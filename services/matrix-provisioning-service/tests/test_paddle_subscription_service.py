"""Tests for applying Paddle webhooks and refreshes to the entitlement store."""

# ruff: noqa: S105,S106 - explicit non-production credential fixtures

from __future__ import annotations

import hashlib
import hmac
from dataclasses import replace
from datetime import datetime, timedelta

import pytest
from src.core.exceptions import (
    GooglePlayVerificationException,
    PaddleWebhookException,
)
from src.core.paddle import RENEWAL_DELIVERY_BUFFER, parse_subscription
from src.core.subscriptions import (
    CheckoutSession,
    EntitlementState,
    GoogleSubscriptionState,
    SubscriptionProvider,
)
from src.services.paddle_subscription_service import (
    PaddleSubscriptionService,
    paddle_token_fingerprint,
)
from src.services.secret_cipher import SecretCipher
from src.services.web_subscription_repository import WebSubscriptionRepository
from tests.paddle_fixtures import (
    ANNUAL_PRICE,
    MONTHLY_PRICE,
    NOW,
    WEBHOOK_SECRET,
    event_payload,
    signed,
    subscription_payload,
)

pytestmark = pytest.mark.anyio


class FakeAccessService:
    def __init__(self):
        self.enforced = []

    async def enforce(self, subscription, *, now):
        self.enforced.append((subscription.token_fingerprint, subscription.entitlement_state))


class FakePaddleClient:
    def __init__(self):
        self.subscription = None
        self.fetched = []
        self.portal_calls = []

    async def get_subscription(self, subscription_id):
        self.fetched.append(subscription_id)
        return self.subscription

    async def create_portal_url(self, customer_id, subscription_id):
        self.portal_calls.append((customer_id, subscription_id))
        return "https://customer-portal.paddle.com/cpl_01"


class Clock:
    def __init__(self, now: datetime):
        self.now = now

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
async def repository(tmp_path):
    repo = WebSubscriptionRepository(str(tmp_path / "web.db"))
    await repo.create_entitlement(
        entitlement_id="entitlement-one",
        obfuscated_account_id="obfuscated-one",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    for session_id in ("session-one", "session-two"):
        await repo.create_checkout_session(
            CheckoutSession(
                session_id=session_id,
                entitlement_id="entitlement-one",
                claim_secret_hash="claim-hash",
                price_id=MONTHLY_PRICE,
                expires_at=NOW + timedelta(minutes=30),
                bound_token_fingerprint=None,
                bound_at=None,
                created_at=NOW,
            )
        )
    return repo


@pytest.fixture
def clock():
    return Clock(NOW)


@pytest.fixture
def access():
    return FakeAccessService()


@pytest.fixture
def paddle():
    return FakePaddleClient()


@pytest.fixture
def service(repository, access, paddle, clock):
    return PaddleSubscriptionService(
        repository,
        access,
        SecretCipher(key_id="key-v1", key=bytes(range(32))),
        paddle,
        webhook_secret=WEBHOOK_SECRET,
        allowed_price_ids=frozenset({MONTHLY_PRICE, ANNUAL_PRICE}),
        now_provider=clock,
    )


@pytest.fixture
def deliver(service, clock):
    """Deliver an event signed at the service's current time, as Paddle would."""

    async def _deliver(data, **event):
        return await service.handle_webhook(*signed(event_payload(data, **event), at=clock.now))

    return _deliver


async def test_service_needs_at_least_one_price(repository, access, paddle):
    with pytest.raises(ValueError, match="price"):
        PaddleSubscriptionService(
            repository,
            access,
            SecretCipher(key_id="k", key=bytes(range(32))),
            paddle,
            webhook_secret=WEBHOOK_SECRET,
            allowed_price_ids=frozenset(),
        )


async def test_first_event_binds_session_and_grants_access(service, repository, access, deliver):
    outcome = await deliver(subscription_payload())

    fingerprint = paddle_token_fingerprint("sub_01")
    stored = await repository.get_current_subscription("entitlement-one")
    assert outcome == "applied"
    assert stored.provider is SubscriptionProvider.PADDLE
    assert stored.token_fingerprint == fingerprint
    assert stored.google_state is GoogleSubscriptionState.ACTIVE
    assert stored.entitlement_state is EntitlementState.ACTIVE
    assert stored.current_period_end == NOW + timedelta(days=30) + RENEWAL_DELIVERY_BUFFER
    assert stored.base_plan_id == MONTHLY_PRICE
    session = await repository.get_checkout_session("session-one")
    assert session.bound_token_fingerprint == fingerprint
    assert access.enforced == [(fingerprint, EntitlementState.ACTIVE)]


async def test_sealed_reference_round_trips_paddle_ids(service, repository, deliver):
    await deliver(subscription_payload())

    stored = await repository.get_current_subscription("entitlement-one")
    reference = service.reference(stored)

    assert (reference.subscription_id, reference.customer_id) == ("sub_01", "ctm_01")
    assert b"sub_01" not in stored.encrypted_purchase_token


async def test_reference_refuses_play_rows(service, repository, deliver):
    await deliver(subscription_payload())
    stored = await repository.get_current_subscription("entitlement-one")

    with pytest.raises(ValueError, match="Not a Paddle"):
        service.reference(replace(stored, provider=SubscriptionProvider.GOOGLE_PLAY))


async def test_duplicate_delivery_is_acknowledged_without_reapplying(service, access, deliver):
    await deliver(subscription_payload())

    outcome = await deliver(subscription_payload())

    assert outcome == "duplicate"
    assert len(access.enforced) == 1


async def test_later_events_resolve_by_subscription_without_custom_data(
    service, repository, clock, deliver
):
    await deliver(subscription_payload())
    clock.now = NOW + timedelta(days=2)

    await deliver(
        subscription_payload(session_id=None, status="past_due"),
        event_id="evt_02",
        event_type="subscription.past_due",
        occurred_at=NOW + timedelta(days=2),
    )

    stored = await repository.get_current_subscription("entitlement-one")
    assert stored.entitlement_state is EntitlementState.GRACE
    assert stored.grace_deadline == NOW + timedelta(days=7)


async def test_out_of_order_events_cannot_roll_state_back(service, repository, clock, deliver):
    clock.now = NOW + timedelta(hours=1)
    await deliver(
        subscription_payload(scheduled_action="cancel"),
        event_id="evt_cancel",
        event_type="subscription.updated",
        occurred_at=NOW + timedelta(hours=1),
    )

    await deliver(subscription_payload(), event_id="evt_activated", occurred_at=NOW)

    stored = await repository.get_current_subscription("entitlement-one")
    assert stored.entitlement_state is EntitlementState.CANCELED_ACTIVE


async def test_cancellation_ends_access_and_enforces_suspension(
    service, repository, access, clock, deliver
):
    await deliver(subscription_payload())
    clock.now = NOW + timedelta(days=31)

    await deliver(
        subscription_payload(
            session_id=None, status="canceled", period_start=None, period_end=None
        ),
        event_id="evt_02",
        event_type="subscription.canceled",
        occurred_at=clock.now,
    )

    stored = await repository.get_current_subscription("entitlement-one")
    assert stored.entitlement_state is EntitlementState.EXPIRED
    assert access.enforced[-1] == (stored.token_fingerprint, EntitlementState.EXPIRED)


async def test_enforcement_bookkeeping_survives_an_upsert(service, repository, clock, deliver):
    await deliver(subscription_payload())
    stored = await repository.get_current_subscription("entitlement-one")
    await repository.record_subscription_enforcement(
        stored.token_fingerprint,
        suspended=True,
        now=NOW + timedelta(minutes=1),
    )
    clock.now = NOW + timedelta(minutes=2)

    await deliver(
        subscription_payload(session_id=None),
        event_id="evt_02",
        event_type="subscription.updated",
        occurred_at=clock.now,
    )

    refreshed = await repository.get_current_subscription("entitlement-one")
    assert refreshed.matrix_suspended is True
    assert refreshed.suspended_at == NOW + timedelta(minutes=1)


@pytest.mark.parametrize(
    ("data", "outcome"),
    [
        (subscription_payload(price_id="pri_unrelated"), "ignored-price"),
        (subscription_payload(session_id="no-such-session"), "ignored-session"),
        (subscription_payload(session_id=None), "ignored-unbound"),
    ],
)
async def test_unattributable_subscriptions_are_acknowledged_but_not_stored(
    service, repository, data, outcome, deliver
):
    assert await deliver(data) == outcome

    assert await repository.get_current_subscription("entitlement-one") is None
    assert await repository.webhook_event_processed("evt_01") is True


async def test_non_subscription_events_are_acknowledged(service, repository, deliver):
    outcome = await deliver({"id": "txn_01"}, event_type="transaction.completed")

    assert outcome == "ignored"
    assert await repository.webhook_event_processed("evt_01") is True


@pytest.mark.parametrize("body", [b"not json", b"[1, 2]"])
async def test_signed_garbage_is_rejected(service, body):
    timestamp = str(int(NOW.timestamp()))
    digest = hmac.new(WEBHOOK_SECRET.encode(), timestamp.encode() + b":" + body, hashlib.sha256)

    with pytest.raises(PaddleWebhookException):
        await service.handle_webhook(body, f"ts={timestamp};h1={digest.hexdigest()}")


async def test_unsigned_delivery_is_rejected_and_not_recorded(service, repository):
    body, _ = signed(event_payload(subscription_payload()))

    with pytest.raises(PaddleWebhookException):
        await service.handle_webhook(body, "ts=1;h1=00")

    assert await repository.webhook_event_processed("evt_01") is False


async def test_second_checkout_replaces_the_first_as_access_source(service, repository, deliver):
    await deliver(subscription_payload())

    await deliver(
        subscription_payload(subscription_id="sub_02", session_id="session-two"),
        event_id="evt_02",
    )

    current = await repository.get_current_subscription("entitlement-one")
    assert current.token_fingerprint == paddle_token_fingerprint("sub_02")
    assert current.linked_token_fingerprint == paddle_token_fingerprint("sub_01")


async def test_a_non_granting_replacement_is_refused_and_not_recorded(service, repository, deliver):
    await deliver(subscription_payload())

    with pytest.raises(GooglePlayVerificationException):
        await deliver(
            subscription_payload(
                subscription_id="sub_02",
                session_id="session-two",
                status="canceled",
                period_start=None,
                period_end=None,
            ),
            event_id="evt_02",
        )

    assert await repository.webhook_event_processed("evt_02") is False


async def test_refresh_reapplies_paddles_current_view(service, repository, paddle, clock, deliver):
    await deliver(subscription_payload())
    stored = await repository.get_current_subscription("entitlement-one")
    renewed_end = NOW + timedelta(days=60)
    paddle.subscription = parse_subscription(
        subscription_payload(period_start=NOW + timedelta(days=30), period_end=renewed_end)
    )
    clock.now = NOW + timedelta(days=29)

    await service.refresh(stored)

    refreshed = await repository.get_current_subscription("entitlement-one")
    assert paddle.fetched == ["sub_01"]
    assert refreshed.current_period_end == renewed_end + RENEWAL_DELIVERY_BUFFER
    # The next check never lands past the deadline it is guarding.
    assert refreshed.next_reconciliation_at <= refreshed.current_period_end


async def test_portal_url_uses_the_sealed_customer(service, repository, paddle, deliver):
    await deliver(subscription_payload())
    stored = await repository.get_current_subscription("entitlement-one")

    url = await service.portal_url(stored)

    assert url == "https://customer-portal.paddle.com/cpl_01"
    assert paddle.portal_calls == [("ctm_01", "sub_01")]


async def test_a_known_subscription_never_binds_another_entitlements_session(
    service, repository, deliver
):
    await repository.create_entitlement(
        entitlement_id="entitlement-two",
        obfuscated_account_id="obfuscated-two",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    await repository.create_checkout_session(
        CheckoutSession(
            session_id="foreign-session",
            entitlement_id="entitlement-two",
            claim_secret_hash="claim-hash",
            price_id=MONTHLY_PRICE,
            expires_at=NOW + timedelta(minutes=30),
            bound_token_fingerprint=None,
            bound_at=None,
            created_at=NOW,
        )
    )
    await deliver(subscription_payload())

    await deliver(
        subscription_payload(session_id="foreign-session"),
        event_id="evt_02",
        event_type="subscription.updated",
    )

    foreign = await repository.get_checkout_session("foreign-session")
    assert foreign.bound_token_fingerprint is None
    assert await repository.get_current_subscription("entitlement-two") is None
