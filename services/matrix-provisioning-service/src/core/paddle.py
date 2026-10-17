"""Paddle Billing webhook verification and subscription interpretation.

Paddle is the merchant of record for web checkout. Its subscription lifecycle
is mapped onto the Google Play state vocabulary in ``subscriptions`` so the
existing entitlement state machine, escrow, suspension and reaper govern both
providers without a second copy.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Any

from .exceptions import PaddleWebhookException
from .subscriptions import GoogleSubscriptionState

#: Paddle signs ``ts:raw_body``; deliveries older than this are replays.
SIGNATURE_TOLERANCE = timedelta(minutes=5)

#: Paddle renews at the period boundary and the renewal webhook can trail it.
#: Access survives this long past ``ends_at`` so a slow webhook does not
#: suspend a paying user, while a missed one still fails closed.
RENEWAL_DELIVERY_BUFFER = timedelta(days=1)


class PaddleSubscriptionStatus(str, Enum):
    """``subscription.status`` values in Paddle Billing."""

    ACTIVE = "active"
    TRIALING = "trialing"
    PAST_DUE = "past_due"
    PAUSED = "paused"
    CANCELED = "canceled"


@dataclass(frozen=True)
class PaddleSubscription:
    """The fields of a Paddle subscription entity that decide access."""

    subscription_id: str
    customer_id: str
    status: PaddleSubscriptionStatus
    price_id: str
    product_id: str
    started_at: datetime | None
    period_starts_at: datetime | None
    period_ends_at: datetime | None
    cancel_scheduled: bool
    checkout_session_id: str | None


@dataclass(frozen=True)
class PaddleWebhookEvent:
    """A verified notification; ``subscription`` is set for ``subscription.*``."""

    event_id: str
    event_type: str
    occurred_at: datetime
    subscription: PaddleSubscription | None


@dataclass(frozen=True)
class PaddleAccess:
    """Paddle state expressed in the shared Play vocabulary."""

    play_state: GoogleSubscriptionState
    access_deadline: datetime | None


def verify_signature(
    raw_body: bytes,
    signature_header: str,
    secret: str,
    *,
    now: datetime,
    tolerance: timedelta = SIGNATURE_TOLERANCE,
) -> None:
    """Reject anything not signed by Paddle for this destination, or replayed.

    The header is ``ts=<unix>;h1=<hex>``; during secret rotation Paddle sends
    one ``h1`` per active secret, so any match is accepted.
    """
    if not secret:
        raise PaddleWebhookException("Paddle webhook secret is not configured")
    timestamp: str | None = None
    signatures: list[str] = []
    for part in signature_header.split(";"):
        key, _, value = part.strip().partition("=")
        if key == "ts":
            timestamp = value
        elif key == "h1" and value:
            signatures.append(value)
    if timestamp is None or not signatures:
        raise PaddleWebhookException("Malformed Paddle-Signature header")
    try:
        signed_at = int(timestamp)
    except ValueError as exc:
        raise PaddleWebhookException("Malformed Paddle-Signature timestamp") from exc
    if abs(now.timestamp() - signed_at) > tolerance.total_seconds():
        raise PaddleWebhookException("Paddle signature timestamp outside tolerance")
    expected = hmac.new(
        secret.encode(),
        timestamp.encode() + b":" + raw_body,
        hashlib.sha256,
    ).hexdigest()
    if not any(hmac.compare_digest(expected, candidate) for candidate in signatures):
        raise PaddleWebhookException("Paddle signature mismatch")


def parse_event(payload: dict[str, Any]) -> PaddleWebhookEvent:
    """Parse a verified webhook body into the fields this service acts on."""
    try:
        event_id = _required_str(payload, "event_id")
        event_type = _required_str(payload, "event_type")
        occurred_at = _required_time(payload, "occurred_at")
        data = payload.get("data")
        if not isinstance(data, dict):
            raise PaddleWebhookException("Paddle event has no data object")
    except PaddleWebhookException:
        raise
    except (TypeError, ValueError) as exc:
        raise PaddleWebhookException("Malformed Paddle event") from exc
    subscription = parse_subscription(data) if event_type.startswith("subscription.") else None
    return PaddleWebhookEvent(
        event_id=event_id,
        event_type=event_type,
        occurred_at=occurred_at,
        subscription=subscription,
    )


def parse_subscription(data: dict[str, Any]) -> PaddleSubscription:
    """Parse a Paddle subscription entity (webhook ``data`` or API ``data``)."""
    try:
        items = data.get("items") or []
        if not items or not isinstance(items[0], dict):
            raise PaddleWebhookException("Paddle subscription has no items")
        price = items[0].get("price") or {}
        period = data.get("current_billing_period") or {}
        scheduled = data.get("scheduled_change") or {}
        custom_data = data.get("custom_data") or {}
        session_id = custom_data.get("checkout_session_id")
        return PaddleSubscription(
            subscription_id=_required_str(data, "id"),
            customer_id=_required_str(data, "customer_id"),
            status=PaddleSubscriptionStatus(data.get("status")),
            price_id=_required_str(price, "id"),
            product_id=_required_str(price, "product_id"),
            started_at=_optional_time(data.get("started_at")),
            period_starts_at=_optional_time(period.get("starts_at")),
            period_ends_at=_optional_time(period.get("ends_at")),
            cancel_scheduled=scheduled.get("action") == "cancel",
            checkout_session_id=session_id if isinstance(session_id, str) else None,
        )
    except PaddleWebhookException:
        raise
    except (AttributeError, TypeError, ValueError) as exc:
        raise PaddleWebhookException("Malformed Paddle subscription") from exc


def interpret(
    subscription: PaddleSubscription,
    *,
    observed_at: datetime,
    grace_period: timedelta,
) -> PaddleAccess:
    """Translate a Paddle subscription into Play state plus an access deadline.

    ``past_due`` means a renewal charge failed and Paddle is retrying; access
    continues for ``grace_period`` from the start of the unpaid period. A
    scheduled cancellation keeps access until the paid period ends.
    """
    status = subscription.status
    if status is PaddleSubscriptionStatus.CANCELED:
        return PaddleAccess(GoogleSubscriptionState.EXPIRED, None)
    if status is PaddleSubscriptionStatus.PAUSED:
        return PaddleAccess(GoogleSubscriptionState.PAUSED, None)
    if status is PaddleSubscriptionStatus.PAST_DUE:
        unpaid_since = subscription.period_starts_at or observed_at
        return PaddleAccess(
            GoogleSubscriptionState.IN_GRACE_PERIOD,
            unpaid_since + grace_period,
        )
    if subscription.period_ends_at is None:
        raise PaddleWebhookException("Active Paddle subscription has no billing period")
    if subscription.cancel_scheduled:
        return PaddleAccess(GoogleSubscriptionState.CANCELED, subscription.period_ends_at)
    return PaddleAccess(
        GoogleSubscriptionState.ACTIVE,
        subscription.period_ends_at + RENEWAL_DELIVERY_BUFFER,
    )


def _required_str(container: dict[str, Any], key: str) -> str:
    value = container.get(key)
    if not isinstance(value, str) or not value:
        raise PaddleWebhookException(f"Paddle field {key!r} is missing")
    return value


def _required_time(container: dict[str, Any], key: str) -> datetime:
    parsed = _optional_time(container.get(key))
    if parsed is None:
        raise PaddleWebhookException(f"Paddle field {key!r} is missing")
    return parsed


def _optional_time(value: Any) -> datetime | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise PaddleWebhookException("Paddle timestamp is not a string")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise PaddleWebhookException("Paddle timestamp has no timezone")
    return parsed
