"""Authenticated HTTP boundary for the Paddle Billing API."""

from __future__ import annotations

from typing import Any
from urllib.parse import quote

import httpx

from ..core.exceptions import PaddleUnavailableException
from ..core.paddle import PaddleSubscription, parse_subscription

PADDLE_LIVE_BASE_URL = "https://api.paddle.com"
PADDLE_SANDBOX_BASE_URL = "https://sandbox-api.paddle.com"


class PaddleClient:
    """The two Paddle calls the service needs: read a subscription, open the portal."""

    def __init__(
        self,
        api_key: str,
        *,
        base_url: str = PADDLE_LIVE_BASE_URL,
        http_client: httpx.AsyncClient | None = None,
    ):
        if not api_key:
            raise ValueError("PADDLE_API_KEY is required")
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._http = http_client or httpx.AsyncClient(timeout=15.0)

    async def get_subscription(self, subscription_id: str) -> PaddleSubscription:
        """Return Paddle's authoritative view of one subscription."""
        payload = await self._request(
            "GET",
            f"/subscriptions/{quote(subscription_id, safe='')}",
        )
        return parse_subscription(payload)

    async def create_portal_url(self, customer_id: str, subscription_id: str) -> str:
        """Return a short-lived customer-portal link scoped to one subscription."""
        payload = await self._request(
            "POST",
            f"/customers/{quote(customer_id, safe='')}/portal-sessions",
            json={"subscription_ids": [subscription_id]},
        )
        # The overview is where cancelling, resuming and changing the payment
        # method all live, so it is the one link the app needs.
        overview = ((payload.get("urls") or {}).get("general") or {}).get("overview")
        if not overview:
            raise PaddleUnavailableException("Paddle portal session has no URL")
        return overview

    async def _request(self, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        try:
            response = await self._http.request(
                method,
                f"{self._base_url}{path}",
                headers={"Authorization": f"Bearer {self._api_key}"},
                **kwargs,
            )
        except httpx.HTTPError as exc:
            raise PaddleUnavailableException("Paddle API unreachable") from exc
        if response.status_code >= 400:
            raise PaddleUnavailableException(f"Paddle API returned HTTP {response.status_code}")
        try:
            data = response.json().get("data")
        except ValueError as exc:
            raise PaddleUnavailableException("Paddle API returned invalid JSON") from exc
        if not isinstance(data, dict):
            raise PaddleUnavailableException("Paddle API response has no data object")
        return data

    async def aclose(self) -> None:
        """Close the shared connection pool."""
        await self._http.aclose()
