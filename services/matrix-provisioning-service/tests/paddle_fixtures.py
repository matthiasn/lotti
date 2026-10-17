"""Paddle Billing payloads shaped like the real API, shared by the web tests."""

from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone
from typing import Any

NOW = datetime(2026, 10, 17, 12, tzinfo=timezone.utc)
WEBHOOK_SECRET = "pdl_ntfset_test_secret"  # noqa: S105 - test fixture
MONTHLY_PRICE = "pri_monthly"
ANNUAL_PRICE = "pri_annual"
PRODUCT = "pro_lotti_sync"


def subscription_payload(
    *,
    subscription_id: str = "sub_01",
    customer_id: str = "ctm_01",
    status: str = "active",
    price_id: str = MONTHLY_PRICE,
    session_id: str | None = "session-one",
    period_start: datetime | None = NOW,
    period_end: datetime | None = NOW + timedelta(days=30),
    scheduled_action: str | None = None,
) -> dict[str, Any]:
    """A Paddle ``subscription`` entity as webhooks and the API return it."""
    period = (
        {"starts_at": _ts(period_start), "ends_at": _ts(period_end)}
        if period_start is not None and period_end is not None
        else None
    )
    return {
        "id": subscription_id,
        "status": status,
        "customer_id": customer_id,
        "started_at": _ts(NOW),
        "current_billing_period": period,
        "scheduled_change": (
            {"action": scheduled_action, "effective_at": _ts(period_end)}
            if scheduled_action
            else None
        ),
        "items": [{"price": {"id": price_id, "product_id": PRODUCT}, "quantity": 1}],
        "custom_data": {"checkout_session_id": session_id} if session_id else None,
    }


def event_payload(
    data: dict[str, Any],
    *,
    event_id: str = "evt_01",
    event_type: str = "subscription.activated",
    occurred_at: datetime = NOW,
) -> dict[str, Any]:
    """A Paddle notification envelope."""
    return {
        "event_id": event_id,
        "event_type": event_type,
        "occurred_at": _ts(occurred_at),
        "notification_id": f"ntf_{event_id}",
        "data": data,
    }


def signed(
    payload: dict[str, Any],
    *,
    secret: str = WEBHOOK_SECRET,
    at: datetime = NOW,
) -> tuple[bytes, str]:
    """Serialize and sign exactly as Paddle does: HMAC-SHA256 over ``ts:body``."""
    body = json.dumps(payload).encode()
    timestamp = str(int(at.timestamp()))
    digest = hmac.new(secret.encode(), timestamp.encode() + b":" + body, hashlib.sha256)
    return body, f"ts={timestamp};h1={digest.hexdigest()}"


def _ts(value: datetime | None) -> str | None:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z") if value else None
