"""Tests for the authenticated Google Play HTTP and response boundary."""

# ruff: noqa: S105 - explicit non-production token fixtures

from __future__ import annotations

import json
from datetime import datetime, timezone

import httpx
import pytest
from src.core.exceptions import (
    GooglePlayUnavailableException,
    GooglePlayVerificationException,
)
from src.core.subscriptions import AcknowledgementState, GoogleSubscriptionState
from src.services.google_play_client import (
    GoogleAccessTokenProvider,
    GooglePlayClient,
    parse_subscription,
)

pytestmark = pytest.mark.anyio


class StubTokenProvider:
    async def get_token(self):
        return "short-lived-access-token"


def subscription_payload(**overrides):
    payload = {
        "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
        "acknowledgementState": "ACKNOWLEDGEMENT_STATE_PENDING",
        "startTime": "2026-08-01T12:00:00Z",
        "linkedPurchaseToken": "old-token",
        "externalAccountIdentifiers": {
            "obfuscatedExternalAccountId": "account-binding",
            "obfuscatedExternalProfileId": "profile-binding",
        },
        "lineItems": [
            {
                "productId": "lotti_sync",
                "expiryTime": "2026-09-01T12:00:00.123456789Z",
                "latestSuccessfulOrderId": "GPA.1234",
                "offerDetails": {"basePlanId": "monthly"},
            }
        ],
    }
    payload.update(overrides)
    return payload


def test_parse_subscription_preserves_authorization_fields():
    snapshot = parse_subscription(subscription_payload(testPurchase={}))

    assert snapshot.state is GoogleSubscriptionState.ACTIVE
    assert snapshot.acknowledgement_state is AcknowledgementState.PENDING
    assert snapshot.start_time == datetime(2026, 8, 1, 12, tzinfo=timezone.utc)
    assert snapshot.linked_purchase_token == "old-token"
    assert snapshot.obfuscated_external_account_id == "account-binding"
    assert snapshot.obfuscated_external_profile_id == "profile-binding"
    assert snapshot.test_purchase is True
    assert snapshot.line_items[0].product_id == "lotti_sync"
    assert snapshot.line_items[0].base_plan_id == "monthly"
    assert snapshot.line_items[0].expiry_time == datetime(
        2026, 9, 1, 12, 0, 0, 123456, tzinfo=timezone.utc
    )
    assert snapshot.line_items[0].latest_successful_order_id == "GPA.1234"


def test_parse_subscription_preserves_out_of_app_recovery_binding():
    snapshot = parse_subscription(
        subscription_payload(
            linkedPurchaseToken=None,
            outOfAppPurchaseContext={
                "expiredPurchaseToken": "expired-token",
                "expiredExternalAccountIdentifiers": {
                    "obfuscatedExternalAccountId": "old-account-binding",
                    "obfuscatedExternalProfileId": "old-profile-binding",
                },
            },
        )
    )

    assert snapshot.expired_purchase_token == "expired-token"
    assert snapshot.expired_obfuscated_external_account_id == "old-account-binding"
    assert snapshot.expired_obfuscated_external_profile_id == "old-profile-binding"


def test_parse_subscription_accepts_absent_optional_timestamps():
    payload = subscription_payload(startTime=None)
    payload["lineItems"][0]["expiryTime"] = None

    snapshot = parse_subscription(payload)

    assert snapshot.start_time is None
    assert snapshot.line_items[0].expiry_time is None


@pytest.mark.parametrize(
    "payload",
    [
        {},
        subscription_payload(subscriptionState="unknown"),
        subscription_payload(lineItems=[]),
        subscription_payload(lineItems=[{"productId": "lotti_sync", "expiryTime": "not-a-time"}]),
        subscription_payload(startTime="2026-08-01T12:00:00"),
    ],
)
def test_parse_subscription_rejects_malformed_google_responses(payload):
    with pytest.raises(GooglePlayVerificationException):
        parse_subscription(payload)


async def test_get_subscription_uses_bearer_auth_and_escaped_token():
    requests = []

    def handler(request):
        requests.append(request)
        return httpx.Response(200, json=subscription_payload())

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        snapshot = await client.get_subscription(
            "com.matthiasn.lotti", "purchase/token+with?reserved"
        )

    assert snapshot.state is GoogleSubscriptionState.ACTIVE
    assert requests[0].headers["Authorization"] == "Bearer short-lived-access-token"
    assert requests[0].url.raw_path.endswith(b"/purchase%2Ftoken%2Bwith%3Freserved")


async def test_acknowledge_uses_subscription_product_and_empty_body():
    requests = []

    def handler(request):
        requests.append(request)
        return httpx.Response(200, json={})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        await client.acknowledge_subscription("com.matthiasn.lotti", "lotti_sync", "purchase-token")

    request = requests[0]
    assert request.method == "POST"
    assert request.url.path.endswith(
        "/purchases/subscriptions/lotti_sync/tokens/purchase-token:acknowledge"
    )
    assert json.loads(request.content) == {}


async def test_acknowledge_accepts_empty_success_response():
    transport = httpx.MockTransport(lambda _: httpx.Response(204))
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)

        await client.acknowledge_subscription(
            "com.matthiasn.lotti",
            "lotti_sync",
            "purchase-token",
        )


async def test_decode_integrity_token_posts_only_the_signed_token():
    requests = []

    def handler(request):
        requests.append(request)
        return httpx.Response(200, json={"tokenPayloadExternal": {"requestDetails": {}}})

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        payload = await client.decode_integrity_token(
            "com.matthiasn.lotti", "signed-integrity-token"
        )

    assert payload == {"tokenPayloadExternal": {"requestDetails": {}}}
    assert requests[0].url.path == ("/v1/com.matthiasn.lotti:decodeIntegrityToken")
    assert json.loads(requests[0].content) == {"integrity_token": "signed-integrity-token"}


@pytest.mark.parametrize("status_code", [429, 500, 502, 503, 504])
async def test_retryable_google_failures_are_reported_as_unavailable(status_code):
    transport = httpx.MockTransport(lambda _: httpx.Response(status_code, json={}))
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        with pytest.raises(GooglePlayUnavailableException):
            await client.get_subscription("com.matthiasn.lotti", "token")


@pytest.mark.parametrize("status_code", [400, 401, 403, 404])
async def test_permanent_google_rejections_are_verification_failures(status_code):
    transport = httpx.MockTransport(lambda _: httpx.Response(status_code, json={}))
    async with httpx.AsyncClient(transport=transport) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        with pytest.raises(GooglePlayVerificationException):
            await client.get_subscription("com.matthiasn.lotti", "token")


async def test_transport_failure_is_reported_without_leaking_the_token():
    def handler(request):
        raise httpx.ConnectError("offline", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        with pytest.raises(GooglePlayUnavailableException) as caught:
            await client.get_subscription("com.matthiasn.lotti", "secret-purchase-token")

    assert "secret-purchase-token" not in str(caught.value)


async def test_access_token_provider_refreshes_invalid_credentials_once():
    class Credentials:
        valid = False
        token = None
        refresh_count = 0

        def refresh(self, _request):
            self.refresh_count += 1
            self.valid = True
            self.token = "refreshed-token"

    credentials = Credentials()
    provider = GoogleAccessTokenProvider(credentials)

    assert await provider.get_token() == "refreshed-token"
    assert await provider.get_token() == "refreshed-token"
    assert credentials.refresh_count == 1


def test_application_default_credentials_use_android_publisher_scope(monkeypatch):
    credentials = object()
    calls = []

    def default(*, scopes):
        calls.append(scopes)
        return credentials, "project"

    monkeypatch.setattr("src.services.google_play_client.google.auth.default", default)

    provider = GoogleAccessTokenProvider.from_application_default_credentials()

    assert provider._credentials is credentials
    assert calls == [
        [
            "https://www.googleapis.com/auth/androidpublisher",
            "https://www.googleapis.com/auth/playintegrity",
        ]
    ]


async def test_access_token_provider_rejects_refresh_without_token():
    class Credentials:
        valid = False
        token = None

        def refresh(self, _request):
            self.valid = True

    with pytest.raises(GooglePlayUnavailableException, match="did not produce"):
        await GoogleAccessTokenProvider(Credentials()).get_token()


@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(200, content=b"not-json"),
        httpx.Response(200, json=["not", "an", "object"]),
    ],
)
async def test_google_response_body_must_be_a_json_object(response):
    async with httpx.AsyncClient(transport=httpx.MockTransport(lambda _: response)) as http_client:
        client = GooglePlayClient(StubTokenProvider(), client=http_client)
        with pytest.raises(GooglePlayVerificationException):
            await client.get_subscription("com.matthiasn.lotti", "token")


async def test_client_closes_only_its_internally_owned_pool():
    client = GooglePlayClient(StubTokenProvider())
    owned_pool = client._client

    await client.aclose()

    assert owned_pool.is_closed is True
