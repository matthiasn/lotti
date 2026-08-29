"""Tests for normalizing Google Play subscription state into sync access."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from src.core.subscriptions import (
    EntitlementState,
    GoogleSubscriptionState,
    normalize_entitlement,
)


NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)
FUTURE = NOW + timedelta(days=3)
PAST = NOW - timedelta(microseconds=1)


@pytest.mark.parametrize(
    ("play_state", "expected_state"),
    [
        (GoogleSubscriptionState.ACTIVE, EntitlementState.ACTIVE),
        (GoogleSubscriptionState.IN_GRACE_PERIOD, EntitlementState.GRACE),
        (GoogleSubscriptionState.CANCELED, EntitlementState.CANCELED_ACTIVE),
    ],
)
def test_grantable_states_keep_access_until_google_expiry(play_state, expected_state):
    result = normalize_entitlement(play_state, expiry_time=FUTURE, now=NOW)

    assert result.state is expected_state
    assert result.access_granted is True
    assert result.access_deadline == FUTURE


@pytest.mark.parametrize(
    "play_state",
    [
        GoogleSubscriptionState.PENDING,
        GoogleSubscriptionState.PAUSED,
        GoogleSubscriptionState.ON_HOLD,
        GoogleSubscriptionState.PENDING_PURCHASE_CANCELED,
        GoogleSubscriptionState.UNSPECIFIED,
    ],
)
def test_non_grantable_states_suspend_access_immediately(play_state):
    result = normalize_entitlement(play_state, expiry_time=FUTURE, now=NOW)

    assert result.state is (
        EntitlementState.PENDING
        if play_state is GoogleSubscriptionState.PENDING
        else EntitlementState.SUSPENDED
    )
    assert result.access_granted is False
    assert result.access_deadline is None


def test_expired_google_state_is_terminal_even_with_future_line_item():
    result = normalize_entitlement(
        GoogleSubscriptionState.EXPIRED,
        expiry_time=FUTURE,
        now=NOW,
    )

    assert result.state is EntitlementState.EXPIRED
    assert result.access_granted is False
    assert result.access_deadline is None


@pytest.mark.parametrize(
    "play_state",
    [
        GoogleSubscriptionState.ACTIVE,
        GoogleSubscriptionState.CANCELED,
    ],
)
@pytest.mark.parametrize("expiry_time", [NOW, PAST])
def test_active_or_canceled_subscription_loses_access_at_expiry(play_state, expiry_time):
    result = normalize_entitlement(play_state, expiry_time=expiry_time, now=NOW)

    assert result.state is EntitlementState.EXPIRED
    assert result.access_granted is False
    assert result.access_deadline is None


@pytest.mark.parametrize("expiry_time", [NOW, PAST])
def test_grace_period_suspends_at_its_authoritative_deadline(expiry_time):
    result = normalize_entitlement(
        GoogleSubscriptionState.IN_GRACE_PERIOD,
        expiry_time=expiry_time,
        now=NOW,
    )

    assert result.state is EntitlementState.SUSPENDED
    assert result.access_granted is False
    assert result.access_deadline is None


@pytest.mark.parametrize("value", [None, datetime(2026, 8, 30, 12)])
def test_grantable_state_requires_an_aware_expiry(value):
    with pytest.raises(ValueError, match="timezone-aware"):
        normalize_entitlement(
            GoogleSubscriptionState.ACTIVE,
            expiry_time=value,
            now=NOW,
        )


def test_normalization_requires_an_aware_clock():
    with pytest.raises(ValueError, match="timezone-aware"):
        normalize_entitlement(
            GoogleSubscriptionState.ACTIVE,
            expiry_time=FUTURE,
            now=datetime(2026, 8, 29, 12),
        )
