"""SQLite-backed persistence for provisioned users, bundles and purge runs.

Mirrors the credits-service pattern: synchronous sqlite3 work wrapped in
``asyncio.to_thread`` so the event loop is never blocked.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone

from ..core.constants import DEFAULT_DB_PATH, DEFAULT_EVENT_LIMIT, MAX_PAGE_SIZE
from ..core.exceptions import (
    BundleNotFoundException,
    InvalidBundleStateException,
    UsernameAlreadyProvisionedException,
)
from ..core.models import (
    BundleEvent,
    BundleEventType,
    BundleStatus,
    PaymentStatus,
    ProvisionedUser,
    StatsResponse,
)

logger = logging.getLogger(__name__)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS provisioned_users (
    bundle_id           TEXT PRIMARY KEY,
    username            TEXT NOT NULL,
    user_mxid           TEXT NOT NULL,
    home_server         TEXT NOT NULL,
    server_name         TEXT NOT NULL,
    room_id             TEXT NOT NULL,
    display_name        TEXT,
    status              TEXT NOT NULL,
    payment_status      TEXT NOT NULL,
    bundle_fingerprint  TEXT NOT NULL,
    created_at          TEXT NOT NULL,
    first_login_at      TEXT,
    rotated_at          TEXT,
    revoked_at          TEXT,
    last_seen_at        TEXT,
    last_polled_at      TEXT,
    notes               TEXT NOT NULL DEFAULT '',
    retention_days      INTEGER,
    retention_exempt    INTEGER NOT NULL DEFAULT 0
);

-- One account per username per homeserver. Synapse would reject a duplicate
-- anyway, but failing here avoids a pointless round trip and a confusing 500.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_server
    ON provisioned_users (username, server_name);

CREATE INDEX IF NOT EXISTS idx_users_status ON provisioned_users (status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON provisioned_users (created_at);

CREATE TABLE IF NOT EXISTS bundle_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    bundle_id   TEXT NOT NULL,
    event_type  TEXT NOT NULL,
    detail      TEXT NOT NULL DEFAULT '',
    created_at  TEXT NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_events_bundle ON bundle_events (bundle_id, id);

-- `media_deleted` and `bytes_freed` are what makes a purge more than an event:
-- once media is gone the live figures no longer show that the account ever held
-- it, and on a journalling app the media *is* the data the user created. These
-- rows are the only surviving record of that volume, and they cannot be
-- reconstructed after the fact.
CREATE TABLE IF NOT EXISTS purge_runs (
    purge_id        TEXT PRIMARY KEY,
    bundle_id       TEXT NOT NULL,
    room_id         TEXT NOT NULL,
    purge_up_to_ts  INTEGER NOT NULL,
    status          TEXT NOT NULL,
    started_at      TEXT NOT NULL,
    completed_at    TEXT,
    media_deleted   INTEGER NOT NULL DEFAULT 0,
    bytes_freed     INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_purges_bundle ON purge_runs (bundle_id, started_at);
"""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _parse(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


class ProvisioningRepository:
    """Stores what the CLI never did: who was provisioned, and what happened next."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        self._ensure_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    #: Columns added after the first release, keyed by table, with the DDL to
    #: add them. SQLite has no "ADD COLUMN IF NOT EXISTS", so they are applied
    #: conditionally against the live schema.
    _MIGRATIONS: dict[str, dict[str, str]] = {
        "provisioned_users": {
            "retention_days": (
                "ALTER TABLE provisioned_users ADD COLUMN retention_days INTEGER"
            ),
            "retention_exempt": (
                "ALTER TABLE provisioned_users "
                "ADD COLUMN retention_exempt INTEGER NOT NULL DEFAULT 0"
            ),
        },
        "purge_runs": {
            "media_deleted": (
                "ALTER TABLE purge_runs "
                "ADD COLUMN media_deleted INTEGER NOT NULL DEFAULT 0"
            ),
            "bytes_freed": (
                "ALTER TABLE purge_runs "
                "ADD COLUMN bytes_freed INTEGER NOT NULL DEFAULT 0"
            ),
        },
    }

    def _ensure_db(self) -> None:
        """Create the database file and schema, and apply column migrations."""
        os.makedirs(os.path.dirname(self.db_path) or ".", exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        try:
            conn.executescript(_SCHEMA)
            for table, columns in self._MIGRATIONS.items():
                existing = {
                    row[1]
                    for row in conn.execute(f"PRAGMA table_info({table})").fetchall()
                }
                for column, ddl in columns.items():
                    if column not in existing:
                        conn.execute(ddl)
                        logger.info("Migrated %s: added %s", table, column)
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def _row_to_user(row: sqlite3.Row) -> ProvisionedUser:
        return ProvisionedUser(
            bundle_id=row["bundle_id"],
            username=row["username"],
            user_mxid=row["user_mxid"],
            home_server=row["home_server"],
            server_name=row["server_name"],
            room_id=row["room_id"],
            display_name=row["display_name"],
            status=BundleStatus(row["status"]),
            payment_status=PaymentStatus(row["payment_status"]),
            bundle_fingerprint=row["bundle_fingerprint"],
            created_at=_parse(row["created_at"]),
            first_login_at=_parse(row["first_login_at"]),
            rotated_at=_parse(row["rotated_at"]),
            revoked_at=_parse(row["revoked_at"]),
            last_seen_at=_parse(row["last_seen_at"]),
            last_polled_at=_parse(row["last_polled_at"]),
            notes=row["notes"] or "",
            retention_days=row["retention_days"],
            retention_exempt=bool(row["retention_exempt"]),
        )

    # -- writes -------------------------------------------------------------

    def _record_event_sync(
        self,
        conn: sqlite3.Connection,
        bundle_id: str,
        event_type: BundleEventType,
        detail: str = "",
    ) -> None:
        conn.execute(
            "INSERT INTO bundle_events (bundle_id, event_type, detail, created_at) "
            "VALUES (?, ?, ?, ?)",
            (bundle_id, event_type.value, detail, _iso(_now())),
        )

    def _create_sync(
        self,
        *,
        username: str,
        user_mxid: str,
        home_server: str,
        server_name: str,
        room_id: str,
        display_name: str | None,
        bundle_fingerprint: str,
        notes: str,
    ) -> ProvisionedUser:
        bundle_id = str(uuid.uuid4())
        created_at = _now()
        conn = self._connect()
        try:
            try:
                conn.execute(
                    "INSERT INTO provisioned_users ("
                    "bundle_id, username, user_mxid, home_server, server_name, room_id, "
                    "display_name, status, payment_status, bundle_fingerprint, created_at, notes"
                    ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        bundle_id,
                        username,
                        user_mxid,
                        home_server,
                        server_name,
                        room_id,
                        display_name,
                        BundleStatus.UNUSED.value,
                        PaymentStatus.UNKNOWN.value,
                        bundle_fingerprint,
                        _iso(created_at),
                        notes,
                    ),
                )
            except sqlite3.IntegrityError as exc:
                raise UsernameAlreadyProvisionedException(
                    f"{username} is already provisioned on {server_name}"
                ) from exc

            self._record_event_sync(
                conn, bundle_id, BundleEventType.CREATED, f"Provisioned {user_mxid}"
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row)
        finally:
            conn.close()

    async def create(
        self,
        *,
        username: str,
        user_mxid: str,
        home_server: str,
        server_name: str,
        room_id: str,
        display_name: str | None,
        bundle_fingerprint: str,
        notes: str = "",
    ) -> ProvisionedUser:
        """Record a freshly provisioned account.

        Raises:
            UsernameAlreadyProvisionedException: If the username already exists
                on this homeserver.
        """
        return await asyncio.to_thread(
            self._create_sync,
            username=username,
            user_mxid=user_mxid,
            home_server=home_server,
            server_name=server_name,
            room_id=room_id,
            display_name=display_name,
            bundle_fingerprint=bundle_fingerprint,
            notes=notes,
        )

    def _mark_redeemed_sync(self, bundle_id: str, last_seen_at: datetime | None) -> ProvisionedUser:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleNotFoundException(bundle_id)

            current = BundleStatus(row["status"])
            if current is BundleStatus.REVOKED:
                raise InvalidBundleStateException(
                    f"Bundle {bundle_id} is revoked and cannot be redeemed"
                )

            # Redemption is only ever an advance from UNUSED. Observing activity
            # on an already-rotated account must not walk the status backwards.
            first_login = _parse(row["first_login_at"]) or last_seen_at or _now()
            new_status = (
                BundleStatus.REDEEMED if current is BundleStatus.UNUSED else current
            )

            conn.execute(
                "UPDATE provisioned_users SET status = ?, first_login_at = ?, "
                "last_seen_at = ?, last_polled_at = ? WHERE bundle_id = ?",
                (
                    new_status.value,
                    _iso(first_login),
                    _iso(last_seen_at),
                    _iso(_now()),
                    bundle_id,
                ),
            )
            if current is BundleStatus.UNUSED:
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.REDEEMED,
                    "Sign-in observed on the homeserver",
                )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row)
        finally:
            conn.close()

    async def mark_redeemed(
        self, bundle_id: str, last_seen_at: datetime | None = None
    ) -> ProvisionedUser:
        """Advance a bundle to ``REDEEMED`` after observing a sign-in.

        Idempotent: re-observing activity on an already redeemed or rotated
        bundle refreshes timestamps without changing the status.
        """
        return await asyncio.to_thread(self._mark_redeemed_sync, bundle_id, last_seen_at)

    def _mark_rotated_sync(self, bundle_id: str) -> ProvisionedUser:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleNotFoundException(bundle_id)

            current = BundleStatus(row["status"])
            if current is BundleStatus.REVOKED:
                raise InvalidBundleStateException(
                    f"Bundle {bundle_id} is revoked and cannot be rotated"
                )
            if current is BundleStatus.ROTATED:
                return self._row_to_user(row)

            now = _now()
            # A rotation callback also proves redemption, even if the poller has
            # not caught up yet.
            first_login = _parse(row["first_login_at"]) or now
            conn.execute(
                "UPDATE provisioned_users SET status = ?, rotated_at = ?, first_login_at = ? "
                "WHERE bundle_id = ?",
                (BundleStatus.ROTATED.value, _iso(now), _iso(first_login), bundle_id),
            )
            self._record_event_sync(
                conn, bundle_id, BundleEventType.ROTATED, "Client confirmed password rotation"
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row)
        finally:
            conn.close()

    async def mark_rotated(self, bundle_id: str) -> ProvisionedUser:
        """Advance a bundle to ``ROTATED`` on confirmed client rotation."""
        return await asyncio.to_thread(self._mark_rotated_sync, bundle_id)

    def _revoke_sync(self, bundle_id: str, reason: str) -> ProvisionedUser:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleNotFoundException(bundle_id)

            conn.execute(
                "UPDATE provisioned_users SET status = ?, revoked_at = ? WHERE bundle_id = ?",
                (BundleStatus.REVOKED.value, _iso(_now()), bundle_id),
            )
            self._record_event_sync(
                conn, bundle_id, BundleEventType.REVOKED, reason or "Revoked by admin"
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row)
        finally:
            conn.close()

    async def revoke(self, bundle_id: str, reason: str = "") -> ProvisionedUser:
        """Mark a bundle revoked. Does not touch the Matrix account itself."""
        return await asyncio.to_thread(self._revoke_sync, bundle_id, reason)

    def _update_sync(
        self,
        bundle_id: str,
        payment_status: PaymentStatus | None,
        notes: str | None,
        retention_days: int | None,
        retention_exempt: bool | None,
        clear_retention_override: bool,
    ) -> ProvisionedUser:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleNotFoundException(bundle_id)

            if payment_status is not None and payment_status.value != row["payment_status"]:
                conn.execute(
                    "UPDATE provisioned_users SET payment_status = ? WHERE bundle_id = ?",
                    (payment_status.value, bundle_id),
                )
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.PAYMENT_STATUS_CHANGED,
                    f"{row['payment_status']} → {payment_status.value}",
                )

            if notes is not None and notes != (row["notes"] or ""):
                conn.execute(
                    "UPDATE provisioned_users SET notes = ? WHERE bundle_id = ?",
                    (notes, bundle_id),
                )
                self._record_event_sync(conn, bundle_id, BundleEventType.NOTE_UPDATED)

            # `None` already means "unchanged", so clearing an override needs
            # its own explicit flag rather than a magic value.
            if clear_retention_override and row["retention_days"] is not None:
                conn.execute(
                    "UPDATE provisioned_users SET retention_days = NULL WHERE bundle_id = ?",
                    (bundle_id,),
                )
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.RETENTION_CHANGED,
                    f"{row['retention_days']}d → service default",
                )
            elif retention_days is not None and retention_days != row["retention_days"]:
                conn.execute(
                    "UPDATE provisioned_users SET retention_days = ? WHERE bundle_id = ?",
                    (retention_days, bundle_id),
                )
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.RETENTION_CHANGED,
                    f"{row['retention_days'] or 'default'} → {retention_days}d",
                )

            if (
                retention_exempt is not None
                and int(retention_exempt) != row["retention_exempt"]
            ):
                conn.execute(
                    "UPDATE provisioned_users SET retention_exempt = ? WHERE bundle_id = ?",
                    (int(retention_exempt), bundle_id),
                )
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.RETENTION_CHANGED,
                    "exempted from sweep" if retention_exempt else "included in sweep",
                )

            conn.commit()
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row)
        finally:
            conn.close()

    async def update(
        self,
        bundle_id: str,
        *,
        payment_status: PaymentStatus | None = None,
        notes: str | None = None,
        retention_days: int | None = None,
        retention_exempt: bool | None = None,
        clear_retention_override: bool = False,
    ) -> ProvisionedUser:
        """Update the manually maintained fields, recording an audit event."""
        return await asyncio.to_thread(
            self._update_sync,
            bundle_id,
            payment_status,
            notes,
            retention_days,
            retention_exempt,
            clear_retention_override,
        )

    def _touch_poll_sync(self, bundle_id: str, detail: str | None) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE provisioned_users SET last_polled_at = ? WHERE bundle_id = ?",
                (_iso(_now()), bundle_id),
            )
            if detail and not self._repeats_last_failure(conn, bundle_id, detail):
                self._record_event_sync(
                    conn, bundle_id, BundleEventType.POLL_FAILED, detail
                )
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def _repeats_last_failure(
        conn: sqlite3.Connection, bundle_id: str, detail: str
    ) -> bool:
        """Whether this failure is a repeat of the bundle's latest event.

        The poller retries every pollable bundle on a fixed interval forever, so
        an outage that lasts a weekend would otherwise write ~576 identical rows
        per bundle per day and bury the real audit trail. Collapsing a run of
        identical consecutive failures into its first entry keeps the trail
        readable; ``last_polled_at`` is what says whether it is still failing.
        """
        row = conn.execute(
            "SELECT event_type, detail FROM bundle_events WHERE bundle_id = ? "
            "ORDER BY id DESC LIMIT 1",
            (bundle_id,),
        ).fetchone()
        return (
            row is not None
            and row["event_type"] == BundleEventType.POLL_FAILED.value
            and (row["detail"] or "") == detail
        )

    async def touch_poll(self, bundle_id: str, failure_detail: str | None = None) -> None:
        """Record that the poller checked this account, optionally noting a failure.

        A failure identical to the bundle's most recent event is not recorded
        again, so a sustained outage leaves one entry rather than one per poll.
        """
        await asyncio.to_thread(self._touch_poll_sync, bundle_id, failure_detail)

    # -- reads --------------------------------------------------------------

    def _get_sync(self, bundle_id: str) -> ProvisionedUser | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(row) if row else None
        finally:
            conn.close()

    async def get(self, bundle_id: str) -> ProvisionedUser | None:
        """Fetch one record, or ``None`` if the bundle ID is unknown."""
        return await asyncio.to_thread(self._get_sync, bundle_id)

    def _find_by_username_sync(self, username: str) -> ProvisionedUser | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM provisioned_users WHERE username = ? "
                "ORDER BY created_at DESC LIMIT 1",
                (username,),
            ).fetchone()
            return self._row_to_user(row) if row else None
        finally:
            conn.close()

    async def find_by_username(self, username: str) -> ProvisionedUser | None:
        """Return the most recent record for a username, or ``None``.

        Used to reject a duplicate before provisioning, so the common failure
        does not leave an orphan account on Synapse to roll back.
        """
        return await asyncio.to_thread(self._find_by_username_sync, username)

    def _list_sync(
        self,
        page: int,
        page_size: int,
        status: BundleStatus | None,
        payment_status: PaymentStatus | None,
    ) -> tuple[list[ProvisionedUser], int]:
        page = max(1, page)
        page_size = max(1, min(MAX_PAGE_SIZE, page_size))

        where, params = [], []
        if status is not None:
            where.append("status = ?")
            params.append(status.value)
        if payment_status is not None:
            where.append("payment_status = ?")
            params.append(payment_status.value)
        clause = f" WHERE {' AND '.join(where)}" if where else ""

        conn = self._connect()
        try:
            total = conn.execute(
                f"SELECT COUNT(*) FROM provisioned_users{clause}", params
            ).fetchone()[0]
            rows = conn.execute(
                f"SELECT * FROM provisioned_users{clause} "
                "ORDER BY created_at DESC LIMIT ? OFFSET ?",
                [*params, page_size, (page - 1) * page_size],
            ).fetchall()
            return [self._row_to_user(r) for r in rows], total
        finally:
            conn.close()

    async def list_users(
        self,
        page: int = 1,
        page_size: int = 20,
        status: BundleStatus | None = None,
        payment_status: PaymentStatus | None = None,
    ) -> tuple[list[ProvisionedUser], int]:
        """List records newest first, optionally filtered."""
        return await asyncio.to_thread(
            self._list_sync, page, page_size, status, payment_status
        )

    def _list_pollable_sync(self, limit: int) -> list[ProvisionedUser]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM provisioned_users WHERE status IN (?, ?) "
                "ORDER BY COALESCE(last_polled_at, '') ASC LIMIT ?",
                (BundleStatus.UNUSED.value, BundleStatus.REDEEMED.value, limit),
            ).fetchall()
            return [self._row_to_user(r) for r in rows]
        finally:
            conn.close()

    async def list_pollable(self, limit: int) -> list[ProvisionedUser]:
        """Return accounts still worth polling, least-recently-polled first.

        Rotated and revoked bundles are terminal, so they are never polled again.
        """
        return await asyncio.to_thread(self._list_pollable_sync, limit)

    def _list_purgeable_sync(self, limit: int) -> list[ProvisionedUser]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM provisioned_users "
                "WHERE first_login_at IS NOT NULL "
                "  AND revoked_at IS NULL "
                "  AND retention_exempt = 0 "
                "ORDER BY created_at ASC LIMIT ?",
                (limit,),
            ).fetchall()
            return [self._row_to_user(r) for r in rows]
        finally:
            conn.close()

    async def list_purgeable(self, limit: int = 500) -> list[ProvisionedUser]:
        """Return users the retention sweep should process.

        Filters in SQL rather than in Python so the sweep does not page the
        whole roster to discard most of it: an unredeemed room holds nothing,
        a revoked one may be under investigation, and an exempt user has been
        deliberately pinned.
        """
        return await asyncio.to_thread(self._list_purgeable_sync, limit)

    def _events_sync(self, bundle_id: str, limit: int) -> list[BundleEvent]:
        conn = self._connect()
        try:
            # Newest-first in SQL so the limit keeps the *recent* entries, then
            # reversed for display. Selecting the oldest N would pin the caller
            # to the creation event forever.
            rows = conn.execute(
                "SELECT * FROM bundle_events WHERE bundle_id = ? ORDER BY id DESC LIMIT ?",
                (bundle_id, max(1, limit)),
            ).fetchall()
            return [
                BundleEvent(
                    id=r["id"],
                    bundle_id=r["bundle_id"],
                    event_type=BundleEventType(r["event_type"]),
                    detail=r["detail"] or "",
                    created_at=_parse(r["created_at"]),
                )
                for r in reversed(rows)
            ]
        finally:
            conn.close()

    async def get_events(
        self, bundle_id: str, limit: int = DEFAULT_EVENT_LIMIT
    ) -> list[BundleEvent]:
        """Return a bundle's most recent audit entries, oldest first.

        Bounded rather than complete: the trail grows unattended (the poller
        writes to it), so an unlimited read is a response size no caller can
        predict.
        """
        return await asyncio.to_thread(self._events_sync, bundle_id, limit)

    def _stats_sync(self, signup_history_days: int) -> StatsResponse:
        conn = self._connect()
        try:
            status_counts = {
                r["status"]: r["n"]
                for r in conn.execute(
                    "SELECT status, COUNT(*) AS n FROM provisioned_users GROUP BY status"
                ).fetchall()
            }
            payment_counts = {
                r["payment_status"]: r["n"]
                for r in conn.execute(
                    "SELECT payment_status, COUNT(*) AS n FROM provisioned_users "
                    "GROUP BY payment_status"
                ).fetchall()
            }
            cutoff = _iso(_now() - timedelta(days=signup_history_days))
            signups = {
                r["day"]: r["n"]
                for r in conn.execute(
                    "SELECT substr(created_at, 1, 10) AS day, COUNT(*) AS n "
                    "FROM provisioned_users WHERE created_at >= ? GROUP BY day ORDER BY day",
                    (cutoff,),
                ).fetchall()
            }
            total = conn.execute("SELECT COUNT(*) FROM provisioned_users").fetchone()[0]
        finally:
            conn.close()

        return StatsResponse(
            total_provisioned=total,
            unused=status_counts.get(BundleStatus.UNUSED.value, 0),
            redeemed=status_counts.get(BundleStatus.REDEEMED.value, 0),
            rotated=status_counts.get(BundleStatus.ROTATED.value, 0),
            revoked=status_counts.get(BundleStatus.REVOKED.value, 0),
            paying=payment_counts.get(PaymentStatus.PAYING.value, 0),
            non_paying=payment_counts.get(PaymentStatus.NON_PAYING.value, 0),
            unknown_payment=payment_counts.get(PaymentStatus.UNKNOWN.value, 0),
            complimentary=payment_counts.get(PaymentStatus.COMPLIMENTARY.value, 0),
            signups_by_day=signups,
        )

    async def get_stats(self, signup_history_days: int = 90) -> StatsResponse:
        """Aggregate counts for the dashboard."""
        return await asyncio.to_thread(self._stats_sync, signup_history_days)

    # -- purge runs ---------------------------------------------------------

    def _record_purge_sync(
        self, purge_id: str, bundle_id: str, room_id: str, purge_up_to_ts: int
    ) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "INSERT INTO purge_runs (purge_id, bundle_id, room_id, purge_up_to_ts, "
                "status, started_at) VALUES (?, ?, ?, ?, ?, ?)",
                (purge_id, bundle_id, room_id, purge_up_to_ts, "active", _iso(_now())),
            )
            conn.commit()
        finally:
            conn.close()

    async def record_purge(
        self, purge_id: str, bundle_id: str, room_id: str, purge_up_to_ts: int
    ) -> None:
        """Record a started purge so its outcome can be reported later."""
        await asyncio.to_thread(
            self._record_purge_sync, purge_id, bundle_id, room_id, purge_up_to_ts
        )

    def _record_purge_volume_sync(
        self, purge_id: str, media_deleted: int, bytes_freed: int
    ) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE purge_runs SET media_deleted = ?, bytes_freed = ? "
                "WHERE purge_id = ?",
                (media_deleted, bytes_freed, purge_id),
            )
            conn.commit()
        finally:
            conn.close()

    async def record_purge_volume(
        self, purge_id: str, media_deleted: int, bytes_freed: int
    ) -> None:
        """Record how much a purge actually reclaimed.

        Written after the media deletion rather than with the run itself,
        because the figure is only known once the files are gone and the usage
        has been re-read.
        """
        await asyncio.to_thread(
            self._record_purge_volume_sync, purge_id, media_deleted, bytes_freed
        )

    def _purged_totals_sync(self, bundle_id: str) -> tuple[int, int]:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT COALESCE(SUM(bytes_freed), 0) AS b, "
                "COALESCE(SUM(media_deleted), 0) AS n "
                "FROM purge_runs WHERE bundle_id = ?",
                (bundle_id,),
            ).fetchone()
            return int(row["b"]), int(row["n"])
        finally:
            conn.close()

    async def purged_totals(self, bundle_id: str) -> tuple[int, int]:
        """Return ``(bytes_freed, media_deleted)`` across every purge of a bundle.

        Summed from the purge runs rather than kept as a counter on the user
        row, so the total cannot drift out of step with the history it is
        derived from.
        """
        return await asyncio.to_thread(self._purged_totals_sync, bundle_id)

    def _update_purge_sync(self, purge_id: str, status: str) -> None:
        conn = self._connect()
        try:
            completed = _iso(_now()) if status in ("complete", "failed") else None
            conn.execute(
                "UPDATE purge_runs SET status = ?, completed_at = ? WHERE purge_id = ?",
                (status, completed, purge_id),
            )
            conn.commit()
        finally:
            conn.close()

    async def update_purge_status(self, purge_id: str, status: str) -> None:
        """Update a purge run's status, stamping completion for terminal states."""
        await asyncio.to_thread(self._update_purge_sync, purge_id, status)

    def _list_purges_sync(self, bundle_id: str | None) -> list[dict]:
        conn = self._connect()
        try:
            if bundle_id:
                rows = conn.execute(
                    "SELECT * FROM purge_runs WHERE bundle_id = ? ORDER BY started_at DESC",
                    (bundle_id,),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT * FROM purge_runs ORDER BY started_at DESC LIMIT 200"
                ).fetchall()
            return [dict(r) for r in rows]
        finally:
            conn.close()

    async def list_purges(self, bundle_id: str | None = None) -> list[dict]:
        """List purge runs, newest first."""
        return await asyncio.to_thread(self._list_purges_sync, bundle_id)
