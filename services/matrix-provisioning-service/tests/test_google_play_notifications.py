"""Tests for authenticated RTDN decoding and authoritative refresh routing."""

# ruff: noqa: S105 - explicit non-production token fixtures

from __future__ import annotations

import base64
import json
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest
from src.core.exceptions import (
    GooglePlayVerificationException,
    PubSubAuthenticationException,
)
from src.services.google_play_notifications import (
    GooglePlayNotificationService,
    PubSubAuthenticator,
    _verify_google_token,
    parse_rtdn_envelope,
)

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)
AUDIENCE = "https://provisioner.example.com/api/v1/google-play/rtdn"
EMAIL = "play-rtdn@example-project.iam.gserviceaccount.com"


def claims(**overrides):
    values = {
        "iss": "https://accounts.google.com",
        "aud": AUDIENCE,
        "email": EMAIL,
        "email_verified": True,
    }
    values.update(overrides)
    return values


def envelope(**overrides):
    payload = {
        "version": "1.0",
        "packageName": "com.matthiasn.lotti",
        "eventTimeMillis": str(int(NOW.timestamp() * 1000)),
        "subscriptionNotification": {
            "version": "1.0",
            "notificationType": 6,
            "purchaseToken": "purchase-token",
        },
    }
    payload.update(overrides)
    return {
        "message": {
            "messageId": "message-one",
            "data": base64.b64encode(json.dumps(payload).encode()).decode(),
        },
        "subscription": "projects/project/subscriptions/play-rtdn",
    }


async def test_pubsub_authenticator_passes_exact_token_and_audience_to_google():
    calls = []

    def verifier(token, audience):
        calls.append((token, audience))
        return claims()

    authenticator = PubSubAuthenticator(
        audience=AUDIENCE,
        service_account_email=EMAIL,
        verifier=verifier,
    )

    result = await authenticator.authenticate("Bearer signed-jwt")

    assert result["email"] == EMAIL
    assert calls == [("signed-jwt", AUDIENCE)]


@pytest.mark.parametrize(
    "overrides",
    [
        {"iss": "attacker.example"},
        {"aud": "other-audience"},
        {"email": "attacker@example.com"},
        {"email_verified": False},
    ],
)
async def test_pubsub_authenticator_rejects_wrong_identity_claim(overrides):
    authenticator = PubSubAuthenticator(
        audience=AUDIENCE,
        service_account_email=EMAIL,
        verifier=lambda _token, _audience: claims(**overrides),
    )

    with pytest.raises(PubSubAuthenticationException):
        await authenticator.authenticate("Bearer signed-jwt")


async def test_pubsub_authenticator_rejects_missing_or_invalid_token():
    authenticator = PubSubAuthenticator(
        audience=AUDIENCE,
        service_account_email=EMAIL,
        verifier=lambda _token, _audience: (_ for _ in ()).throw(ValueError("bad signature")),
    )

    with pytest.raises(PubSubAuthenticationException):
        await authenticator.authenticate("")
    with pytest.raises(PubSubAuthenticationException):
        await authenticator.authenticate("Bearer invalid-jwt")


def test_rtdn_parser_extracts_signal_fields_only():
    notification = parse_rtdn_envelope(envelope())

    assert notification.package_name == "com.matthiasn.lotti"
    assert notification.purchase_token == "purchase-token"
    assert notification.notification_type == 6
    assert notification.event_time == NOW


def test_default_google_token_verifier_passes_exact_audience(monkeypatch):
    calls = []

    def verify(token, request, *, audience):
        calls.append((token, request, audience))
        return claims()

    monkeypatch.setattr(
        "src.services.google_play_notifications.id_token.verify_oauth2_token", verify
    )

    assert _verify_google_token("signed-jwt", AUDIENCE)["email"] == EMAIL
    assert calls[0][0] == "signed-jwt"
    assert calls[0][2] == AUDIENCE


@pytest.mark.parametrize(
    "invalid",
    [
        {},
        {"message": {}},
        {"message": {"data": "not base64!!"}},
        {"message": {"data": base64.b64encode(b"not json").decode()}},
        envelope(subscriptionNotification={}),
        envelope(packageName=""),
        envelope(subscriptionNotification={"notificationType": 6, "purchaseToken": ""}),
    ],
)
def test_rtdn_parser_rejects_malformed_envelope(invalid):
    with pytest.raises(GooglePlayVerificationException, match="Malformed RTDN"):
        parse_rtdn_envelope(invalid)


class FakeAuthenticator:
    def __init__(self):
        self.headers = []

    async def authenticate(self, authorization):
        self.headers.append(authorization)


class FakeSubscriptionService:
    def __init__(self):
        self.calls = []
        self.subscription = SimpleNamespace(
            entitlement_id="entitlement-one",
            is_current=True,
        )

    async def refresh_known_purchase(self, purchase_token, *, now):
        self.calls.append((purchase_token, now))
        return self.subscription


class FakeAccessService:
    def __init__(self):
        self.calls = []

    async def enforce(self, subscription, *, now):
        self.calls.append((subscription, now))


class FakeRepository:
    def __init__(self, current=None):
        self.current = current
        self.calls = []

    async def get_current_subscription(self, entitlement_id):
        self.calls.append(entitlement_id)
        return self.current


async def test_notification_requeries_google_then_enforces_returned_state():
    authenticator = FakeAuthenticator()
    subscriptions = FakeSubscriptionService()
    access = FakeAccessService()
    repository = FakeRepository(subscriptions.subscription)
    service = GooglePlayNotificationService(
        authenticator,
        subscriptions,
        access,
        repository,
        package_name="com.matthiasn.lotti",
    )

    result = await service.handle(
        envelope(),
        authorization="Bearer signed-jwt",
        now=NOW,
    )

    assert result is subscriptions.subscription
    assert authenticator.headers == ["Bearer signed-jwt"]
    assert subscriptions.calls == [("purchase-token", NOW)]
    assert access.calls == [(subscriptions.subscription, NOW)]
    assert repository.calls == ["entitlement-one"]


async def test_wrong_package_never_requeries_purchase_token():
    subscriptions = FakeSubscriptionService()
    service = GooglePlayNotificationService(
        FakeAuthenticator(),
        subscriptions,
        FakeAccessService(),
        FakeRepository(),
        package_name="com.matthiasn.lotti",
    )

    with pytest.raises(GooglePlayVerificationException, match="package"):
        await service.handle(
            envelope(packageName="attacker.package"),
            authorization="Bearer signed-jwt",
            now=NOW,
        )

    assert subscriptions.calls == []


async def test_late_notification_for_retired_token_cannot_change_matrix_access():
    subscriptions = FakeSubscriptionService()
    subscriptions.subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        is_current=False,
    )
    access = FakeAccessService()
    current = SimpleNamespace(entitlement_id="entitlement-one", is_current=True)
    service = GooglePlayNotificationService(
        FakeAuthenticator(),
        subscriptions,
        access,
        FakeRepository(current),
        package_name="com.matthiasn.lotti",
    )

    result = await service.handle(
        envelope(),
        authorization="Bearer signed-jwt",
        now=NOW,
    )

    assert result.is_current is False
    assert subscriptions.calls == [("purchase-token", NOW)]
    assert access.calls == [(current, NOW)]
