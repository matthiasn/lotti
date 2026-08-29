"""Tests for public subscription routes and their per-entitlement auth boundary."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from src.container import container
from src.core.constants import (
    SERVICE_BUNDLE_ROTATION_SERVICE,
    SERVICE_BUNDLE_CLAIM_REAPER,
    SERVICE_GOOGLE_PLAY_NOTIFICATIONS,
    SERVICE_PAID_BUNDLE_SERVICE,
    SERVICE_SUBSCRIPTION_IDENTITY,
    SERVICE_SUBSCRIPTION_REPOSITORY,
    SERVICE_SUBSCRIPTION_RECONCILER,
    SERVICE_SUBSCRIPTION_SERVICE,
)
from src.core.exceptions import (
    BundleClaimConflictException,
    EntitlementAuthenticationException,
    GooglePlayUnavailableException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PubSubAuthenticationException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
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

    async def create_entitlement(self, *, now):
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
        self.failure = None

    @staticmethod
    def _delivery():
        return PaidBundleDelivery(
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

    async def get_current_subscription(self, _entitlement_id):
        return self.subscription


class FakeReconciler:
    def start(self):
        pass

    async def stop(self):
        pass


@pytest.fixture
def services(repository, monkeypatch):
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "true")
    instances = {
        SERVICE_SUBSCRIPTION_IDENTITY: FakeIdentityService(),
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


def test_entitlement_bootstrap_is_public_and_returns_one_time_secret(client):
    response = client.post("/api/v1/client/subscriptions/entitlements")

    assert response.status_code == 201
    assert response.json() == {
        "entitlement_id": "entitlement-one",
        "auth_secret": AUTH_SECRET,
        "obfuscated_account_id": "obfuscated-one",
    }


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


def test_verified_purchase_returns_paid_bundle_and_rotation_challenge(client, services):
    response = client.post(
        "/api/v1/client/subscriptions/purchases/verify",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json=purchase_payload(),
    )

    assert response.status_code == 200
    assert response.json()["bundle"] == "encoded-bundle"
    assert response.json()["rotation_challenge"] == "rotation-proof"
    assert response.json()["entitlement_state"] == "active"
    _, values = services[SERVICE_SUBSCRIPTION_SERVICE].calls[0]
    assert values["entitlement_auth_secret"] == AUTH_SECRET


def test_delivery_retry_authenticates_entitlement_without_replaying_purchase(client, services):
    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 200
    assert response.json()["bundle_id"] == "bundle-one"
    identity = services[SERVICE_SUBSCRIPTION_IDENTITY]
    assert identity.auth_calls == [("entitlement-one", AUTH_SECRET)]
    assert services[SERVICE_PAID_BUNDLE_SERVICE].delivery_calls[0]["claim_secret"] == CLAIM_SECRET


def test_delivery_retry_fails_closed_when_current_subscription_is_missing(client, services):
    services[SERVICE_SUBSCRIPTION_REPOSITORY].subscription = None

    response = client.post(
        "/api/v1/client/subscriptions/bundle-claims/deliver",
        headers={"Authorization": f"Bearer {AUTH_SECRET}"},
        json={"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Subscription is missing"


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
