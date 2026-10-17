"""Tests for Paddle signature verification, parsing and state mapping."""

# ruff: noqa: S105,S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import timedelta

import pytest
from src.core.exceptions import PaddleWebhookException
from src.core.paddle import (
    RENEWAL_DELIVERY_BUFFER,
    PaddleSubscriptionStatus,
    interpret,
    parse_event,
    parse_subscription,
    verify_signature,
)
from src.core.subscriptions import GoogleSubscriptionState
from tests.paddle_fixtures import (
    MONTHLY_PRICE,
    NOW,
    PRODUCT,
    WEBHOOK_SECRET,
    event_payload,
    signed,
    subscription_payload,
)

GRACE = timedelta(days=7)


def test_signature_accepts_paddles_own_construction():
    body, header = signed(event_payload(subscription_payload()))

    verify_signature(body, header, WEBHOOK_SECRET, now=NOW)


def test_signature_accepts_any_h1_during_secret_rotation():
    body, header = signed(event_payload(subscription_payload()))
    timestamp, current = header.split(";")
    rotated = f"{timestamp};h1={'0' * 64};{current}"

    verify_signature(body, rotated, WEBHOOK_SECRET, now=NOW)


@pytest.mark.parametrize(
    ("mutate", "message"),
    [
        (lambda body, header: (body + b" ", header), "mismatch"),
        (lambda body, header: (body, header.replace("h1=", "h2=")), "Malformed"),
        (lambda body, header: (body, "ts=abc;h1=00"), "timestamp"),
        (lambda body, header: (body, ""), "Malformed"),
    ],
)
def test_signature_rejects_tampering_and_garbage(mutate, message):
    body, header = mutate(*signed(event_payload(subscription_payload())))

    with pytest.raises(PaddleWebhookException, match=message):
        verify_signature(body, header, WEBHOOK_SECRET, now=NOW)


def test_signature_rejects_a_different_destination_secret():
    body, header = signed(event_payload(subscription_payload()), secret="other-secret")

    with pytest.raises(PaddleWebhookException, match="mismatch"):
        verify_signature(body, header, WEBHOOK_SECRET, now=NOW)


def test_signature_rejects_replays_outside_the_window():
    body, header = signed(event_payload(subscription_payload()), at=NOW - timedelta(minutes=6))

    with pytest.raises(PaddleWebhookException, match="tolerance"):
        verify_signature(body, header, WEBHOOK_SECRET, now=NOW)


def test_signature_refuses_to_run_without_a_secret():
    body, header = signed(event_payload(subscription_payload()))

    with pytest.raises(PaddleWebhookException, match="not configured"):
        verify_signature(body, header, "", now=NOW)


def test_parse_event_extracts_subscription_and_session():
    event = parse_event(event_payload(subscription_payload(scheduled_action="cancel")))

    assert event.event_id == "evt_01"
    assert event.event_type == "subscription.activated"
    assert event.occurred_at == NOW
    subscription = event.subscription
    assert subscription is not None
    assert subscription.subscription_id == "sub_01"
    assert subscription.customer_id == "ctm_01"
    assert subscription.status is PaddleSubscriptionStatus.ACTIVE
    assert (subscription.price_id, subscription.product_id) == (MONTHLY_PRICE, PRODUCT)
    assert subscription.period_ends_at == NOW + timedelta(days=30)
    assert subscription.cancel_scheduled is True
    assert subscription.checkout_session_id == "session-one"


def test_parse_event_leaves_non_subscription_events_without_subscription():
    event = parse_event(
        event_payload({"id": "txn_01"}, event_type="transaction.completed"),
    )

    assert event.subscription is None


@pytest.mark.parametrize(
    "payload",
    [
        {"event_type": "subscription.updated", "occurred_at": "2026-10-17T12:00:00Z", "data": {}},
        {"event_id": "e", "event_type": "x", "occurred_at": "2026-10-17T12:00:00", "data": {}},
        {"event_id": "e", "event_type": "x", "occurred_at": "2026-10-17T12:00:00Z"},
        {"event_id": "e", "event_type": "x", "occurred_at": 17, "data": {}},
        {"event_id": "e", "event_type": "x", "occurred_at": "yesterday", "data": {}},
        {"event_id": "e", "event_type": "x", "data": {}},
    ],
)
def test_parse_event_rejects_malformed_envelopes(payload):
    with pytest.raises(PaddleWebhookException):
        parse_event(payload)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda data: data.update(items=[]),
        lambda data: data.update(status="exploded"),
        lambda data: data.pop("customer_id"),
        lambda data: data["items"][0].update(price={"id": "pri"}),
    ],
)
def test_parse_subscription_rejects_incomplete_entities(mutate):
    data = subscription_payload()
    mutate(data)

    with pytest.raises(PaddleWebhookException):
        parse_subscription(data)


def test_parse_subscription_ignores_foreign_custom_data():
    data = subscription_payload(session_id=None)
    data["custom_data"] = {"checkout_session_id": 42}

    assert parse_subscription(data).checkout_session_id is None


def test_active_subscription_keeps_access_past_period_end_for_late_renewals():
    access = interpret(
        parse_subscription(subscription_payload()),
        observed_at=NOW,
        grace_period=GRACE,
    )

    assert access.play_state is GoogleSubscriptionState.ACTIVE
    assert access.access_deadline == NOW + timedelta(days=30) + RENEWAL_DELIVERY_BUFFER


def test_trialing_counts_as_active():
    access = interpret(
        parse_subscription(subscription_payload(status="trialing")),
        observed_at=NOW,
        grace_period=GRACE,
    )

    assert access.play_state is GoogleSubscriptionState.ACTIVE


def test_scheduled_cancellation_ends_exactly_at_the_paid_period():
    access = interpret(
        parse_subscription(subscription_payload(scheduled_action="cancel")),
        observed_at=NOW,
        grace_period=GRACE,
    )

    assert access.play_state is GoogleSubscriptionState.CANCELED
    assert access.access_deadline == NOW + timedelta(days=30)


def test_past_due_grants_grace_from_the_unpaid_period_start():
    access = interpret(
        parse_subscription(subscription_payload(status="past_due")),
        observed_at=NOW + timedelta(days=2),
        grace_period=GRACE,
    )

    assert access.play_state is GoogleSubscriptionState.IN_GRACE_PERIOD
    assert access.access_deadline == NOW + GRACE


def test_past_due_without_a_period_counts_grace_from_observation():
    access = interpret(
        parse_subscription(
            subscription_payload(status="past_due", period_start=None, period_end=None)
        ),
        observed_at=NOW,
        grace_period=GRACE,
    )

    assert access.access_deadline == NOW + GRACE


@pytest.mark.parametrize(
    ("status", "state"),
    [
        ("canceled", GoogleSubscriptionState.EXPIRED),
        ("paused", GoogleSubscriptionState.PAUSED),
    ],
)
def test_ended_and_paused_subscriptions_grant_nothing(status, state):
    access = interpret(
        parse_subscription(subscription_payload(status=status, period_start=None, period_end=None)),
        observed_at=NOW,
        grace_period=GRACE,
    )

    assert access.play_state is state
    assert access.access_deadline is None


def test_active_subscription_without_a_period_is_rejected():
    with pytest.raises(PaddleWebhookException, match="billing period"):
        interpret(
            parse_subscription(subscription_payload(period_start=None, period_end=None)),
            observed_at=NOW,
            grace_period=GRACE,
        )
