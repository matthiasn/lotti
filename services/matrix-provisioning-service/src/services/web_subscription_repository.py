"""Persistence for web checkout sessions and Paddle webhook idempotency.

Web subscriptions themselves live in the shared subscription table with
``provider = 'paddle'``; this layer only adds what the web path needs on top:
the session that ties a Paddle checkout to an anonymous entitlement, and the
ledger of processed Paddle event ids.
"""

from __future__ import annotations

import asyncio
import sqlite3
from datetime import datetime, timedelta

from ..core.constants import DEFAULT_DB_PATH
from ..core.subscriptions import CheckoutSession
from .subscription_repository import SubscriptionRepository, _iso, _parse

ATTEMPT_KIND_WEB_CHECKOUT = "web_checkout"

#: Unbound sessions are useless after expiry; bound ones are kept because the
#: claim secret hash on them authorizes bundle delivery.
_UNBOUND_SESSION_RETENTION = timedelta(days=1)

_WEB_SCHEMA = """
CREATE TABLE IF NOT EXISTS checkout_sessions (
    session_id              TEXT PRIMARY KEY,
    entitlement_id          TEXT NOT NULL,
    claim_secret_hash       TEXT NOT NULL,
    price_id                TEXT NOT NULL,
    expires_at              TEXT NOT NULL,
    bound_token_fingerprint TEXT,
    bound_at                TEXT,
    created_at              TEXT NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_checkout_sessions_binding
    ON checkout_sessions (entitlement_id, bound_token_fingerprint);

CREATE TABLE IF NOT EXISTS paddle_webhook_events (
    event_id     TEXT PRIMARY KEY,
    event_type   TEXT NOT NULL,
    occurred_at  TEXT NOT NULL,
    processed_at TEXT NOT NULL
);
"""


class WebSubscriptionRepository(SubscriptionRepository):
    """Adds checkout sessions and Paddle event ids to the paid schema."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        super().__init__(db_path)
        conn = self._connect()
        try:
            conn.executescript(_WEB_SCHEMA)
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def _row_to_checkout_session(row: sqlite3.Row) -> CheckoutSession:
        return CheckoutSession(
            session_id=row["session_id"],
            entitlement_id=row["entitlement_id"],
            claim_secret_hash=row["claim_secret_hash"],
            price_id=row["price_id"],
            expires_at=_parse(row["expires_at"]),
            bound_token_fingerprint=row["bound_token_fingerprint"],
            bound_at=_parse(row["bound_at"]),
            created_at=_parse(row["created_at"]),
        )

    def _create_checkout_session_sync(self, session: CheckoutSession) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "DELETE FROM checkout_sessions WHERE bound_token_fingerprint IS NULL "
                "AND expires_at < ?",
                (_iso(session.created_at - _UNBOUND_SESSION_RETENTION),),
            )
            conn.execute(
                "INSERT INTO checkout_sessions (session_id, entitlement_id, "
                "claim_secret_hash, price_id, expires_at, created_at) "
                "VALUES (?,?,?,?,?,?)",
                (
                    session.session_id,
                    session.entitlement_id,
                    session.claim_secret_hash,
                    session.price_id,
                    _iso(session.expires_at),
                    _iso(session.created_at),
                ),
            )
            conn.commit()
        finally:
            conn.close()

    async def create_checkout_session(self, session: CheckoutSession) -> None:
        """Persist a new session, pruning long-expired unbound ones."""
        await asyncio.to_thread(self._create_checkout_session_sync, session)

    def _get_checkout_session_sync(self, session_id: str) -> CheckoutSession | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM checkout_sessions WHERE session_id = ?",
                (session_id,),
            ).fetchone()
            return self._row_to_checkout_session(row) if row else None
        finally:
            conn.close()

    async def get_checkout_session(self, session_id: str) -> CheckoutSession | None:
        """Return a session by id, or ``None``."""
        return await asyncio.to_thread(self._get_checkout_session_sync, session_id)

    def _bind_checkout_session_sync(
        self,
        session_id: str,
        token_fingerprint: str,
        now: datetime,
    ) -> CheckoutSession | None:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE checkout_sessions SET bound_token_fingerprint = ?, bound_at = ? "
                "WHERE session_id = ? AND bound_token_fingerprint IS NULL",
                (token_fingerprint, _iso(now), session_id),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM checkout_sessions WHERE session_id = ?",
                (session_id,),
            ).fetchone()
            return self._row_to_checkout_session(row) if row else None
        finally:
            conn.close()

    async def bind_checkout_session(
        self,
        session_id: str,
        *,
        token_fingerprint: str,
        now: datetime,
    ) -> CheckoutSession | None:
        """Bind a session to the subscription it produced; the first binding wins."""
        return await asyncio.to_thread(
            self._bind_checkout_session_sync,
            session_id,
            token_fingerprint,
            now,
        )

    def _get_bound_checkout_session_sync(
        self,
        entitlement_id: str,
        token_fingerprint: str,
    ) -> CheckoutSession | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM checkout_sessions WHERE entitlement_id = ? "
                "AND bound_token_fingerprint = ? ORDER BY bound_at ASC LIMIT 1",
                (entitlement_id, token_fingerprint),
            ).fetchone()
            return self._row_to_checkout_session(row) if row else None
        finally:
            conn.close()

    async def get_bound_checkout_session(
        self,
        entitlement_id: str,
        *,
        token_fingerprint: str,
    ) -> CheckoutSession | None:
        """Return the session whose checkout produced this subscription."""
        return await asyncio.to_thread(
            self._get_bound_checkout_session_sync,
            entitlement_id,
            token_fingerprint,
        )

    def _webhook_event_processed_sync(self, event_id: str) -> bool:
        conn = self._connect()
        try:
            return (
                conn.execute(
                    "SELECT 1 FROM paddle_webhook_events WHERE event_id = ?",
                    (event_id,),
                ).fetchone()
                is not None
            )
        finally:
            conn.close()

    async def webhook_event_processed(self, event_id: str) -> bool:
        """Whether a Paddle event id has already been applied."""
        return await asyncio.to_thread(self._webhook_event_processed_sync, event_id)

    def _record_webhook_event_sync(
        self,
        event_id: str,
        event_type: str,
        occurred_at: datetime,
        now: datetime,
    ) -> None:
        conn = self._connect()
        try:
            conn.execute(
                "INSERT OR IGNORE INTO paddle_webhook_events "
                "(event_id, event_type, occurred_at, processed_at) VALUES (?,?,?,?)",
                (event_id, event_type, _iso(occurred_at), _iso(now)),
            )
            conn.commit()
        finally:
            conn.close()

    async def record_webhook_event(
        self,
        event_id: str,
        *,
        event_type: str,
        occurred_at: datetime,
        now: datetime,
    ) -> None:
        """Mark an event applied. Recorded only after success, so a failed
        application is retried by Paddle rather than silently dropped."""
        await asyncio.to_thread(
            self._record_webhook_event_sync,
            event_id,
            event_type,
            occurred_at,
            now,
        )
