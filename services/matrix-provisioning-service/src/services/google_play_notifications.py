"""Authenticated Pub/Sub processing for Google Play RTDN lifecycle signals."""

from __future__ import annotations

import asyncio
import base64
import binascii
import json
from datetime import datetime, timezone
from typing import Any, Callable

from google.auth.transport.requests import Request
from google.oauth2 import id_token

from ..core.exceptions import (
    GooglePlayVerificationException,
    PubSubAuthenticationException,
)
from ..core.subscriptions import (
    RealtimeDeveloperNotification,
    RealtimeDeveloperTestNotification,
    StoredSubscription,
)
from .subscription_access_service import SubscriptionAccessService
from .subscription_repository import SubscriptionRepository
from .subscription_service import SubscriptionService


def _verify_google_token(token: str, audience: str) -> dict[str, Any]:
    return id_token.verify_oauth2_token(token, Request(), audience=audience)


class PubSubAuthenticator:
    """Verifies the OIDC identity Google attaches to Pub/Sub push requests."""

    def __init__(
        self,
        *,
        audience: str,
        service_account_email: str,
        verifier: Callable[[str, str], dict[str, Any]] = _verify_google_token,
    ):
        self._audience = audience
        self._service_account_email = service_account_email
        self._verifier = verifier

    async def authenticate(self, authorization: str) -> dict[str, Any]:
        """Verify signature, audience, issuer, and exact push service identity."""
        parts = authorization.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise PubSubAuthenticationException("Missing Pub/Sub bearer token")
        try:
            claims = await asyncio.to_thread(
                self._verifier,
                parts[1],
                self._audience,
            )
        except Exception as exc:
            raise PubSubAuthenticationException("Invalid Pub/Sub bearer token") from exc
        if (
            claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com")
            or claims.get("aud") != self._audience
            or claims.get("email") != self._service_account_email
            or claims.get("email_verified") is not True
        ):
            raise PubSubAuthenticationException("Pub/Sub identity is not authorized")
        return claims


def parse_rtdn_envelope(
    envelope: dict[str, Any],
) -> RealtimeDeveloperNotification | RealtimeDeveloperTestNotification:
    """Decode a Pub/Sub envelope without trusting its lifecycle state."""
    try:
        encoded = envelope["message"]["data"]
        raw = base64.b64decode(encoded, validate=True)
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise TypeError("RTDN payload must be an object")
        event_time = datetime.fromtimestamp(
            int(payload["eventTimeMillis"]) / 1000,
            tz=timezone.utc,
        )
        package_name = payload["packageName"]
        is_test = "testNotification" in payload
        has_subscription = "subscriptionNotification" in payload
        if is_test == has_subscription:
            raise ValueError("RTDN must contain exactly one notification")
        if is_test:
            test_notification = payload["testNotification"]
            if not isinstance(test_notification, dict) or not test_notification.get("version"):
                raise ValueError("Malformed test notification")
            result = RealtimeDeveloperTestNotification(
                package_name=package_name,
                event_time=event_time,
            )
        else:
            notification = payload["subscriptionNotification"]
            result = RealtimeDeveloperNotification(
                package_name=package_name,
                purchase_token=notification["purchaseToken"],
                notification_type=int(notification["notificationType"]),
                event_time=event_time,
            )
    except (
        KeyError,
        TypeError,
        ValueError,
        OverflowError,
        binascii.Error,
        json.JSONDecodeError,
    ) as exc:
        raise GooglePlayVerificationException("Malformed RTDN envelope") from exc
    if not result.package_name or (
        isinstance(result, RealtimeDeveloperNotification) and not result.purchase_token
    ):
        raise GooglePlayVerificationException("Malformed RTDN envelope")
    return result


class GooglePlayNotificationService:
    """Treat RTDN only as a signal to re-query a previously bound token."""

    def __init__(
        self,
        authenticator: PubSubAuthenticator,
        subscription_service: SubscriptionService,
        access_service: SubscriptionAccessService,
        repository: SubscriptionRepository,
        *,
        package_name: str,
    ):
        self._authenticator = authenticator
        self._subscription_service = subscription_service
        self._access_service = access_service
        self._repository = repository
        self._package_name = package_name

    async def handle(
        self,
        envelope: dict[str, Any],
        *,
        authorization: str,
        now: datetime,
    ) -> StoredSubscription | None:
        """Authenticate, acknowledge tests, or re-query and converge access."""
        await self._authenticator.authenticate(authorization)
        notification = parse_rtdn_envelope(envelope)
        if notification.package_name != self._package_name:
            raise GooglePlayVerificationException("RTDN package name does not match")
        if isinstance(notification, RealtimeDeveloperTestNotification):
            return None
        subscription = await self._subscription_service.refresh_known_purchase(
            notification.purchase_token,
            now=now,
        )
        current = await self._repository.get_current_subscription(subscription.entitlement_id)
        if current is not None:
            await self._access_service.enforce(current, now=now)
        return subscription
