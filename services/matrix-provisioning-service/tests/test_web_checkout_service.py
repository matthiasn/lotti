"""End-to-end tests of web checkout: session → webhook → claim → portal."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta
from urllib.parse import parse_qs, urlsplit

import pytest
from src.core.exceptions import (
    BundleClaimConflictException,
    CheckoutSessionException,
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PaymentPendingException,
    WebCheckoutRateLimitException,
)
from src.core.subscriptions import EntitlementState
from src.services.paddle_subscription_service import PaddleSubscriptionService
from src.services.paid_bundle_service import PaidBundleService
from src.services.secret_cipher import SecretCipher
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.web_checkout_service import CheckoutSessionState, WebCheckoutService
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

from shared.matrix import BundleKind, ProvisionResult, SyncBundle

pytestmark = pytest.mark.anyio

CHECKOUT_PAGE = "https://sync.example.com/checkout/"
CLAIM_SECRET = "c" * 43
ENCODED_BUNDLE = SyncBundle(
    home_server="https://matrix.example.com",
    user="@sync_web:example.com",
    password="bootstrap-password",
    room_id="!paid:example.com",
    kind=BundleKind.PROVISIONED,
).encode()


class FakeBundleService:
    def __init__(self):
        self.requests = []

    async def create_bundle_with_persistence(self, request, persist):
        self.requests.append(request)
        result = ProvisionResult(
            bundle=SyncBundle.decode(ENCODED_BUNDLE),
            user_mxid="@sync_web:example.com",
            room_id="!paid:example.com",
            server_name="example.com",
        )
        return await persist(result, ENCODED_BUNDLE)


class FakeAccessService:
    def __init__(self):
        self.suspend = False

    async def enforce(self, subscription, *, now):
        return self.suspend if subscription.bundle_id is not None else None


class FakePaddleClient:
    async def create_portal_url(self, customer_id, subscription_id):
        return f"https://customer-portal.paddle.com/{customer_id}/{subscription_id}"


class Clock:
    def __init__(self, now: datetime):
        self.now = now

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def clock():
    return Clock(NOW)


@pytest.fixture
def world(tmp_path, clock):
    repository = WebSubscriptionRepository(str(tmp_path / "web.db"))
    cipher = SecretCipher(key_id="key-v1", key=bytes(range(32)))
    identity = SubscriptionIdentityService(
        repository,
        account_binding_key=bytes(range(32)),
        allowed_products={"lotti_sync": frozenset({"monthly"})},
    )
    access = FakeAccessService()
    bundles = FakeBundleService()
    paddle = PaddleSubscriptionService(
        repository,
        access,
        cipher,
        FakePaddleClient(),
        webhook_secret=WEBHOOK_SECRET,
        allowed_price_ids=frozenset({MONTHLY_PRICE, ANNUAL_PRICE}),
        now_provider=clock,
    )
    paid = PaidBundleService(bundles, repository, None, cipher, now_provider=clock)
    checkout = WebCheckoutService(
        repository,
        identity,
        paid,
        access,
        paddle,
        checkout_page_url=CHECKOUT_PAGE,
        plans={"monthly": MONTHLY_PRICE, "annual": ANNUAL_PRICE},
        attempt_limit=3,
        now_provider=clock,
    )
    return {
        "repository": repository,
        "identity": identity,
        "access": access,
        "bundles": bundles,
        "paddle": paddle,
        "checkout": checkout,
    }


@pytest.fixture
async def credentials(world):
    return await world["identity"].create_entitlement(client_identifier="device", now=NOW)


async def open_session(world, credentials, *, plan="monthly"):
    return await world["checkout"].create_session(
        entitlement_id=credentials.entitlement_id,
        auth_secret=credentials.auth_secret,
        plan=plan,
        claim_secret=CLAIM_SECRET,
    )


async def pay(world, clock, session_id, **subscription):
    body, header = signed(
        event_payload(subscription_payload(session_id=session_id, **subscription)),
        at=clock.now,
    )
    return await world["paddle"].handle_webhook(body, header)


async def claim(world, credentials, *, claim_secret=CLAIM_SECRET):
    return await world["checkout"].claim(
        entitlement_id=credentials.entitlement_id,
        auth_secret=credentials.auth_secret,
        claim_secret=claim_secret,
    )


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"checkout_page_url": "http://sync.example.com/"}, "https"),
        ({"plans": {}}, "plan"),
    ],
)
async def test_service_validates_its_configuration(world, overrides, message):
    values = {
        "checkout_page_url": CHECKOUT_PAGE,
        "plans": {"monthly": MONTHLY_PRICE},
    }
    values.update(overrides)
    with pytest.raises(ValueError, match=message):
        WebCheckoutService(
            world["repository"],
            world["identity"],
            None,
            world["access"],
            world["paddle"],
            **values,
        )


async def test_session_url_keeps_the_session_id_out_of_server_logs(world, credentials):
    created = await open_session(world, credentials)

    url = urlsplit(created.checkout_url)
    assert f"{url.scheme}://{url.netloc}{url.path}" == CHECKOUT_PAGE
    assert url.query == ""
    assert parse_qs(url.fragment) == {"session": [created.session_id], "price": [MONTHLY_PRICE]}
    assert created.expires_at == NOW + timedelta(minutes=30)
    stored = await world["repository"].get_checkout_session(created.session_id)
    assert CLAIM_SECRET not in stored.claim_secret_hash


async def test_session_maps_plans_to_server_side_prices(world, credentials):
    annual = await open_session(world, credentials, plan="annual")

    assert parse_qs(urlsplit(annual.checkout_url).fragment)["price"] == [ANNUAL_PRICE]
    with pytest.raises(InvalidSubscriptionProductException):
        await open_session(world, credentials, plan="lifetime")


async def test_session_rejects_a_short_claim_secret(world, credentials):
    with pytest.raises(BundleClaimConflictException, match="too short"):
        await world["checkout"].create_session(
            entitlement_id=credentials.entitlement_id,
            auth_secret=credentials.auth_secret,
            plan="monthly",
            claim_secret="short",
        )


async def test_session_rejects_wrong_and_unknown_credentials(world, credentials):
    with pytest.raises(EntitlementAuthenticationException):
        await world["checkout"].create_session(
            entitlement_id=credentials.entitlement_id,
            auth_secret="wrong",
            plan="monthly",
            claim_secret=CLAIM_SECRET,
        )
    with pytest.raises(EntitlementAuthenticationException):
        await world["checkout"].create_session(
            entitlement_id="no-such-entitlement",
            auth_secret=credentials.auth_secret,
            plan="monthly",
            claim_secret=CLAIM_SECRET,
        )


async def test_session_attempts_are_rate_limited_before_hashing(world, credentials):
    for _ in range(3):
        await open_session(world, credentials)

    with pytest.raises(WebCheckoutRateLimitException) as raised:
        await open_session(world, credentials)

    assert raised.value.retry_after_seconds > 0


async def test_status_moves_from_pending_to_paid_when_the_webhook_lands(world, credentials, clock):
    created = await open_session(world, credentials)
    checkout = world["checkout"]

    assert await checkout.session_state(created.session_id) is CheckoutSessionState.PENDING
    await pay(world, clock, created.session_id)
    assert await checkout.session_state(created.session_id) is CheckoutSessionState.PAID


async def test_status_reports_expiry_only_for_unpaid_sessions(world, credentials, clock):
    unpaid = await open_session(world, credentials)
    paid = await open_session(world, credentials)
    await pay(world, clock, paid.session_id)
    clock.now = NOW + timedelta(hours=1)

    checkout = world["checkout"]
    assert await checkout.session_state(unpaid.session_id) is CheckoutSessionState.EXPIRED
    assert await checkout.session_state(paid.session_id) is CheckoutSessionState.PAID


async def test_status_is_pending_again_once_the_subscription_lapses(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)
    clock.now = NOW + timedelta(days=40)

    assert await world["checkout"].session_state(created.session_id) is (
        CheckoutSessionState.PENDING
    )


async def test_status_of_an_unknown_session_is_an_error(world):
    with pytest.raises(CheckoutSessionException):
        await world["checkout"].session_state("missing-session-id")


async def test_claim_before_payment_is_pending(world, credentials):
    await open_session(world, credentials)

    with pytest.raises(PaymentPendingException):
        await claim(world, credentials)


async def test_claim_after_payment_provisions_once_and_redelivers(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)

    first = await claim(world, credentials)
    second = await claim(world, credentials)

    assert first.delivery.bundle == ENCODED_BUNDLE
    assert first.delivery.rotation_challenge is not None
    assert first.subscription.entitlement_state is EntitlementState.ACTIVE
    assert second.delivery.bundle_id == first.delivery.bundle_id
    assert len(world["bundles"].requests) == 1
    assert world["bundles"].requests[0].notes == "Paddle web subscription"


async def test_claim_requires_the_secret_the_session_was_opened_with(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)

    with pytest.raises(BundleClaimConflictException, match="claim secret"):
        await claim(world, credentials, claim_secret="x" * 43)
    assert world["bundles"].requests == []


async def test_claim_is_refused_while_the_account_is_suspended(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)
    await claim(world, credentials)
    world["access"].suspend = True

    with pytest.raises(GooglePlayVerificationException):
        await claim(world, credentials)


async def test_claim_after_lapse_is_pending(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)
    clock.now = NOW + timedelta(days=40)

    with pytest.raises(PaymentPendingException):
        await claim(world, credentials)


async def test_portal_link_is_scoped_to_the_entitlements_subscription(world, credentials, clock):
    created = await open_session(world, credentials)
    await pay(world, clock, created.session_id)

    url = await world["checkout"].portal_url(
        entitlement_id=credentials.entitlement_id,
        auth_secret=credentials.auth_secret,
    )

    assert url == "https://customer-portal.paddle.com/ctm_01/sub_01"


async def test_portal_without_a_web_subscription_is_pending(world, credentials):
    with pytest.raises(PaymentPendingException):
        await world["checkout"].portal_url(
            entitlement_id=credentials.entitlement_id,
            auth_secret=credentials.auth_secret,
        )


async def test_a_crash_before_binding_stays_pending_until_paddle_redelivers(
    world, credentials, clock, monkeypatch
):
    created = await open_session(world, credentials)
    repository = world["repository"]
    bind = repository.bind_checkout_session

    async def crash(*args, **kwargs):
        raise RuntimeError("process killed between the two writes")

    monkeypatch.setattr(repository, "bind_checkout_session", crash)
    with pytest.raises(RuntimeError):
        await pay(world, clock, created.session_id)

    # The subscription row exists, but nothing ties it to a claim secret yet.
    with pytest.raises(PaymentPendingException, match="No checkout"):
        await claim(world, credentials)

    monkeypatch.setattr(repository, "bind_checkout_session", bind)
    assert await pay(world, clock, created.session_id) == "applied"
    assert (await claim(world, credentials)).delivery.bundle == ENCODED_BUNDLE
