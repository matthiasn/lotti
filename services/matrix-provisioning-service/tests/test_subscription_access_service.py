"""Tests for reversible Matrix enforcement at entitlement boundaries."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

from dataclasses import replace
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from src.core.exceptions import BundleClaimConflictException
from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    VerifiedSubscription,
)
from src.services.subscription_access_service import SubscriptionAccessService
from src.services.subscription_repository import SubscriptionRepository

pytestmark = pytest.mark.anyio

NOW = datetime(2026, 8, 29, 12, tzinfo=timezone.utc)


class FakeAdminClient:
    def __init__(self, *, suspended=False):
        self.suspended = suspended
        self.changes = []
        self.failure = None
        self.activity_calls = 0

    async def get_user_activity(self, _user_mxid):
        self.activity_calls += 1
        if self.failure:
            raise self.failure
        return SimpleNamespace(suspended=self.suspended)

    async def set_user_suspended(self, user_mxid, *, suspended):
        if self.failure:
            raise self.failure
        self.changes.append((user_mxid, suspended))
        self.suspended = suspended


async def setup_subscription(repository, *, state, period_end=None, with_bundle=True):
    await repository.create_entitlement(
        entitlement_id="entitlement-one",
        obfuscated_account_id="obfuscated-one",
        auth_secret_hash="auth-hash",
        now=NOW,
    )
    stored = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id="entitlement-one",
            token_fingerprint="purchase-token",
            encrypted_purchase_token=b"encrypted-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="monthly",
            latest_order_id="GPA.1234",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=state,
            start_time=NOW,
            current_period_end=period_end,
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
        ),
        now=NOW,
    )
    if not with_bundle:
        return stored
    provisioning_token = "access-service-test"  # noqa: S105 - fixture lease token
    assert await repository.reserve_paid_bundle_provisioning(
        stored.entitlement_id,
        token_fingerprint=stored.token_fingerprint,
        operation_token=provisioning_token,
        now=NOW,
        stale_before=NOW - timedelta(minutes=5),
    )
    await repository.store_paid_bundle(
        token_fingerprint=stored.token_fingerprint,
        provisioning_token=provisioning_token,
        bundle_id="bundle-one",
        username="sync_one",
        user_mxid="@sync_one:example.com",
        home_server="https://matrix.example.com",
        server_name="example.com",
        room_id="!sync:example.com",
        display_name="Lotti SYNC",
        bundle_fingerprint="b" * 64,
        notes="Verified Google Play subscription",
        claim_secret_hash="claim-hash",
        encrypted_bundle=b"encrypted-bundle",
        encryption_key_id="test-key",
        expires_at=NOW + timedelta(hours=24),
        now=NOW,
    )
    return await repository.get_subscription_by_token(stored.token_fingerprint)


@pytest.fixture
def repository(tmp_path):
    return SubscriptionRepository(str(tmp_path / "subscriptions.db"))


def access_service(repository, admin, *, now_provider=lambda: NOW):
    return SubscriptionAccessService(
        repository,
        admin,
        now_provider=now_provider,
    )


@pytest.mark.parametrize(
    "state",
    [EntitlementState.SUSPENDED, EntitlementState.EXPIRED, EntitlementState.PENDING],
)
async def test_non_grantable_state_suspends_matrix_account(repository, state):
    subscription = await setup_subscription(repository, state=state)
    admin = FakeAdminClient(suspended=False)
    service = access_service(repository, admin)

    desired = await service.enforce(subscription, now=NOW)

    assert desired is True
    assert admin.changes == [("@sync_one:example.com", True)]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.suspended_at == NOW
    assert stored.last_error is None


@pytest.mark.parametrize(
    "state",
    [EntitlementState.ACTIVE, EntitlementState.GRACE, EntitlementState.CANCELED_ACTIVE],
)
async def test_grantable_state_restores_suspended_matrix_account(repository, state):
    subscription = await setup_subscription(
        repository,
        state=state,
        period_end=NOW + timedelta(seconds=1),
    )
    admin = FakeAdminClient(suspended=True)
    service = access_service(repository, admin)

    desired = await service.enforce(subscription, now=NOW)

    assert desired is False
    assert admin.changes == [("@sync_one:example.com", False)]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.unsuspended_at == NOW


async def test_access_is_suspended_exactly_at_authoritative_deadline(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.GRACE,
        period_end=NOW,
    )
    admin = FakeAdminClient()
    service = access_service(repository, admin)

    assert await service.enforce(subscription, now=NOW) is True
    assert admin.changes == [("@sync_one:example.com", True)]


async def test_activity_lookup_refreshes_clock_before_expiry_enforcement(repository):
    deadline = NOW + timedelta(seconds=1)
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.ACTIVE,
        period_end=deadline,
    )
    current_time = NOW

    class ExpiringAdminClient(FakeAdminClient):
        async def get_user_activity(self, user_mxid):
            nonlocal current_time
            activity = await super().get_user_activity(user_mxid)
            current_time = deadline
            return activity

    admin = ExpiringAdminClient(suspended=False)
    service = access_service(
        repository,
        admin,
        now_provider=lambda: current_time,
    )

    assert await service.enforce(subscription, now=NOW) is True
    assert admin.changes == [("@sync_one:example.com", True)]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.suspended_at == deadline


async def test_unsuspension_crossing_expiry_is_immediately_reconverged(repository):
    deadline = NOW + timedelta(seconds=1)
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.GRACE,
        period_end=deadline,
    )
    current_time = NOW

    class ExpiringAdminClient(FakeAdminClient):
        async def set_user_suspended(self, user_mxid, *, suspended):
            nonlocal current_time
            await super().set_user_suspended(user_mxid, suspended=suspended)
            if suspended is False:
                current_time = deadline

    admin = ExpiringAdminClient(suspended=True)
    service = access_service(
        repository,
        admin,
        now_provider=lambda: current_time,
    )

    assert await service.enforce(subscription, now=NOW) is True
    assert admin.changes == [
        ("@sync_one:example.com", False),
        ("@sync_one:example.com", True),
    ]
    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.suspended_at == deadline


async def test_unprovisioned_subscription_has_no_matrix_side_effect(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.ACTIVE,
        with_bundle=False,
    )
    admin = FakeAdminClient()
    service = access_service(repository, admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.changes == []


async def test_retired_entitlement_without_current_subscription_has_no_side_effect():
    subscription = SimpleNamespace(entitlement_id="retired-entitlement")

    class Repository:
        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            return None

    admin = FakeAdminClient()
    service = access_service(Repository(), admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.activity_calls == 0


async def test_synapse_failure_is_recorded_and_propagated(repository):
    subscription = await setup_subscription(
        repository,
        state=EntitlementState.SUSPENDED,
    )
    admin = FakeAdminClient()
    admin.failure = RuntimeError("synapse unavailable")
    service = access_service(repository, admin)

    with pytest.raises(RuntimeError, match="synapse unavailable"):
        await service.enforce(subscription, now=NOW)

    stored = await repository.get_subscription_by_token("purchase-token")
    assert stored.last_error == "synapse unavailable"
    assert stored.next_reconciliation_at == NOW + timedelta(minutes=5)


async def test_subscription_with_dangling_bundle_reference_fails_closed():
    class Repository:
        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == "entitlement-one"
            return subscription

        async def get(self, bundle_id):
            assert bundle_id == "missing-bundle"
            return None

    service = access_service(Repository(), FakeAdminClient())
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        bundle_id="missing-bundle",
    )

    with pytest.raises(BundleClaimConflictException, match="missing Matrix bundle"):
        await service.enforce(subscription, now=NOW)


async def test_stale_predecessor_enforces_current_replacement(repository):
    predecessor = await setup_subscription(
        repository,
        state=EntitlementState.EXPIRED,
    )
    await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id="entitlement-one",
            token_fingerprint="replacement-token",
            encrypted_purchase_token=b"replacement-token",
            encryption_key_id="test-key",
            package_name="com.matthiasn.lotti",
            product_id="lotti_sync",
            base_plan_id="annual",
            latest_order_id="GPA.5678",
            google_state=GoogleSubscriptionState.ACTIVE,
            entitlement_state=EntitlementState.ACTIVE,
            start_time=NOW,
            current_period_end=NOW + timedelta(days=365),
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW,
            next_reconciliation_at=NOW + timedelta(hours=6),
            linked_token_fingerprint=predecessor.token_fingerprint,
        ),
        now=NOW,
    )
    admin = FakeAdminClient(suspended=True)
    service = access_service(repository, admin)

    assert await service.enforce(predecessor, now=NOW) is False
    assert admin.changes == [("@sync_one:example.com", False)]
    assert admin.suspended is False


async def test_state_is_reloaded_after_activity_lookup_before_matrix_mutation(repository):
    active = await setup_subscription(
        repository,
        state=EntitlementState.ACTIVE,
        period_end=NOW + timedelta(days=30),
    )
    await repository.record_subscription_enforcement(
        active.token_fingerprint,
        suspended=True,
        now=NOW,
    )

    class RacingAdminClient(FakeAdminClient):
        async def get_user_activity(self, user_mxid):
            activity = await super().get_user_activity(user_mxid)
            await repository.store_verified_subscription(
                replace(
                    active,
                    google_state=GoogleSubscriptionState.ON_HOLD,
                    entitlement_state=EntitlementState.SUSPENDED,
                    last_verified_at=NOW + timedelta(seconds=1),
                    next_reconciliation_at=NOW + timedelta(hours=6),
                ),
                now=NOW + timedelta(seconds=1),
            )
            return activity

    admin = RacingAdminClient(suspended=True)
    service = access_service(repository, admin)

    assert await service.enforce(active, now=NOW + timedelta(seconds=1)) is True
    assert admin.changes == []
    current = await repository.get_current_subscription(active.entitlement_id)
    assert current.entitlement_state is EntitlementState.SUSPENDED


async def test_bundle_detached_during_activity_lookup_stops_enforcement():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
    )
    detached = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint=subscription.token_fingerprint,
        bundle_id=None,
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads == 1 else detached

        async def get(self, bundle_id):
            assert bundle_id == "old-bundle"
            return SimpleNamespace(user_mxid="@old:example.com")

        async def record_subscription_enforcement(self, *_args, **_kwargs):
            pytest.fail("Detached accounts must not record enforcement")

        async def record_subscription_error(self, *_args, **_kwargs):
            pytest.fail("A concurrent detach is not an enforcement error")

    admin = FakeAdminClient(suspended=False)
    service = access_service(RacingRepository(), admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.activity_calls == 1
    assert admin.changes == []


async def test_bundle_detached_after_matrix_mutation_stops_enforcement():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
        entitlement_state=EntitlementState.SUSPENDED,
        current_period_end=None,
    )
    detached = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint=subscription.token_fingerprint,
        bundle_id=None,
        entitlement_state=subscription.entitlement_state,
        current_period_end=subscription.current_period_end,
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads <= 2 else detached

        async def get(self, bundle_id):
            assert bundle_id == "old-bundle"
            return SimpleNamespace(user_mxid="@old:example.com")

        async def record_subscription_enforcement(self, *_args, **_kwargs):
            pytest.fail("Detached accounts must not record enforcement")

        async def record_subscription_error(self, *_args, **_kwargs):
            pytest.fail("A concurrent detach is not an enforcement error")

    admin = FakeAdminClient(suspended=False)
    service = access_service(RacingRepository(), admin)

    assert await service.enforce(subscription, now=NOW) is None
    assert admin.changes == [("@old:example.com", True)]


async def test_missing_replacement_after_matrix_mutation_is_recorded():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
        entitlement_state=EntitlementState.SUSPENDED,
        current_period_end=None,
    )
    replacement = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint="new-token",
        bundle_id="missing-bundle",
        entitlement_state=subscription.entitlement_state,
        current_period_end=subscription.current_period_end,
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0
            self.errors = []

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads <= 2 else replacement

        async def get(self, bundle_id):
            if bundle_id == "old-bundle":
                return SimpleNamespace(user_mxid="@old:example.com")
            assert bundle_id == "missing-bundle"
            return None

        async def record_subscription_error(
            self,
            token_fingerprint,
            *,
            last_error,
            now,
            next_reconciliation_at,
        ):
            self.errors.append((token_fingerprint, last_error, now, next_reconciliation_at))

    repository = RacingRepository()
    admin = FakeAdminClient(suspended=False)
    service = access_service(repository, admin)

    with pytest.raises(BundleClaimConflictException, match="missing Matrix bundle"):
        await service.enforce(subscription, now=NOW)

    assert admin.changes == [("@old:example.com", True)]
    assert repository.errors == [
        (
            "new-token",
            "Subscription references a missing Matrix bundle",
            NOW,
            NOW + timedelta(minutes=5),
        )
    ]


async def test_replacement_bundle_is_rechecked_and_mutated_instead_of_stale_user():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
        entitlement_state=EntitlementState.ACTIVE,
        current_period_end=NOW + timedelta(days=1),
    )
    replacement = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint="new-token",
        bundle_id="new-bundle",
        entitlement_state=subscription.entitlement_state,
        current_period_end=subscription.current_period_end,
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0
            self.enforcements = []

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads == 1 else replacement

        async def get(self, bundle_id):
            return SimpleNamespace(user_mxid=f"@{bundle_id}:example.com")

        async def record_subscription_enforcement(
            self,
            token_fingerprint,
            *,
            suspended,
            now,
        ):
            self.enforcements.append((token_fingerprint, suspended, now))

        async def record_subscription_error(self, *_args, **_kwargs):
            pytest.fail("Successful replacement enforcement must not record an error")

    class TrackingAdminClient(FakeAdminClient):
        def __init__(self):
            super().__init__(suspended=True)
            self.activity_users = []

        async def get_user_activity(self, user_mxid):
            self.activity_users.append(user_mxid)
            return await super().get_user_activity(user_mxid)

    repository = RacingRepository()
    admin = TrackingAdminClient()
    service = access_service(repository, admin)

    assert await service.enforce(subscription, now=NOW) is False
    assert admin.activity_users == ["@old-bundle:example.com", "@new-bundle:example.com"]
    assert admin.changes == [("@new-bundle:example.com", False)]
    assert repository.enforcements == [("new-token", False, NOW)]


async def test_replacement_bundle_after_matrix_mutation_is_also_converged():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
        entitlement_state=EntitlementState.SUSPENDED,
        current_period_end=None,
    )
    replacement = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint="new-token",
        bundle_id="new-bundle",
        entitlement_state=subscription.entitlement_state,
        current_period_end=subscription.current_period_end,
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0
            self.enforcements = []

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads <= 2 else replacement

        async def get(self, bundle_id):
            return SimpleNamespace(user_mxid=f"@{bundle_id}:example.com")

        async def record_subscription_enforcement(
            self,
            token_fingerprint,
            *,
            suspended,
            now,
        ):
            self.enforcements.append((token_fingerprint, suspended, now))

        async def record_subscription_error(self, *_args, **_kwargs):
            pytest.fail("Successful replacement enforcement must not record an error")

    class PerUserAdminClient(FakeAdminClient):
        def __init__(self):
            super().__init__()
            self.suspension_by_user = {
                "@old-bundle:example.com": False,
                "@new-bundle:example.com": False,
            }

        async def get_user_activity(self, user_mxid):
            self.activity_calls += 1
            return SimpleNamespace(suspended=self.suspension_by_user[user_mxid])

        async def set_user_suspended(self, user_mxid, *, suspended):
            self.changes.append((user_mxid, suspended))
            self.suspension_by_user[user_mxid] = suspended

    repository = RacingRepository()
    admin = PerUserAdminClient()
    service = access_service(repository, admin)

    assert await service.enforce(subscription, now=NOW) is True
    assert admin.changes == [
        ("@old-bundle:example.com", True),
        ("@new-bundle:example.com", True),
    ]
    assert repository.enforcements == [("new-token", True, NOW)]


async def test_repeated_state_churn_is_bounded_and_retried():
    active = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="purchase-token",
        bundle_id="bundle-one",
        entitlement_state=EntitlementState.ACTIVE,
        current_period_end=NOW + timedelta(days=1),
    )
    suspended = SimpleNamespace(
        entitlement_id=active.entitlement_id,
        token_fingerprint=active.token_fingerprint,
        bundle_id=active.bundle_id,
        entitlement_state=EntitlementState.SUSPENDED,
        current_period_end=active.current_period_end,
    )

    class ChurningRepository:
        def __init__(self):
            self.current_reads = 0
            self.errors = []

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == active.entitlement_id
            snapshots = [active, active, suspended, active, suspended]
            snapshot = snapshots[min(self.current_reads, len(snapshots) - 1)]
            self.current_reads += 1
            return snapshot

        async def get(self, bundle_id):
            assert bundle_id == active.bundle_id
            return SimpleNamespace(user_mxid="@sync:example.com")

        async def record_subscription_enforcement(self, *_args, **_kwargs):
            pytest.fail("Unstable state must not be recorded as converged")

        async def record_subscription_error(
            self,
            token_fingerprint,
            *,
            last_error,
            now,
            next_reconciliation_at,
        ):
            self.errors.append((token_fingerprint, last_error, now, next_reconciliation_at))

    repository = ChurningRepository()
    admin = FakeAdminClient(suspended=True)
    service = access_service(repository, admin)

    with pytest.raises(BundleClaimConflictException, match="changed repeatedly"):
        await service.enforce(active, now=NOW)

    assert admin.changes == [
        ("@sync:example.com", False),
        ("@sync:example.com", True),
        ("@sync:example.com", False),
    ]
    assert repository.errors == [
        (
            "purchase-token",
            "Subscription changed repeatedly during Matrix enforcement",
            NOW,
            NOW + timedelta(minutes=5),
        )
    ]


async def test_missing_replacement_bundle_is_recorded_as_enforcement_error():
    subscription = SimpleNamespace(
        entitlement_id="entitlement-one",
        token_fingerprint="old-token",
        bundle_id="old-bundle",
    )
    replacement = SimpleNamespace(
        entitlement_id=subscription.entitlement_id,
        token_fingerprint="new-token",
        bundle_id="missing-bundle",
    )

    class RacingRepository:
        def __init__(self):
            self.current_reads = 0
            self.errors = []

        async def get_current_subscription(self, entitlement_id):
            assert entitlement_id == subscription.entitlement_id
            self.current_reads += 1
            return subscription if self.current_reads == 1 else replacement

        async def get(self, bundle_id):
            if bundle_id == "old-bundle":
                return SimpleNamespace(user_mxid="@old:example.com")
            assert bundle_id == "missing-bundle"
            return None

        async def record_subscription_error(
            self,
            token_fingerprint,
            *,
            last_error,
            now,
            next_reconciliation_at,
        ):
            self.errors.append((token_fingerprint, last_error, now, next_reconciliation_at))

    repository = RacingRepository()
    service = access_service(repository, FakeAdminClient())

    with pytest.raises(BundleClaimConflictException, match="missing Matrix bundle"):
        await service.enforce(subscription, now=NOW)

    assert repository.errors == [
        (
            "new-token",
            "Subscription references a missing Matrix bundle",
            NOW,
            NOW + timedelta(minutes=5),
        )
    ]
