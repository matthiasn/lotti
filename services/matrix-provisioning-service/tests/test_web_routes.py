"""Tests for the web checkout routes and the Paddle webhook endpoint."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from src.container import container
from src.core.constants import (
    SERVICE_ADMIN_CLIENT,
    SERVICE_BUNDLE_CLAIM_REAPER,
    SERVICE_LAPSED_ACCOUNT_REAPER,
    SERVICE_PADDLE_SUBSCRIPTIONS,
    SERVICE_PAID_BUNDLE_SERVICE,
    SERVICE_SUBSCRIPTION_IDENTITY,
    SERVICE_SUBSCRIPTION_RECONCILER,
    SERVICE_WEB_CHECKOUT,
)
from src.core.exceptions import (
    BundleClaimConflictException,
    BundleClaimRateLimitException,
    CheckoutSessionException,
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PaddleUnavailableException,
    PaddleWebhookException,
    PaymentPendingException,
    WebCheckoutRateLimitException,
)
from src.core.subscriptions import EntitlementState, PaidBundleDelivery
from src.main import app
from src.services.web_checkout_service import (
    CheckoutSessionState,
    CreatedCheckoutSession,
    WebClaimResult,
)

NOW = datetime(2026, 10, 17, 12, tzinfo=timezone.utc)
AUTH_SECRET = "a" * 43
CLAIM_SECRET = "c" * 43
SESSION_ID = "s" * 32


class FakeWebCheckout:
    def __init__(self):
        self.calls = []
        self.failure = None

    def _record(self, name, values):
        if self.failure:
            raise self.failure
        self.calls.append((name, values))

    async def create_session(self, **values):
        self._record("create_session", values)
        return CreatedCheckoutSession(
            session_id=SESSION_ID,
            checkout_url=f"https://sync.example.com/checkout/#session={SESSION_ID}",
            expires_at=NOW,
        )

    async def session_state(self, session_id):
        self._record("session_state", {"session_id": session_id})
        return CheckoutSessionState.PAID

    async def claim(self, **values):
        self._record("claim", values)
        return WebClaimResult(
            delivery=PaidBundleDelivery(
                bundle_id="bundle-one",
                bundle="encoded-bundle",
                expires_at=NOW,
                rotation_challenge="challenge",
            ),
            subscription=SimpleNamespace(entitlement_state=EntitlementState.ACTIVE),
        )

    async def portal_url(self, **values):
        self._record("portal_url", values)
        return "https://customer-portal.paddle.com/cpl_01"


class FakePaddleSubscriptions:
    def __init__(self):
        self.deliveries = []
        self.failure = None

    async def handle_webhook(self, raw_body, signature_header):
        if self.failure:
            raise self.failure
        self.deliveries.append((raw_body, signature_header))
        return "applied"


class FakeWorker:
    def start(self):
        pass

    async def stop(self):
        pass


class FakeAdminClient:
    async def require_account_suspension_support(self):
        pass

    async def aclose(self):
        pass


@pytest.fixture
def services(repository, monkeypatch):
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "false")
    monkeypatch.setenv("ENABLE_WEB_SUBSCRIPTIONS", "true")
    instances = {
        SERVICE_ADMIN_CLIENT: FakeAdminClient(),
        SERVICE_SUBSCRIPTION_IDENTITY: object(),
        SERVICE_PAID_BUNDLE_SERVICE: object(),
        SERVICE_WEB_CHECKOUT: FakeWebCheckout(),
        SERVICE_PADDLE_SUBSCRIPTIONS: FakePaddleSubscriptions(),
        SERVICE_SUBSCRIPTION_RECONCILER: FakeWorker(),
        SERVICE_BUNDLE_CLAIM_REAPER: FakeWorker(),
        SERVICE_LAPSED_ACCOUNT_REAPER: FakeWorker(),
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


def bearer():
    return {"Authorization": f"Bearer {AUTH_SECRET}"}


SESSION_BODY = {
    "entitlement_id": "entitlement-one",
    "plan": "monthly",
    "claim_secret": CLAIM_SECRET,
}
CLAIM_BODY = {"entitlement_id": "entitlement-one", "claim_secret": CLAIM_SECRET}


def test_session_route_needs_no_api_key_and_passes_the_bearer_secret(client, services):
    response = client.post(
        "/api/v1/client/web-checkout/sessions", json=SESSION_BODY, headers=bearer()
    )

    assert response.status_code == 201
    assert response.json()["session_id"] == SESSION_ID
    name, values = services[SERVICE_WEB_CHECKOUT].calls[0]
    assert name == "create_session"
    assert values == {**SESSION_BODY, "auth_secret": AUTH_SECRET}


def test_session_route_requires_a_bearer_credential(client):
    response = client.post("/api/v1/client/web-checkout/sessions", json=SESSION_BODY)

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize(
    ("failure", "code"),
    [
        (EntitlementAuthenticationException("bad"), 401),
        (WebCheckoutRateLimitException(retry_after_seconds=30), 429),
        (InvalidSubscriptionProductException("price"), 422),
    ],
)
def test_session_route_maps_failures(client, services, failure, code):
    services[SERVICE_WEB_CHECKOUT].failure = failure

    response = client.post(
        "/api/v1/client/web-checkout/sessions", json=SESSION_BODY, headers=bearer()
    )

    assert response.status_code == code
    if code == 429:
        assert response.headers["retry-after"] == "30"


def test_status_route_is_public_and_returns_the_state(client, services):
    response = client.post(
        "/api/v1/client/web-checkout/session-status", json={"session_id": SESSION_ID}
    )

    assert response.status_code == 200
    assert response.json() == {"state": "paid"}


def test_status_route_hides_unknown_sessions_behind_404(client, services):
    services[SERVICE_WEB_CHECKOUT].failure = CheckoutSessionException("unknown")

    response = client.post(
        "/api/v1/client/web-checkout/session-status", json={"session_id": SESSION_ID}
    )

    assert response.status_code == 404


def test_status_route_rejects_short_ids_before_any_lookup(client, services):
    response = client.post("/api/v1/client/web-checkout/session-status", json={"session_id": "x"})

    assert response.status_code == 422
    assert services[SERVICE_WEB_CHECKOUT].calls == []


def test_claim_route_returns_the_bundle_and_state(client, services):
    response = client.post("/api/v1/client/web-checkout/claims", json=CLAIM_BODY, headers=bearer())

    assert response.status_code == 200
    body = response.json()
    assert body["bundle"] == "encoded-bundle"
    assert body["rotation_challenge"] == "challenge"
    assert body["entitlement_state"] == "active"


@pytest.mark.parametrize(
    ("failure", "code"),
    [
        (EntitlementAuthenticationException("bad"), 401),
        (BundleClaimRateLimitException(retry_after_seconds=9), 429),
        (PaymentPendingException("not yet"), 402),
        (GooglePlayVerificationException("suspended"), 422),
        (BundleClaimConflictException("secret"), 409),
    ],
)
def test_claim_route_maps_failures(client, services, failure, code):
    services[SERVICE_WEB_CHECKOUT].failure = failure

    response = client.post("/api/v1/client/web-checkout/claims", json=CLAIM_BODY, headers=bearer())

    assert response.status_code == code


def test_portal_route_returns_the_link(client, services):
    response = client.post(
        "/api/v1/client/web-checkout/portal-sessions",
        json={"entitlement_id": "entitlement-one"},
        headers=bearer(),
    )

    assert response.status_code == 200
    assert response.json() == {"url": "https://customer-portal.paddle.com/cpl_01"}


@pytest.mark.parametrize(
    ("failure", "code"),
    [
        (EntitlementAuthenticationException("bad"), 401),
        (WebCheckoutRateLimitException(retry_after_seconds=9), 429),
        (PaymentPendingException("none"), 404),
        (PaddleUnavailableException("down"), 503),
    ],
)
def test_portal_route_maps_failures(client, services, failure, code):
    services[SERVICE_WEB_CHECKOUT].failure = failure

    response = client.post(
        "/api/v1/client/web-checkout/portal-sessions",
        json={"entitlement_id": "entitlement-one"},
        headers=bearer(),
    )

    assert response.status_code == code


def test_webhook_passes_the_exact_raw_body_and_signature(client, services):
    raw = b'{"event_id": "evt_01",  "spacing": "preserved"}'

    response = client.post(
        "/api/v1/webhooks/paddle",
        content=raw,
        headers={"Paddle-Signature": "ts=1;h1=abc", "Content-Type": "application/json"},
    )

    assert response.status_code == 200
    assert response.json() == {"outcome": "applied"}
    assert services[SERVICE_PADDLE_SUBSCRIPTIONS].deliveries == [(raw, "ts=1;h1=abc")]


def test_webhook_rejects_untrusted_deliveries_so_paddle_retries(client, services):
    services[SERVICE_PADDLE_SUBSCRIPTIONS].failure = PaddleWebhookException("mismatch")

    response = client.post("/api/v1/webhooks/paddle", content=b"{}")

    assert response.status_code == 400


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/client/web-checkout/sessions",
        "/api/v1/client/web-checkout/session-status",
        "/api/v1/client/web-checkout/claims",
        "/api/v1/client/web-checkout/portal-sessions",
        "/api/v1/webhooks/paddle",
    ],
)
def test_every_web_route_fails_closed_when_web_checkout_is_off(client, monkeypatch, path):
    monkeypatch.setenv("ENABLE_WEB_SUBSCRIPTIONS", "false")

    response = client.post(
        path,
        json={**SESSION_BODY, "session_id": SESSION_ID},
        headers=bearer(),
    )

    assert response.status_code == 503
