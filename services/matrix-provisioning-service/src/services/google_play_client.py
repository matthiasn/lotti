"""Authenticated HTTP boundary for Google Play purchase verification."""

from __future__ import annotations

import asyncio
from datetime import datetime
from typing import Any, Protocol
from urllib.parse import quote

import google.auth
import httpx
from google.auth.transport.requests import Request

from ..core.exceptions import (
    GooglePlayUnavailableException,
    GooglePlayVerificationException,
)
from ..core.subscriptions import (
    AcknowledgementState,
    GooglePlayLineItem,
    GooglePlaySnapshot,
    GoogleSubscriptionState,
)

ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
PLAY_INTEGRITY_SCOPE = "https://www.googleapis.com/auth/playintegrity"
ANDROID_PUBLISHER_BASE_URL = "https://androidpublisher.googleapis.com"
PLAY_INTEGRITY_BASE_URL = "https://playintegrity.googleapis.com"


class AccessTokenProvider(Protocol):
    """Supplies a short-lived OAuth access token for Google APIs."""

    async def get_token(self) -> str:
        """Return a valid bearer token."""


class GoogleAccessTokenProvider:
    """Refreshes Application Default Credentials without blocking the event loop."""

    def __init__(self, credentials: Any):
        self._credentials = credentials
        self._lock = asyncio.Lock()

    @classmethod
    def from_application_default_credentials(cls) -> GoogleAccessTokenProvider:
        """Load workload identity or a mounted service-account credential."""
        credentials, _ = google.auth.default(scopes=[ANDROID_PUBLISHER_SCOPE, PLAY_INTEGRITY_SCOPE])
        return cls(credentials)

    async def get_token(self) -> str:
        """Return a cached token, refreshing it once when necessary."""
        async with self._lock:
            if not self._credentials.valid:
                await asyncio.to_thread(self._credentials.refresh, Request())
            token = self._credentials.token
            if not token:
                raise GooglePlayUnavailableException(
                    "Google credentials did not produce an access token"
                )
            return token


def _timestamp(value: str | None) -> datetime | None:
    if value is None:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise GooglePlayVerificationException("Google Play returned an invalid timestamp") from exc
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise GooglePlayVerificationException("Google Play returned a timezone-less timestamp")
    return parsed


def parse_subscription(payload: dict[str, Any]) -> GooglePlaySnapshot:
    """Parse the fields Lotti authorizes from ``SubscriptionPurchaseV2``."""
    try:
        state = GoogleSubscriptionState(payload["subscriptionState"])
        acknowledgement = AcknowledgementState(payload["acknowledgementState"])
        line_items = tuple(
            GooglePlayLineItem(
                product_id=item["productId"],
                base_plan_id=(item.get("offerDetails") or {}).get("basePlanId"),
                expiry_time=_timestamp(item.get("expiryTime")),
                latest_successful_order_id=item.get("latestSuccessfulOrderId"),
            )
            for item in payload["lineItems"]
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise GooglePlayVerificationException(
            "Google Play returned an invalid subscription response"
        ) from exc
    if not line_items:
        raise GooglePlayVerificationException(
            "Google Play returned a subscription without line items"
        )

    external = payload.get("externalAccountIdentifiers") or {}
    out_of_app = payload.get("outOfAppPurchaseContext") or {}
    expired_external = out_of_app.get("expiredExternalAccountIdentifiers") or {}
    return GooglePlaySnapshot(
        state=state,
        acknowledgement_state=acknowledgement,
        line_items=line_items,
        start_time=_timestamp(payload.get("startTime")),
        linked_purchase_token=payload.get("linkedPurchaseToken"),
        obfuscated_external_account_id=external.get("obfuscatedExternalAccountId"),
        obfuscated_external_profile_id=external.get("obfuscatedExternalProfileId"),
        test_purchase="testPurchase" in payload,
        expired_purchase_token=out_of_app.get("expiredPurchaseToken"),
        expired_obfuscated_external_account_id=expired_external.get("obfuscatedExternalAccountId"),
        expired_obfuscated_external_profile_id=expired_external.get("obfuscatedExternalProfileId"),
    )


class GooglePlayClient:
    """Calls Android Publisher and Play Integrity with ADC authentication."""

    def __init__(
        self,
        token_provider: AccessTokenProvider,
        *,
        client: httpx.AsyncClient | None = None,
        timeout_seconds: float = 15.0,
    ):
        self._token_provider = token_provider
        self._client = client or httpx.AsyncClient()
        self._owns_client = client is None
        self._timeout = timeout_seconds

    async def _request(
        self,
        method: str,
        url: str,
        *,
        json: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        access_token = await self._token_provider.get_token()
        try:
            response = await self._client.request(
                method,
                url,
                headers={"Authorization": f"Bearer {access_token}"},
                json=json,
                timeout=self._timeout,
            )
        except httpx.HTTPError as exc:
            raise GooglePlayUnavailableException("Google Play request failed") from exc

        if response.status_code in (429, 500, 502, 503, 504):
            raise GooglePlayUnavailableException(
                f"Google Play temporarily failed with HTTP {response.status_code}"
            )
        if response.is_error:
            raise GooglePlayVerificationException(
                f"Google Play rejected the request with HTTP {response.status_code}"
            )
        if not response.content:
            return {}
        try:
            body = response.json()
        except ValueError as exc:
            raise GooglePlayVerificationException(
                "Google Play returned a non-JSON response"
            ) from exc
        if not isinstance(body, dict):
            raise GooglePlayVerificationException("Google Play returned an invalid response body")
        return body

    async def get_subscription(self, package_name: str, purchase_token: str) -> GooglePlaySnapshot:
        """Fetch and parse authoritative subscription state from Google."""
        package = quote(package_name, safe="")
        token = quote(purchase_token, safe="")
        payload = await self._request(
            "GET",
            f"{ANDROID_PUBLISHER_BASE_URL}/androidpublisher/v3/applications/"
            f"{package}/purchases/subscriptionsv2/tokens/{token}",
        )
        return parse_subscription(payload)

    async def acknowledge_subscription(
        self,
        package_name: str,
        product_id: str,
        purchase_token: str,
    ) -> None:
        """Acknowledge a newly granted purchase after durable persistence."""
        package = quote(package_name, safe="")
        product = quote(product_id, safe="")
        token = quote(purchase_token, safe="")
        await self._request(
            "POST",
            f"{ANDROID_PUBLISHER_BASE_URL}/androidpublisher/v3/applications/"
            f"{package}/purchases/subscriptions/{product}/tokens/{token}:acknowledge",
            json={},
        )

    async def decode_integrity_token(
        self, package_name: str, integrity_token: str
    ) -> dict[str, Any]:
        """Decode a standard Play Integrity token on Google's server."""
        package = quote(package_name, safe="")
        return await self._request(
            "POST",
            f"{PLAY_INTEGRITY_BASE_URL}/v1/{package}:decodeIntegrityToken",
            json={"integrity_token": integrity_token},
        )

    async def aclose(self) -> None:
        """Close the internally-owned HTTP pool."""
        if self._owns_client:
            await self._client.aclose()
