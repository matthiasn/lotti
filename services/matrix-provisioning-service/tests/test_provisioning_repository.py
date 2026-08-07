"""Tests for the SQLite persistence layer.

These focus on the bundle state machine, because that is what the whole
provisioning-tracking feature rests on.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from src.core.exceptions import (
    BundleNotFoundException,
    InvalidBundleStateException,
    UsernameAlreadyProvisionedException,
)
from src.core.models import BundleEventType, BundleStatus, PaymentStatus
from tests.conftest import seed_user

pytestmark = pytest.mark.anyio


async def test_create_starts_unused_with_no_login_timestamps(repository):
    user = await seed_user(repository)

    assert user.status is BundleStatus.UNUSED
    assert user.payment_status is PaymentStatus.UNKNOWN
    assert user.first_login_at is None
    assert user.rotated_at is None
    assert user.active_days is None


async def test_create_records_an_audit_event(repository):
    user = await seed_user(repository)

    events = await repository.get_events(user.bundle_id)

    assert [e.event_type for e in events] == [BundleEventType.CREATED]
    assert user.user_mxid in events[0].detail


async def test_duplicate_username_on_same_server_is_rejected(repository):
    await seed_user(repository, username="taken")

    with pytest.raises(UsernameAlreadyProvisionedException):
        await seed_user(repository, username="taken")


async def test_same_username_on_a_different_server_is_allowed(repository):
    """The uniqueness constraint is per homeserver, not global."""
    await seed_user(repository, username="shared")

    other = await seed_user(
        repository,
        username="shared",
        server_name="other.example.com",
        user_mxid="@shared:other.example.com",
    )

    assert other.server_name == "other.example.com"


async def test_mark_redeemed_advances_status_and_stamps_first_login(repository):
    user = await seed_user(repository)
    seen = datetime(2026, 3, 1, tzinfo=timezone.utc)

    updated = await repository.mark_redeemed(user.bundle_id, seen)

    assert updated.status is BundleStatus.REDEEMED
    assert updated.first_login_at == seen
    assert updated.last_seen_at == seen


async def test_mark_redeemed_is_idempotent_and_keeps_original_first_login(repository):
    """Re-observing activity must not keep resetting the first-login stamp."""
    user = await seed_user(repository)
    first = datetime(2026, 3, 1, tzinfo=timezone.utc)
    later = datetime(2026, 4, 1, tzinfo=timezone.utc)

    await repository.mark_redeemed(user.bundle_id, first)
    updated = await repository.mark_redeemed(user.bundle_id, later)

    assert updated.first_login_at == first
    assert updated.last_seen_at == later
    events = await repository.get_events(user.bundle_id)
    assert sum(e.event_type is BundleEventType.REDEEMED for e in events) == 1


async def test_redeeming_a_rotated_bundle_does_not_walk_status_backwards(repository):
    """The poller sees activity on rotated accounts; that must not undo rotation."""
    user = await seed_user(repository)
    await repository.mark_rotated(user.bundle_id)

    updated = await repository.mark_redeemed(
        user.bundle_id, datetime(2026, 5, 1, tzinfo=timezone.utc)
    )

    assert updated.status is BundleStatus.ROTATED


async def test_mark_rotated_implies_redemption(repository):
    """A rotation callback can beat the poller, and still proves first login."""
    user = await seed_user(repository)

    updated = await repository.mark_rotated(user.bundle_id)

    assert updated.status is BundleStatus.ROTATED
    assert updated.rotated_at is not None
    assert updated.first_login_at is not None


async def test_mark_rotated_is_idempotent(repository):
    """The client retries the callback after a dropped response."""
    user = await seed_user(repository)
    first = await repository.mark_rotated(user.bundle_id)

    second = await repository.mark_rotated(user.bundle_id)

    assert second.rotated_at == first.rotated_at
    events = await repository.get_events(user.bundle_id)
    assert sum(e.event_type is BundleEventType.ROTATED for e in events) == 1


async def test_revoked_bundles_reject_further_transitions(repository):
    user = await seed_user(repository)
    await repository.revoke(user.bundle_id, "leaked")

    with pytest.raises(InvalidBundleStateException):
        await repository.mark_redeemed(user.bundle_id)
    with pytest.raises(InvalidBundleStateException):
        await repository.mark_rotated(user.bundle_id)


async def test_revoke_records_reason_in_the_audit_trail(repository):
    user = await seed_user(repository)

    updated = await repository.revoke(user.bundle_id, "posted in public chat")

    assert updated.status is BundleStatus.REVOKED
    assert updated.revoked_at is not None
    events = await repository.get_events(user.bundle_id)
    assert events[-1].detail == "posted in public chat"


async def test_unknown_bundle_raises_not_found(repository):
    for call in (
        repository.mark_redeemed,
        repository.mark_rotated,
        repository.revoke,
    ):
        with pytest.raises(BundleNotFoundException):
            await call("no-such-bundle")


async def test_update_records_payment_transition_detail(repository):
    user = await seed_user(repository)

    updated = await repository.update(
        user.bundle_id, payment_status=PaymentStatus.PAYING
    )

    assert updated.payment_status is PaymentStatus.PAYING
    events = await repository.get_events(user.bundle_id)
    assert events[-1].event_type is BundleEventType.PAYMENT_STATUS_CHANGED
    assert events[-1].detail == "unknown → paying"


async def test_update_to_the_same_value_records_no_event(repository):
    """Re-saving an unchanged form must not spam the audit trail."""
    user = await seed_user(repository)
    await repository.update(user.bundle_id, payment_status=PaymentStatus.PAYING)
    before = len(await repository.get_events(user.bundle_id))

    await repository.update(user.bundle_id, payment_status=PaymentStatus.PAYING)

    assert len(await repository.get_events(user.bundle_id)) == before


async def test_update_notes_independently_of_payment_status(repository):
    user = await seed_user(repository)

    updated = await repository.update(user.bundle_id, notes="prefers email")

    assert updated.notes == "prefers email"
    assert updated.payment_status is PaymentStatus.UNKNOWN


async def test_list_pollable_excludes_terminal_bundles(repository):
    unused = await seed_user(repository, username="unused_user")
    redeemed = await seed_user(repository, username="redeemed_user")
    await repository.mark_redeemed(redeemed.bundle_id, datetime.now(timezone.utc))
    rotated = await seed_user(repository, username="rotated_user")
    await repository.mark_rotated(rotated.bundle_id)
    revoked = await seed_user(repository, username="revoked_user")
    await repository.revoke(revoked.bundle_id)

    pollable = {u.bundle_id for u in await repository.list_pollable(50)}

    assert pollable == {unused.bundle_id, redeemed.bundle_id}


async def test_list_pollable_prioritises_least_recently_polled(repository):
    first = await seed_user(repository, username="first_user")
    second = await seed_user(repository, username="second_user")
    await repository.touch_poll(first.bundle_id)

    pollable = await repository.list_pollable(50)

    assert pollable[0].bundle_id == second.bundle_id


async def test_touch_poll_with_failure_records_an_event(repository):
    user = await seed_user(repository)

    await repository.touch_poll(user.bundle_id, "connection refused")

    events = await repository.get_events(user.bundle_id)
    assert events[-1].event_type is BundleEventType.POLL_FAILED
    assert "connection refused" in events[-1].detail


async def test_list_users_filters_by_status_and_paginates(repository):
    for i in range(5):
        await seed_user(repository, username=f"user_{i}")
    all_users, _ = await repository.list_users(page=1, page_size=100)
    await repository.mark_rotated(all_users[0].bundle_id)

    rotated, total = await repository.list_users(status=BundleStatus.ROTATED)
    page_one, overall = await repository.list_users(page=1, page_size=2)

    assert total == 1 and len(rotated) == 1
    assert overall == 5 and len(page_one) == 2


async def test_find_by_username_returns_none_when_absent(repository):
    assert await repository.find_by_username("nobody") is None


async def test_stats_counts_each_status_and_payment_bucket(repository):
    a = await seed_user(repository, username="a_user")
    b = await seed_user(repository, username="b_user")
    await seed_user(repository, username="c_user")
    await repository.mark_rotated(a.bundle_id)
    await repository.revoke(b.bundle_id)
    await repository.update(a.bundle_id, payment_status=PaymentStatus.PAYING)

    stats = await repository.get_stats()

    assert stats.total_provisioned == 3
    assert stats.rotated == 1
    assert stats.revoked == 1
    assert stats.unused == 1
    assert stats.paying == 1
    assert stats.unknown_payment == 2


async def test_stats_group_signups_by_day(repository):
    await seed_user(repository, username="today_user")

    stats = await repository.get_stats()

    today = datetime.now(timezone.utc).date().isoformat()
    assert stats.signups_by_day[today] == 1


async def test_active_days_counts_from_first_login(repository):
    user = await seed_user(repository)
    ten_days_ago = datetime.now(timezone.utc) - timedelta(days=10)

    updated = await repository.mark_redeemed(user.bundle_id, ten_days_ago)

    assert updated.active_days == 10


async def test_purge_runs_are_recorded_and_completed(repository):
    user = await seed_user(repository)
    await repository.record_purge("purge_1", user.bundle_id, user.room_id, 1700000000000)

    await repository.update_purge_status("purge_1", "complete")
    purges = await repository.list_purges(user.bundle_id)

    assert purges[0]["status"] == "complete"
    assert purges[0]["completed_at"] is not None


async def test_active_purge_has_no_completion_timestamp(repository):
    user = await seed_user(repository)
    await repository.record_purge("purge_2", user.bundle_id, user.room_id, 1)

    await repository.update_purge_status("purge_2", "active")

    assert (await repository.list_purges())[0]["completed_at"] is None


@pytest.mark.parametrize(
    ("status", "terminal"),
    [
        (BundleStatus.UNUSED, False),
        (BundleStatus.REDEEMED, False),
        (BundleStatus.ROTATED, True),
        (BundleStatus.REVOKED, True),
    ],
)
async def test_is_terminal_matches_the_documented_state_machine(status, terminal):
    """The poller relies on this to decide what it may stop checking."""
    assert status.is_terminal is terminal


# -- retention overrides ----------------------------------------------------


async def test_retention_defaults_to_inheriting_the_service_window(repository):
    user = await seed_user(repository)

    assert user.retention_days is None
    assert user.retention_exempt is False


async def test_setting_a_retention_override_records_the_transition(repository):
    user = await seed_user(repository)

    updated = await repository.update(user.bundle_id, retention_days=365)

    assert updated.retention_days == 365
    events = await repository.get_events(user.bundle_id)
    assert events[-1].event_type is BundleEventType.RETENTION_CHANGED
    assert events[-1].detail == "default → 365d"


async def test_clearing_the_override_returns_the_user_to_the_default(repository):
    """`None` means 'unchanged', so clearing needs its own explicit flag."""
    user = await seed_user(repository)
    await repository.update(user.bundle_id, retention_days=365)

    updated = await repository.update(user.bundle_id, clear_retention_override=True)

    assert updated.retention_days is None
    events = await repository.get_events(user.bundle_id)
    assert "service default" in events[-1].detail


async def test_omitting_retention_days_leaves_an_existing_override_alone(repository):
    user = await seed_user(repository)
    await repository.update(user.bundle_id, retention_days=365)

    updated = await repository.update(user.bundle_id, notes="unrelated edit")

    assert updated.retention_days == 365


async def test_exempting_a_user_is_recorded(repository):
    user = await seed_user(repository)

    updated = await repository.update(user.bundle_id, retention_exempt=True)

    assert updated.retention_exempt is True
    events = await repository.get_events(user.bundle_id)
    assert events[-1].detail == "exempted from sweep"


async def test_list_purgeable_excludes_exempt_unredeemed_and_revoked(repository):
    eligible = await seed_user(repository, username="eligible_user")
    await repository.mark_redeemed(eligible.bundle_id, datetime.now(timezone.utc))

    exempt = await seed_user(repository, username="exempt_user")
    await repository.mark_redeemed(exempt.bundle_id, datetime.now(timezone.utc))
    await repository.update(exempt.bundle_id, retention_exempt=True)

    await seed_user(repository, username="unredeemed_user")

    revoked = await seed_user(repository, username="revoked_user")
    await repository.mark_redeemed(revoked.bundle_id, datetime.now(timezone.utc))
    await repository.revoke(revoked.bundle_id)

    purgeable = {u.bundle_id for u in await repository.list_purgeable()}

    assert purgeable == {eligible.bundle_id}


async def test_schema_migrates_a_database_created_before_retention_columns(tmp_path):
    """An existing deployment must not need a manual ALTER TABLE."""
    import sqlite3

    from src.services.provisioning_repository import ProvisioningRepository

    db_path = tmp_path / "legacy.db"
    legacy = sqlite3.connect(db_path)
    legacy.execute(
        """
        CREATE TABLE provisioned_users (
            bundle_id TEXT PRIMARY KEY, username TEXT NOT NULL,
            user_mxid TEXT NOT NULL, home_server TEXT NOT NULL,
            server_name TEXT NOT NULL, room_id TEXT NOT NULL, display_name TEXT,
            status TEXT NOT NULL, payment_status TEXT NOT NULL,
            bundle_fingerprint TEXT NOT NULL, created_at TEXT NOT NULL,
            first_login_at TEXT, rotated_at TEXT, revoked_at TEXT,
            last_seen_at TEXT, last_polled_at TEXT, notes TEXT NOT NULL DEFAULT ''
        )
        """
    )
    legacy.execute(
        "INSERT INTO provisioned_users VALUES "
        "('b1','old','@old:s','h','s','!r',NULL,'unused','unknown','f',"
        "'2026-01-01T00:00:00+00:00',NULL,NULL,NULL,NULL,NULL,'')"
    )
    legacy.commit()
    legacy.close()

    repository = ProvisioningRepository(str(db_path))
    user = await repository.get("b1")

    assert user is not None
    assert user.retention_days is None
    assert user.retention_exempt is False


# -- audit trail bounds -----------------------------------------------------


async def test_a_sustained_outage_records_one_failure_not_one_per_poll(repository):
    """The poller retries forever; a row per attempt would bury the real trail."""
    user = await seed_user(repository)

    for _ in range(50):
        await repository.touch_poll(user.bundle_id, "homeserver unreachable")

    failures = [
        e
        for e in await repository.get_events(user.bundle_id)
        if e.event_type is BundleEventType.POLL_FAILED
    ]
    assert len(failures) == 1


async def test_a_different_failure_is_still_recorded(repository):
    """Collapsing repeats must not hide a new symptom."""
    user = await seed_user(repository)

    await repository.touch_poll(user.bundle_id, "homeserver unreachable")
    await repository.touch_poll(user.bundle_id, "homeserver unreachable")
    await repository.touch_poll(user.bundle_id, "admin token expired")

    details = [
        e.detail
        for e in await repository.get_events(user.bundle_id)
        if e.event_type is BundleEventType.POLL_FAILED
    ]
    assert details == ["homeserver unreachable", "admin token expired"]


async def test_a_failure_after_recovery_is_recorded_again(repository):
    """Only *consecutive* identical failures collapse."""
    user = await seed_user(repository)

    await repository.touch_poll(user.bundle_id, "homeserver unreachable")
    await repository.mark_redeemed(user.bundle_id)
    await repository.touch_poll(user.bundle_id, "homeserver unreachable")

    failures = [
        e
        for e in await repository.get_events(user.bundle_id)
        if e.event_type is BundleEventType.POLL_FAILED
    ]
    assert len(failures) == 2


async def test_a_successful_poll_records_nothing(repository):
    user = await seed_user(repository)
    before = len(await repository.get_events(user.bundle_id))

    await repository.touch_poll(user.bundle_id)

    assert len(await repository.get_events(user.bundle_id)) == before


async def test_the_event_trail_is_capped_and_keeps_the_newest_entries(repository):
    """An unbounded read is a response size no caller can predict."""
    user = await seed_user(repository)
    for i in range(30):
        await repository.touch_poll(user.bundle_id, f"failure {i}")

    events = await repository.get_events(user.bundle_id, limit=5)

    assert len(events) == 5
    assert [e.detail for e in events] == [f"failure {i}" for i in range(25, 30)]


async def test_the_capped_trail_is_still_oldest_first(repository):
    user = await seed_user(repository)
    for i in range(10):
        await repository.touch_poll(user.bundle_id, f"failure {i}")

    events = await repository.get_events(user.bundle_id, limit=4)

    assert [e.id for e in events] == sorted(e.id for e in events)
