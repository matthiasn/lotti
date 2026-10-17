"""Durable ledger for erasing the accounts of lapsed subscribers.

Erasure crosses SQLite and Synapse in several irreversible steps, and a
renewal can race it. The ledger makes both safe:

* **Claiming** is one transaction that re-checks eligibility (still suspended,
  since before the cutoff, not revoked), revokes the bundle, and detaches it
  from every subscription row. From then on no enforcement path can unsuspend
  the account, and a renewal that lost the race provisions a fresh one.
* **Each step is recorded**, so a run that fails part way resumes where it
  stopped instead of repeating a step Synapse would now reject.
* **Completion** deletes the bundle claim, which is what lets a later payment
  on the same entitlement provision a new account rather than meet a
  terminal claim.
"""

from __future__ import annotations

import asyncio
import sqlite3
from dataclasses import dataclass
from datetime import datetime

from ..core.constants import DEFAULT_DB_PATH
from ..core.models import BundleEventType, BundleStatus
from .subscription_repository import SubscriptionRepository, _iso, _parse

ERASURE_STEPS = ("media_deleted_at", "room_deleted_at", "user_erased_at")

_ERASURE_SCHEMA = """
CREATE TABLE IF NOT EXISTS account_erasures (
    bundle_id        TEXT PRIMARY KEY,
    user_mxid        TEXT NOT NULL,
    room_id          TEXT NOT NULL,
    started_at       TEXT NOT NULL,
    media_deleted_at TEXT,
    room_deleted_at  TEXT,
    user_erased_at   TEXT,
    completed_at     TEXT,
    last_error       TEXT,
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id)
);

CREATE INDEX IF NOT EXISTS idx_account_erasures_open
    ON account_erasures (completed_at, started_at);
"""


@dataclass(frozen=True)
class AccountErasure:
    """One account's erasure and the steps already done."""

    bundle_id: str
    user_mxid: str
    room_id: str
    started_at: datetime
    media_deleted_at: datetime | None
    room_deleted_at: datetime | None
    user_erased_at: datetime | None
    completed_at: datetime | None
    last_error: str | None


class AccountErasureRepository(SubscriptionRepository):
    """Adds the erasure ledger to the paid schema."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        super().__init__(db_path)
        conn = self._connect()
        try:
            conn.executescript(_ERASURE_SCHEMA)
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def _row_to_erasure(row: sqlite3.Row) -> AccountErasure:
        return AccountErasure(
            bundle_id=row["bundle_id"],
            user_mxid=row["user_mxid"],
            room_id=row["room_id"],
            started_at=_parse(row["started_at"]),
            media_deleted_at=_parse(row["media_deleted_at"]),
            room_deleted_at=_parse(row["room_deleted_at"]),
            user_erased_at=_parse(row["user_erased_at"]),
            completed_at=_parse(row["completed_at"]),
            last_error=row["last_error"],
        )

    def _claim_erasure_sync(
        self,
        bundle_id: str,
        suspended_before: datetime,
        now: datetime,
    ) -> bool:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            user = conn.execute(
                "SELECT u.* FROM play_subscriptions s "
                "JOIN provisioned_users u ON u.bundle_id = s.bundle_id "
                "WHERE s.bundle_id = ? AND s.is_current = 1 AND s.matrix_suspended = 1 "
                "AND s.suspended_at IS NOT NULL AND s.suspended_at <= ? AND u.status != ?",
                (bundle_id, _iso(suspended_before), BundleStatus.REVOKED.value),
            ).fetchone()
            if user is None:
                # Renewed, or already claimed, since the batch was listed.
                conn.rollback()
                return False
            conn.execute(
                "UPDATE provisioned_users SET status = ?, revoked_at = ? WHERE bundle_id = ?",
                (BundleStatus.REVOKED.value, _iso(now), bundle_id),
            )
            self._terminalize_related_state_on_revoke_sync(conn, bundle_id, now, None)
            self._record_event_sync(
                conn,
                bundle_id,
                BundleEventType.REVOKED,
                "Erasing after the subscription stayed lapsed",
            )
            # Detached, the account has no subscription left to enforce, so
            # nothing can unsuspend it while its data is being deleted.
            conn.execute(
                "UPDATE play_subscriptions SET bundle_id = NULL WHERE bundle_id = ?",
                (bundle_id,),
            )
            conn.execute(
                "INSERT INTO account_erasures (bundle_id, user_mxid, room_id, started_at) "
                "VALUES (?, ?, ?, ?)",
                (bundle_id, user["user_mxid"], user["room_id"], _iso(now)),
            )
            conn.commit()
            return True
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def claim_erasure(
        self,
        bundle_id: str,
        *,
        suspended_before: datetime,
        now: datetime,
    ) -> bool:
        """Start erasing ``bundle_id`` if it is still eligible; return whether it was."""
        return await asyncio.to_thread(
            self._claim_erasure_sync,
            bundle_id,
            suspended_before,
            now,
        )

    def _list_open_erasures_sync(self, limit: int) -> list[AccountErasure]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM account_erasures WHERE completed_at IS NULL "
                "ORDER BY started_at ASC LIMIT ?",
                (max(1, limit),),
            ).fetchall()
            return [self._row_to_erasure(row) for row in rows]
        finally:
            conn.close()

    async def list_open_erasures(self, *, limit: int) -> list[AccountErasure]:
        """Erasures started but not finished, oldest first."""
        return await asyncio.to_thread(self._list_open_erasures_sync, limit)

    def _record_erasure_step_sync(self, bundle_id: str, step: str, now: datetime) -> None:
        if step not in ERASURE_STEPS:
            raise ValueError(f"Unknown erasure step {step!r}")
        conn = self._connect()
        try:
            conn.execute(
                f"UPDATE account_erasures SET {step} = ?, last_error = NULL "  # noqa: S608
                "WHERE bundle_id = ?",
                (_iso(now), bundle_id),
            )
            conn.commit()
        finally:
            conn.close()

    async def record_erasure_step(self, bundle_id: str, step: str, *, now: datetime) -> None:
        """Mark one of :data:`ERASURE_STEPS` done."""
        await asyncio.to_thread(self._record_erasure_step_sync, bundle_id, step, now)

    def _record_erasure_error_sync(self, bundle_id: str, error: str) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE account_erasures SET last_error = ? WHERE bundle_id = ?",
                (error[:500], bundle_id),
            )
            conn.commit()
        finally:
            conn.close()

    async def record_erasure_error(self, bundle_id: str, error: str) -> None:
        """Keep the latest failure for the operator; the next run retries."""
        await asyncio.to_thread(self._record_erasure_error_sync, bundle_id, error)

    def _complete_erasure_sync(self, bundle_id: str, now: datetime) -> None:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            conn.execute(
                "UPDATE account_erasures SET completed_at = ?, last_error = NULL "
                "WHERE bundle_id = ?",
                (_iso(now), bundle_id),
            )
            conn.execute("DELETE FROM bundle_claims WHERE bundle_id = ?", (bundle_id,))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def complete_erasure(self, bundle_id: str, *, now: datetime) -> None:
        """Close the erasure and free the entitlement for a fresh account."""
        await asyncio.to_thread(self._complete_erasure_sync, bundle_id, now)
