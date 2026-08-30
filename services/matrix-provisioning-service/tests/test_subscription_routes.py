"""Tests for public subscription routes and their per-entitlement auth boundary."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from src.container import container
from src.core.constants import (
    SERVICE_ADMIN_CLIENT,
    SERVICE_BUNDLE_CLAIM_REAPER,
    SERVICE_BUNDLE_ROTATION_SERVICE,
    SERVICE_GOOGLE_PLAY_NOTIFICATIONS,
    SERVICE_PAID_BUNDLE_SERVICE,
    SERVICE_SUBSCRIPTION_ACCESS_SERVICE,
    SERVICE_SUBSCRIPTION_IDENTITY,
    SERVICE_SUBSCRIPTION_RECONCILER,
    SERVICE_SUBSCRIPTION_REPOSITORY,
    SERVICE_SUBSCRIPTION_SERVICE,
)
from src.core.exceptions import (
    BundleClaimConflictException,
    BundleClaimRateLimitException,
    EntitlementAuthenticationException,
    EntitlementRateLimitException,
    GooglePlayUnavailableException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PubSubAuthenticationException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentRateLimitException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    PurchaseVerificationRateLimitException,
    SubscriptionLineageException,
)
from src.core.subscriptions import (
    EntitlementCredentials,
    EntitlementState,
    PaidBundleDelivery,
    PurchaseIntentCredentials,
    VerifiedPurchaseResult,
)
from src.main import app

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)
AUTH_SECRET = "a" * 43
INTENT_SECRET = "i" * 43
CLAIM_SECRET = "c" * 43


class FakeIdentityService:
    def __init__(self):
        self.intent_calls = []
        self.auth_calls = []
        self.failure = None
        self.entitlement_calls = []
        self.bundle_claim_auth_calls = []

    async def create_entitlement(self, *, client_identifier, now):
        if self.failure:
            raise self.failure
        self.entitlement_calls.append((client_identifier, now))
        return EntitlementCredentials(
            entitlement_id="entitlement-one",
            auth_secret=AUTH_SECRET,
            obfuscated_account_id="obfuscated-one",
        )

    async def create_purchase_intent(self, **values):
        if self.failure:
            raise self.failure
        self.intent_calls.append(values)
        return PurchaseIntentCredentials(
            intent_id="intent-one",
            intent_secret=INTENT_SECRET,
            product_id=values["product_id"],
            base_plan_id=values["base_plan_id"],
            obfuscated_account_id="obfuscated-one",
            expires_at=values["now"] + timedelta(minutes=15),
        )

    async def authenticate(self, entitlement_id, auth_secret):
        if self.failure:
            raise self.failure
        self.auth_calls.append((entitlement_id, auth_secret))
        return object()

    async def authenticate_bundle_claim_operation(
        self,
        entitlement_id,
        auth_secret,
        *,
        now,
    ):
        self.bundle_claim_auth_calls.append((entitlement_id, auth_secret, now))
        return await self.authenticate(entitlement_id, auth_secret)


class FakeSubscriptionService:
    def __init__(self):
        self.calls = []
        self.subscription = SimpleNamespace(
            entitlement_state=EntitlementState.ACTIVE,
            entitlement_id="entitlement-one",
        )
        self.failure = None

    async def verify_purchase(self, submission, **values):
        if self.failure:
            raise self.failure
        self.calls.append((submission, values))
        return VerifiedPurchaseResult(
            subscription=self.subscription,
            request_hash="request-hash",
            claim_secret_hash="claim-hash",
        )


class FakePaidBundleService:
    def __init__(self):
        self.provision_calls = []
        self.delivery_calls = []
        self.returnable_delivery_checks = []
        self.returnable_subscription = SimpleNamespace(entitlement_state=EntitlementState.ACTIVE)
        self.failure = None
        self.delivery = None

    def _delivery(self):
        return self.delivery or PaidBundleDelivery(
            bundle_id="bundle-one",
            bundle="encoded-bundle",
            expires_at=NOW + timedelta(hours=24),
            rotation_challenge="rotation-proof",
        )

    async def provision_or_deliver(self, verified, submission, *, now):
        if self.failure:
            raise self.failure
        self.provision_calls.append((verified, submission, now))
        return self._delivery()

    async def deliver_existing_claim(self, **values):
        if self.failure:
            raise self.failure
        self.delivery_calls.append(values)
        return self._delivery()

    async def require_returnable_delivery(self, delivery, **values):
        if self.failure:
            raise self.failure
        self.returnable_delivery_checks.append((delivery, values))
        return self.returnable_subscription


class FakeRotationService:
    def __init__(self):
        self.calls = []
        self.failure = None

    async def confirm_rotation(self, **values):
        if self.failure:
            raise self.failure
        self.calls.append(values)


class FakeNotificationService:
    def __init__(self):
        self.calls = []
        self.failure = None

    async def handle(self, envelope, **values):
        if self.failure:
            raise self.failure
        self.calls.append((envelope, values))


class FakeSubscriptionRepository:
    def __init__(self):
        self.subscription = SimpleNamespace(entitlement_state=EntitlementState.ACTIVE)
        self.lookups = []
        self.results = []

    async def get_current_subscription(self, entitlement_id):
        self.lookups.append(entitlement_id)
        return self.results.pop(0) if self.results else self.subscription


class FakeSubscriptionAccessService:
    def __init__(self):
        self.calls = []
        self.results = []

    async def enforce(self, subscription, *, now):
        self.calls.append((subscription, now))
        return self.results.pop(0) if self.results else False


class FakeReconciler:
    def start(self):
        pass

    async def stop(self):
        pass


class FakeAdminClient:
    def __init__(self):
        self.suspension_checks = 0

    async def require_account_suspension_support(self):
        self.suspension_checks += 1

    async def aclose(self):
        pass


@pytest.fixture
def services(repository, monkeypatch):
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "true")
    instances = {
        SERVICE_ADMIN_CLIENT: FakeAdminClient(),
        SERVICE_SUBSCRIPTION_IDENTITY: FakeIdentityService(),
        SERVICE_SUBSCRIPTION_ACCESS_SERVICE: FakeSubscriptionAccessService(),
        SERVICE_SUBSCRIPTION_SERVICE: FakeSubscriptionService(),
        SERVICE_PAID_BUNDLE_SERVICE: FakePaidBundleService(),
        SERVICE_BUNDLE_ROTATION_SERVICE: FakeRotationService(),
        SERVICE_GOOGLE_PLAY_NOTIFICATIONS: FakeNotificationService(),
        SERVICE_SUBSCRIPTION_REPOSITORY: FakeSubscriptionRepository(),
        SERVICE_SUBSCRIPTION_RECONCILER: FakeReconciler(),
        SERVICE_BUNDLE_CLAIM_REAPER: FakeReconciler(),
    }
    container.reset()
    container.override("provisioning_repository", repository)
    for name, instance in instances.items():
        container.override(name, instance)
    yield instances
    container.reset()


@pytest.fixture
def client(services):
    with TestClient(app) as test_client:
        yield test_client


def purchase_payload():
    return {
        "package_name": "com.matthiasn.lotti",
        "product_id": "lotti_sync",
        "base_plan_id": "monthly",
        "entitlement_id": "entitlement-one",
        "purchase_intent_id": "intent-one",
        "purchase_token": "purchase-token",
        "intent_secret": INTENT_SECRET,
        "claim_secret": CLAIM_SECRET,
        "integrity_token": "signed-integrity-token",
    }


def test_entitlement_bootstrap_is_public_and_returns_one_time_secret(client, services):
    response = client.post("/api/v1/client/subscriptions/entitlements")

    assert response.status_code == 201
    assert response.json() == {
        "entitlement_id": "entitlement-one",
        "auth_secret": AUTH_SECRET,
        "obfuscated_account_id": "obfuscated-one",
    }
    identifier, _ = services[SERVICE_SUBSCRIPTION_IDENTITY].entitlement_calls[0]
    assert identifier == "testclient"
    assert services[SERVICE_ADMIN_CLIENT].suspension_checks == 1


def test_entitlement_bootstrap_maps_per_client_rate_limit(client, services):
    services[SERVICE_SUBSCRIPTION_IDENTITY].failure = EntitlementRateLimitException(
        retry_after_seconds=37
    )

    response = client.post("/api/v1/client/subscriptions/entitlements")

    assert response.status_code == 429
    assert response.headers["retry-after"] == "37"
    assert response.json()["detail"] == "Entitlement creation rate limit exceeded"


def test_subscription_routes_fail_closed_when_feature_is_disabled(client, monkeypatch):
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "false")

    response = client.post("/api/v1/client/subscriptions/entitlements")

    assert response.status_code == 503
    assert response.json()["detail"] == "Google Play SYNC subscriptions are disabled"


def test_purchase_intent_requires_entitlement_bearer_credential(client):
    response = client.post(
        "/api/v1/client/subscriptions/purchase-intents",
        json={
            "entitlement_id": "entitlement-one",
            "product_id": "lotti_sync",
            "base_plan_id": "monthly",
        },
    )

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_purchase_intent_passes_entitlement_secret_to_service(client, services):
    response = client.post(
        "/api/v1/client/subscriptions/purchase-intents",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "product_id": "lotti_sync",
            "base_plan_id": "monthly",
        },
    )

    assert response.status_code == 201
    assert response.json()["intent_secret"] == INTENT_SECRET
    call = services[SERVICE_SUBSCRIPTION_IDENTITY].intent_calls[0]
    assert call["auth_secret"] == AUTH_SECRET
    assert call["base_plan_id"] == "monthly"


def test_purchase_intent_maps_per_entitlement_rate_limit(client, services):
    services[SERVICE_SUBSCRIPTION_IDENTITY].failure = PurchaseIntentRateLimitException(
        retry_after_seconds=91
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchase-intents",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "product_id": "lotti_sync",
            "base_plan_id": "monthly",
        },
    )

    assert response.status_code == 429
    assert response.headers["retry-after"] == "91"
    assert response.json()["detail"] == "Purchase intent creation rate limit exceeded"


def test_verified_purchase_returns_paid_bundle_and_rotation_challenge(
    client,
    services,
    monkeypatch,
):
    route_times = iter(
        (
            NOW,
            NOW + timedelta(seconds=1),
            NOW + timedelta(seconds=2),
            NOW + timedelta(seconds=3),
        )
    )

    class FakeDatetime:
        @classmethod
        def now(cls, _timezone):
            return next(route_times)

    monkeypatch.setattr("src.api.routes.datetime", FakeDatetime)
    services[SERVICE_PAID_BUNDLE_SERVICE].returnable_subscription = SimpleNamespace(
        entitlement_state=EntitlementState.GRACE
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 200
    assert response.json()["bundle"] == "encoded-bundle"
    assert response.json()["rotation_challenge"] == "rotation-proof"
    assert response.json()["bundle_import_required"] is True
    assert response.json()["entitlement_state"] == "grace"
    _, values = services[SERVICE_SUBSCRIPTION_SERVICE].calls[0]
    assert values["entitlement_auth_secret"] == AUTH_SECRET
    access_calls = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].calls
    assert access_calls[0][0] is services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription
    assert len(access_calls) == 2
    assert services[SERVICE_SUBSCRIPTION_REPOSITORY].lookups == [
        "entitlement-one",
        "entitlement-one",
    ]
    final_check = services[SERVICE_PAID_BUNDLE_SERVICE].returnable_delivery_checks[0]
    assert final_check[0].bundle_id == "bundle-one"
    assert final_check[1] == {
        "entitlement_id": "entitlement-one",
        "now": NOW + timedelta(seconds=3),
    }


def test_purchase_verification_rechecks_access_after_slow_provisioning(
    client,
    services,
    monkeypatch,
):
    route_times = iter(
        (
            NOW,
            NOW + timedelta(seconds=30),
            NOW + timedelta(minutes=1),
        )
    )

    class FakeDatetime:
        @classmethod
        def now(cls, _timezone):
            return next(route_times)

    monkeypatch.setattr("src.api.routes.datetime", FakeDatetime)
    access = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE]
    access.results = [False, True]

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert [call[1] for call in access.calls] == [
        NOW + timedelta(seconds=30),
        NOW + timedelta(minutes=1),
    ]
    assert services[SERVICE_PAID_BUNDLE_SERVICE].provision_calls[0][2] == NOW + timedelta(
        seconds=30
    )


def test_purchase_verification_stops_before_delivery_when_enforcement_suspends(
    client,
    services,
):
    services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].results = [True]

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert services[SERVICE_PAID_BUNDLE_SERVICE].provision_calls == []


def test_purchase_verification_fails_closed_if_subscription_disappears_after_delivery(
    client,
    services,
):
    subscription_repository = services[SERVICE_SUBSCRIPTION_REPOSITORY]
    subscription_repository.results = [subscription_repository.subscription, None]

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Verified subscription is missing"
    paid_service = services[SERVICE_PAID_BUNDLE_SERVICE]
    assert len(paid_service.provision_calls) == 1
    assert services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].calls == [
        (subscription_repository.subscription, paid_service.provision_calls[0][2])
    ]


def test_purchase_verification_maps_attempt_rate_limit(client, services):
    services[SERVICE_SUBSCRIPTION_SERVICE].failure = PurchaseVerificationRateLimitException(
        retry_after_seconds=73
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 429
    assert response.headers["retry-after"] == "73"
    assert response.json()["detail"] == "Purchase verification rate limit exceeded"


def test_purchase_verification_enforces_expiry_after_delivery_rejects(
    client,
    services,
    monkeypatch,
):
    route_times = iter(
        (
            NOW,
            NOW + timedelta(seconds=30),
            NOW + timedelta(minutes=1),
        )
    )

    class FakeDatetime:
        @classmethod
        def now(cls, _timezone):
            return next(route_times)

    monkeypatch.setattr("src.api.routes.datetime", FakeDatetime)
    access = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE]
    access.results = [False, True]
    services[SERVICE_PAID_BUNDLE_SERVICE].failure = GooglePlayVerificationException(
        "Subscription does not currently grant SYNC access"
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert [call[1] for call in access.calls] == [
        NOW + timedelta(seconds=30),
        NOW + timedelta(minutes=1),
    ]


def test_inactive_verified_purchase_is_enforced_before_delivery_rejection(
    client,
    services,
):
    subscription = services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription
    subscription.entitlement_state = EntitlementState.SUSPENDED
    services[SERVICE_PAID_BUNDLE_SERVICE].failure = GooglePlayVerificationException(
        "Subscription does not currently grant SYNC access"
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert services[SERVICE_SUBSCRIPTION_REPOSITORY].lookups == [
        "entitlement-one",
        "entitlement-one",
    ]
    access_calls = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].calls
    assert [call[0] for call in access_calls] == [subscription, subscription]


def test_verified_replacement_purchase_returns_account_recovery_result(client, services):
    services[SERVICE_PAID_BUNDLE_SERVICE].delivery = PaidBundleDelivery(
        bundle_id="bundle-one",
        bundle=None,
        expires_at=None,
        rotation_challenge=None,
        bundle_import_required=False,
    )

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 200
    assert response.json()["bundle_id"] == "bundle-one"
    assert response.json()["bundle"] is None
    assert response.json()["expires_at"] is None
    assert response.json()["rotation_challenge"] is None
    assert response.json()["bundle_import_required"] is False


def test_purchase_verification_fails_closed_when_persisted_subscription_is_missing(
    client,
    services,
):
    services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription = None

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Verified subscription is missing"
    assert services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].calls == []


def test_delivery_retry_authenticates_entitlement_without_replaying_purchase(
    client,
    services,
    monkeypatch,
):
    route_times = iter(
        (
            NOW,
            NOW + timedelta(seconds=1),
            NOW + timedelta(seconds=2),
            NOW + timedelta(seconds=3),
            NOW + timedelta(seconds=4),
        )
    )

    class FakeDatetime:
        @classmethod
        def now(cls, _timezone):
            return next(route_times)

    monkeypatch.setattr("src.api.routes.datetime", FakeDatetime)
    services[SERVICE_PAID_BUNDLE_SERVICE].returnable_subscription = SimpleNamespace(
        entitlement_state=EntitlementState.GRACE
    )

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 200
    assert response.json()["bundle_id"] == "bundle-one"
    assert response.json()["entitlement_state"] == "grace"
    identity = services[SERVICE_SUBSCRIPTION_IDENTITY]
    assert identity.auth_calls == [("entitlement-one", AUTH_SECRET)]
    assert identity.bundle_claim_auth_calls == [("entitlement-one", AUTH_SECRET, NOW)]
    access = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE]
    subscription = services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription
    assert [call[0] for call in access.calls] == [subscription, subscription]
    assert [call[1] for call in access.calls] == [
        NOW + timedelta(seconds=1),
        NOW + timedelta(seconds=3),
    ]
    delivery_call = services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls[0]
    assert delivery_call["claim_secret"] == CLAIM_SECRET
    assert delivery_call["now"] == NOW + timedelta(seconds=2)
    assert services[SERVICE_SUBSCRIPTION_REPOSITORY].lookups == [
        "entitlement-one",
        "entitlement-one",
    ]
    final_check = services[SERVICE_PAID_BUNDLE_SERVICE].returnable_delivery_checks[0]
    assert final_check[0].bundle_id == "bundle-one"
    assert final_check[1] == {
        "entitlement_id": "entitlement-one",
        "now": NOW + timedelta(seconds=4),
    }


def test_delivery_retry_stops_before_claim_delivery_when_enforcement_suspends(
    client,
    services,
):
    access = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE]
    access.results = [True]

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert len(access.calls) == 1
    assert services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls == []


def test_delivery_retry_reports_concurrently_replaced_subscription_state(client, services):
    predecessor = SimpleNamespace(entitlement_state=EntitlementState.EXPIRED)
    replacement = SimpleNamespace(entitlement_state=EntitlementState.ACTIVE)
    repository = services[SERVICE_SUBSCRIPTION_REPOSITORY]
    repository.results = [predecessor, replacement]

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 200
    assert response.json()["entitlement_state"] == "active"
    assert repository.lookups == ["entitlement-one", "entitlement-one"]
    access_calls = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE].calls
    assert [call[0] for call in access_calls] == [predecessor, replacement]


def test_delivery_retry_rejects_concurrently_suspended_subscription(client, services):
    predecessor = SimpleNamespace(entitlement_state=EntitlementState.ACTIVE)
    replacement = SimpleNamespace(entitlement_state=EntitlementState.SUSPENDED)
    repository = services[SERVICE_SUBSCRIPTION_REPOSITORY]
    repository.results = [predecessor, replacement]
    access = services[SERVICE_SUBSCRIPTION_ACCESS_SERVICE]
    access.results = [False, True]

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"
    assert [call[0] for call in access.calls] == [predecessor, replacement]
    assert len(services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls) == 1


def test_delivery_retry_fails_closed_if_subscription_disappears_after_delivery(
    client,
    services,
):
    repository = services[SERVICE_SUBSCRIPTION_REPOSITORY]
    repository.results = [repository.subscription, None]

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Subscription is missing"
    assert len(services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls) == 1
    assert repository.lookups == ["entitlement-one", "entitlement-one"]


def test_delivery_retry_fails_closed_when_current_subscription_is_missing(client, services):
    services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription = None

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Subscription is missing"
    assert services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls == []


def test_delivery_retry_maps_inactive_subscription(client, services):
    services[SERVICE_PAID_BUNDLE_SERVICE].failure = GooglePlayVerificationException(
        "Subscription does not currently grant SYNC access"
    )

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Subscription does not currently grant SYNC access"


def test_rotation_confirmation_has_no_response_body(client, services):
    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/confirm-rotation",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "bundle_id": "bundle-one",
            "claim_secret": CLAIM_SECRET,
        },
    )

    assert response.status_code == 204
    call = services[SERVICE_BUNDLE_ROTATION_SERVICE].calls[0]
    assert call["entitlement_auth_secret"] == AUTH_SECRET
    assert call["bundle_id"] == "bundle-one"


def test_rtdn_bypasses_shared_api_key_but_passes_pubsub_jwt_for_verification(
    client,
    services,
):
    payload = {"message": {"data": "encoded"}}

    response = client.post(
        "/api/v1/google-play/rtdn",
        headers={"Authorization": "Bearer pubsub-jwt"},
        json=payload,
    )

    assert response.status_code == 204
    envelope, values = services[SERVICE_GOOGLE_PLAY_NOTIFICATIONS].calls[0]
    assert envelope == payload
    assert values["authorization"] == "Bearer pubsub-jwt"


@pytest.mark.parametrize(
    ("failure", "expected_status"),
    [
        (EntitlementAuthenticationException("bad auth"), 401),
        (InvalidSubscriptionProductException("bad plan"), 422),
    ],
)
def test_purchase_intent_maps_domain_failures(client, services, failure, expected_status):
    services[SERVICE_SUBSCRIPTION_IDENTITY].failure = failure

    response = client.post(
        "/api/v1/client/subscriptions/purchase-intents",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "product_id": "lotti_sync",
            "base_plan_id": "monthly",
        },
    )

    assert response.status_code == expected_status


@pytest.mark.parametrize(
    ("failure", "expected_status"),
    [
        (EntitlementAuthenticationException("bad auth"), 401),
        (PurchaseIntentExpiredException("expired"), 410),
        (PurchaseIntentNotFoundException("missing"), 409),
        (PurchaseIntentReplayException("replayed"), 409),
        (GooglePlayVerificationException("invalid"), 422),
        (InvalidSubscriptionProductException("bad plan"), 422),
        (PurchaseTokenConflictException("owned elsewhere"), 409),
        (SubscriptionLineageException("invalid replacement"), 409),
        (GooglePlayUnavailableException("offline"), 503),
        (BundleClaimConflictException("claimed"), 409),
    ],
)
def test_purchase_verification_maps_domain_failures(
    client,
    services,
    failure,
    expected_status,
):
    services[SERVICE_SUBSCRIPTION_SERVICE].failure = failure

    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == expected_status


@pytest.mark.parametrize(
    ("service_name", "failure", "expected_status"),
    [
        (
            SERVICE_SUBSCRIPTION_IDENTITY,
            EntitlementAuthenticationException("bad auth"),
            401,
        ),
        (SERVICE_PAID_BUNDLE_SERVICE, BundleClaimConflictException("missing"), 409),
    ],
)
def test_delivery_retry_maps_auth_and_claim_failures(
    client,
    services,
    service_name,
    failure,
    expected_status,
):
    services[service_name].failure = failure

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == expected_status


def test_delivery_retry_maps_bundle_claim_attempt_limit(client, services):
    services[SERVICE_SUBSCRIPTION_IDENTITY].failure = BundleClaimRateLimitException(
        retry_after_seconds=47
    )

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 429
    assert response.headers["retry-after"] == "47"
    assert response.json()["detail"] == "Bundle claim operation rate limit exceeded"


@pytest.mark.parametrize(
    ("failure", "expected_status"),
    [
        (EntitlementAuthenticationException("bad auth"), 401),
        (BundleClaimConflictException("bad proof"), 409),
    ],
)
def test_rotation_confirmation_maps_proof_failures(
    client,
    services,
    failure,
    expected_status,
):
    services[SERVICE_BUNDLE_ROTATION_SERVICE].failure = failure

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/confirm-rotation",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "bundle_id": "bundle-one",
            "claim_secret": CLAIM_SECRET,
        },
    )

    assert response.status_code == expected_status


def test_rotation_confirmation_maps_bundle_claim_attempt_limit(client, services):
    services[SERVICE_BUNDLE_ROTATION_SERVICE].failure = BundleClaimRateLimitException(
        retry_after_seconds=53
    )

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/confirm-rotation",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={
            "entitlement_id": "entitlement-one",
            "bundle_id": "bundle-one",
            "claim_secret": CLAIM_SECRET,
        },
    )

    assert response.status_code == 429
    assert response.headers["retry-after"] == "53"
    assert response.json()["detail"] == "Bundle claim operation rate limit exceeded"


@pytest.mark.parametrize(
    ("failure", "expected_status"),
    [
        (PubSubAuthenticationException("bad jwt"), 401),
        (GooglePlayVerificationException("bad notice"), 422),
        (GooglePlayUnavailableException("offline"), 503),
    ],
)
def test_rtdn_maps_auth_verification_and_availability_failures(
    client,
    services,
    failure,
    expected_status,
):
    services[SERVICE_GOOGLE_PLAY_NOTIFICATIONS].failure = failure

    response = client.post(
        "/api/v1/google-play/rtdn",
        headers={"Authorization": "Bearer pubsub-jwt"},
        json={"message": {"data": "encoded"}},
    )

    assert response.status_code == expected_status
