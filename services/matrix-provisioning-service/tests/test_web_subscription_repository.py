"""Tests for checkout-session and Paddle event persistence."""

# ruff: noqa: S105,S106 - explicit non-production credential fixtures

from __future__ import annotations

import sqlite3
from datetime import timedelta

import pytest
from src.core.subscriptions import CheckoutSession
from src.services.web_subscription_repository import WebSubscriptionRepository
from tests.paddle_fixtures import MONTHLY_PRICE, NOW

pytestmark = pytest.mark.anyio


@pytest.fixture
async def repository(tmp_path):
    repo = WebSubscriptionRepository(str(tmp_path / "web.db"))
    await repo.create_entitlement(
        entitlement_id="entitlement-one",
        obfuscated_account_id="obfuscated-one",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    return repo


def session(session_id="session-one", *, created_at=NOW, ttl=timedelta(minutes=30)):
    return CheckoutSession(
        session_id=session_id,
        entitlement_id="entitlement-one",
        claim_secret_hash="claim-hash",
        price_id=MONTHLY_PRICE,
        expires_at=created_at + ttl,
        bound_token_fingerprint=None,
        bound_at=None,
        created_at=created_at,
    )


async def test_session_round_trips_unbound(repository):
    await repository.create_checkout_session(session())

    stored = await repository.get_checkout_session("session-one")

    assert stored == session()
    assert await repository.get_checkout_session("missing") is None


async def test_first_binding_wins_and_is_findable_by_subscription(repository):
    await repository.create_checkout_session(session())

    bound = await repository.bind_checkout_session(
        "session-one", token_fingerprint="fp-one", now=NOW + timedelta(minutes=1)
    )
    rebound = await repository.bind_checkout_session(
        "session-one", token_fingerprint="fp-two", now=NOW + timedelta(minutes=2)
    )

    assert bound.bound_token_fingerprint == "fp-one"
    assert bound.bound_at == NOW + timedelta(minutes=1)
    assert rebound.bound_token_fingerprint == "fp-one"
    found = await repository.get_bound_checkout_session(
        "entitlement-one", token_fingerprint="fp-one"
    )
    assert found.session_id == "session-one"
    assert (
        await repository.get_bound_checkout_session("entitlement-one", token_fingerprint="fp-two")
        is None
    )


async def test_binding_an_unknown_session_returns_none(repository):
    assert (
        await repository.bind_checkout_session("missing", token_fingerprint="fp", now=NOW) is None
    )


async def test_creating_a_session_prunes_long_expired_unbound_ones(repository):
    stale = session("stale", created_at=NOW - timedelta(days=3))
    kept_bound = session("bound", created_at=NOW - timedelta(days=3))
    await repository.create_checkout_session(stale)
    await repository.create_checkout_session(kept_bound)
    await repository.bind_checkout_session("bound", token_fingerprint="fp", now=NOW)

    await repository.create_checkout_session(session("fresh"))

    assert await repository.get_checkout_session("stale") is None
    assert await repository.get_checkout_session("bound") is not None
    assert await repository.get_checkout_session("fresh") is not None


async def test_webhook_ledger_records_each_event_once(repository):
    assert await repository.webhook_event_processed("evt_01") is False

    await repository.record_webhook_event(
        "evt_01", event_type="subscription.activated", occurred_at=NOW, now=NOW
    )
    await repository.record_webhook_event(
        "evt_01", event_type="subscription.activated", occurred_at=NOW, now=NOW
    )

    assert await repository.webhook_event_processed("evt_01") is True
    assert await repository.webhook_event_processed("evt_02") is False


async def test_opening_reuses_the_open_session_for_the_same_price(repository):
    first = await repository.open_checkout_session(session("first"))
    again = await repository.open_checkout_session(session("second"))
    later = await repository.open_checkout_session(
        session("later", created_at=NOW + timedelta(hours=1))
    )

    assert first.session_id == "first"
    assert again.session_id == "first"
    # Once the first has expired a new one is stored.
    assert later.session_id == "later"
    assert await repository.get_checkout_session("second") is None


async def test_a_failed_open_stores_nothing(repository):
    await repository.open_checkout_session(session("first"))
    duplicate = session("first", created_at=NOW + timedelta(hours=1))

    with pytest.raises(sqlite3.IntegrityError):
        await repository.open_checkout_session(duplicate)
