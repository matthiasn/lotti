"""SQLite persistence for Google Play subscription ownership and state."""

from __future__ import annotations

import asyncio
import math
import sqlite3
import uuid
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from ..core.constants import BUSY_TIMEOUT_SECONDS, DEFAULT_DB_PATH
from ..core.exceptions import (
    BundleClaimConflictException,
    GooglePlayVerificationException,
    InvalidBundleStateException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    SubscriptionLineageException,
)
from ..core.models import BundleEventType, BundleStatus, PaymentStatus, ProvisionedUser
from ..core.subscriptions import (
    ACCESS_ENTITLEMENT_STATES,
    AcknowledgementState,
    BundleClaim,
    EntitlementState,
    GoogleSubscriptionState,
    PaidProvisioningReservation,
    PurchaseIntent,
    StoredSubscription,
    SubscriptionEvent,
    SubscriptionEventType,
    SyncEntitlement,
    VerifiedSubscription,
)
from .provisioning_repository import ProvisioningRepository

ATTEMPT_KIND_BUNDLE_CLAIM = "bundle_claim"
ATTEMPT_KIND_PURCHASE_INTENT = "purchase_intent"
ATTEMPT_KIND_PURCHASE_VERIFICATION = "purchase_verification"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS sync_entitlements (
    entitlement_id         TEXT PRIMARY KEY,
    obfuscated_account_id  TEXT NOT NULL UNIQUE,
    auth_secret_hash       TEXT NOT NULL,
    created_at             TEXT NOT NULL,
    disabled_at            TEXT
);

CREATE TABLE IF NOT EXISTS entitlement_issuance_limits (
    client_key_hash   TEXT PRIMARY KEY,
    window_started_at TEXT NOT NULL,
    request_count     INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_entitlement_issuance_window
    ON entitlement_issuance_limits (window_started_at);

CREATE TABLE IF NOT EXISTS play_subscriptions (
    subscription_id                       TEXT PRIMARY KEY,
    entitlement_id                       TEXT NOT NULL,
    token_fingerprint                     TEXT NOT NULL UNIQUE,
    encrypted_purchase_token              BLOB NOT NULL,
    encryption_key_id                     TEXT NOT NULL,
    package_name                          TEXT NOT NULL,
    product_id                            TEXT NOT NULL,
    base_plan_id                          TEXT NOT NULL,
    latest_order_id                       TEXT,
    google_state                          TEXT NOT NULL,
    entitlement_state                     TEXT NOT NULL,
    start_time                            TEXT,
    current_period_end                    TEXT,
    grace_deadline                        TEXT,
    acknowledgement_state                 TEXT NOT NULL,
    acknowledged_at                       TEXT,
    linked_token_fingerprint              TEXT,
    replaced_by_token_fingerprint         TEXT,
    out_of_app_expired_token_fingerprint  TEXT,
    binding_verified                      INTEGER NOT NULL,
    bundle_id                             TEXT,
    is_current                            INTEGER NOT NULL DEFAULT 1,
    retired_at                            TEXT,
    suspended_at                          TEXT,
    unsuspended_at                        TEXT,
    matrix_suspended                      INTEGER,
    last_verified_at                      TEXT NOT NULL,
    next_reconciliation_at                TEXT NOT NULL,
    last_error                            TEXT,
    created_at                            TEXT NOT NULL,
    updated_at                            TEXT NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id),
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_play_current_entitlement
    ON play_subscriptions (entitlement_id) WHERE is_current = 1;
CREATE INDEX IF NOT EXISTS idx_play_reconciliation
    ON play_subscriptions (is_current, next_reconciliation_at);

CREATE TABLE IF NOT EXISTS subscription_events (
    event_id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    subscription_id               TEXT NOT NULL,
    entitlement_id                TEXT NOT NULL,
    token_fingerprint              TEXT NOT NULL,
    event_type                     TEXT NOT NULL,
    from_google_state              TEXT,
    to_google_state                TEXT NOT NULL,
    from_entitlement_state         TEXT,
    to_entitlement_state           TEXT NOT NULL,
    from_acknowledgement_state     TEXT,
    to_acknowledgement_state       TEXT NOT NULL,
    from_period_end                TEXT,
    to_period_end                  TEXT,
    created_at                     TEXT NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_subscription_events_token
    ON subscription_events (token_fingerprint, event_id);

CREATE TRIGGER IF NOT EXISTS subscription_events_no_update
BEFORE UPDATE ON subscription_events
BEGIN
    SELECT RAISE(ABORT, 'subscription events are immutable');
END;

CREATE TRIGGER IF NOT EXISTS subscription_events_no_delete
BEFORE DELETE ON subscription_events
BEGIN
    SELECT RAISE(ABORT, 'subscription events are immutable');
END;

CREATE TABLE IF NOT EXISTS purchase_intents (
    intent_id                    TEXT PRIMARY KEY,
    entitlement_id              TEXT NOT NULL,
    intent_secret_hash          TEXT NOT NULL,
    product_id                  TEXT NOT NULL,
    base_plan_id                TEXT NOT NULL,
    obfuscated_account_id       TEXT NOT NULL,
    expires_at                  TEXT NOT NULL,
    expected_request_hash       TEXT,
    consumed_token_fingerprint  TEXT,
    integrity_token_fingerprint TEXT,
    consumed_at                 TEXT,
    created_at                  TEXT NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_purchase_intents_entitlement
    ON purchase_intents (entitlement_id, created_at);

CREATE TABLE IF NOT EXISTS subscription_attempt_limits (
    entitlement_id    TEXT NOT NULL,
    operation_kind    TEXT NOT NULL,
    window_started_at TEXT NOT NULL,
    request_count     INTEGER NOT NULL,
    PRIMARY KEY (entitlement_id, operation_kind),
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_subscription_attempt_window
    ON subscription_attempt_limits (window_started_at);

CREATE TABLE IF NOT EXISTS purchase_intent_issuance_limits (
    entitlement_id   TEXT PRIMARY KEY,
    window_started_at TEXT NOT NULL,
    request_count     INTEGER NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);

CREATE INDEX IF NOT EXISTS idx_purchase_intent_issuance_window
    ON purchase_intent_issuance_limits (window_started_at);

CREATE TABLE IF NOT EXISTS play_integrity_replays (
    integrity_token_fingerprint TEXT PRIMARY KEY,
    intent_id                   TEXT NOT NULL,
    first_seen_at               TEXT NOT NULL,
    FOREIGN KEY (intent_id) REFERENCES purchase_intents (intent_id)
);

CREATE TABLE IF NOT EXISTS bundle_claims (
    bundle_id            TEXT PRIMARY KEY,
    subscription_id      TEXT NOT NULL UNIQUE,
    claim_secret_hash    TEXT NOT NULL,
    authorized_token_fingerprint TEXT NOT NULL,
    encrypted_bundle     BLOB,
    encryption_key_id    TEXT NOT NULL,
    expires_at           TEXT NOT NULL,
    first_delivered_at   TEXT,
    confirmed_at         TEXT,
    destroyed_at         TEXT,
    abandoned_at         TEXT,
    next_reap_at         TEXT,
    operation_token      TEXT,
    operation_kind       TEXT,
    operation_started_at TEXT,
    created_at           TEXT NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id) ON DELETE CASCADE,
    FOREIGN KEY (subscription_id) REFERENCES play_subscriptions (subscription_id)
);

CREATE TABLE IF NOT EXISTS paid_bundle_provisioning (
    entitlement_id   TEXT PRIMARY KEY,
    token_fingerprint TEXT NOT NULL,
    operation_token  TEXT NOT NULL UNIQUE,
    started_at       TEXT NOT NULL,
    FOREIGN KEY (entitlement_id) REFERENCES sync_entitlements (entitlement_id)
);
"""


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("Subscription timestamps must be timezone-aware")
    return value.astimezone(timezone.utc).isoformat()


def _parse(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


class SubscriptionRepository(ProvisioningRepository):
    """Owns stable entitlements and replay-safe Play token bindings."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        super().__init__(db_path)
        self._ensure_subscription_db()

    def _validate_legacy_rotation_sync(
        self,
        conn: sqlite3.Connection,
        bundle_id: str,
    ) -> None:
        """Require paid claims to use their challenge-bound confirmation flow."""
        paid_claim = conn.execute(
            "SELECT 1 FROM bundle_claims WHERE bundle_id = ?",
            (bundle_id,),
        ).fetchone()
        if paid_claim is not None:
            raise InvalidBundleStateException(
                "A paid bundle must use the subscription rotation confirmation endpoint"
            )

    def _ensure_subscription_db(self) -> None:
        # The paid schema deliberately references provisioned_users. Ensure the
        # older provisioning schema exists even when this repository is the
        # first service resolved by the container or a standalone maintenance
        # command.
        conn = sqlite3.connect(self.db_path, timeout=BUSY_TIMEOUT_SECONDS)
        try:
            conn.execute("PRAGMA journal_mode = WAL")
            conn.execute("PRAGMA foreign_keys = ON")
            conn.executescript(_SCHEMA)
            columns = {
                row[1] for row in conn.execute("PRAGMA table_info(bundle_claims)").fetchall()
            }
            if "next_reap_at" not in columns:
                conn.execute("ALTER TABLE bundle_claims ADD COLUMN next_reap_at TEXT")
            if "abandoned_at" not in columns:
                conn.execute("ALTER TABLE bundle_claims ADD COLUMN abandoned_at TEXT")
            if "operation_token" not in columns:
                conn.execute("ALTER TABLE bundle_claims ADD COLUMN operation_token TEXT")
            if "operation_kind" not in columns:
                conn.execute("ALTER TABLE bundle_claims ADD COLUMN operation_kind TEXT")
            if "operation_started_at" not in columns:
                conn.execute("ALTER TABLE bundle_claims ADD COLUMN operation_started_at TEXT")
            if "authorized_token_fingerprint" not in columns:
                conn.execute(
                    "ALTER TABLE bundle_claims ADD COLUMN authorized_token_fingerprint TEXT"
                )
                conn.execute(
                    "UPDATE bundle_claims SET authorized_token_fingerprint = ("
                    "SELECT s.token_fingerprint FROM play_subscriptions s "
                    "WHERE s.bundle_id = bundle_claims.bundle_id "
                    "ORDER BY s.created_at ASC LIMIT 1)"
                )
            subscription_columns = {
                row[1] for row in conn.execute("PRAGMA table_info(play_subscriptions)").fetchall()
            }
            if "matrix_suspended" not in subscription_columns:
                conn.execute("ALTER TABLE play_subscriptions ADD COLUMN matrix_suspended INTEGER")
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def _row_to_entitlement(row: sqlite3.Row) -> SyncEntitlement:
        return SyncEntitlement(
            entitlement_id=row["entitlement_id"],
            obfuscated_account_id=row["obfuscated_account_id"],
            auth_secret_hash=row["auth_secret_hash"],
            created_at=_parse(row["created_at"]),
            disabled_at=_parse(row["disabled_at"]),
        )

    @staticmethod
    def _row_to_subscription(row: sqlite3.Row) -> StoredSubscription:
        return StoredSubscription(
            entitlement_id=row["entitlement_id"],
            token_fingerprint=row["token_fingerprint"],
            encrypted_purchase_token=bytes(row["encrypted_purchase_token"]),
            encryption_key_id=row["encryption_key_id"],
            package_name=row["package_name"],
            product_id=row["product_id"],
            base_plan_id=row["base_plan_id"],
            latest_order_id=row["latest_order_id"],
            google_state=GoogleSubscriptionState(row["google_state"]),
            entitlement_state=EntitlementState(row["entitlement_state"]),
            start_time=_parse(row["start_time"]),
            current_period_end=_parse(row["current_period_end"]),
            grace_deadline=_parse(row["grace_deadline"]),
            acknowledgement_state=AcknowledgementState(row["acknowledgement_state"]),
            acknowledged_at=_parse(row["acknowledged_at"]),
            linked_token_fingerprint=row["linked_token_fingerprint"],
            replaced_by_token_fingerprint=row["replaced_by_token_fingerprint"],
            out_of_app_expired_token_fingerprint=row["out_of_app_expired_token_fingerprint"],
            binding_verified=bool(row["binding_verified"]),
            bundle_id=row["bundle_id"],
            is_current=bool(row["is_current"]),
            retired_at=_parse(row["retired_at"]),
            suspended_at=_parse(row["suspended_at"]),
            unsuspended_at=_parse(row["unsuspended_at"]),
            matrix_suspended=(
                bool(row["matrix_suspended"]) if row["matrix_suspended"] is not None else None
            ),
            last_verified_at=_parse(row["last_verified_at"]),
            next_reconciliation_at=_parse(row["next_reconciliation_at"]),
            last_error=row["last_error"],
            subscription_id=row["subscription_id"],
            created_at=_parse(row["created_at"]),
            updated_at=_parse(row["updated_at"]),
        )

    @staticmethod
    def _row_to_subscription_event(row: sqlite3.Row) -> SubscriptionEvent:
        return SubscriptionEvent(
            event_id=row["event_id"],
            subscription_id=row["subscription_id"],
            entitlement_id=row["entitlement_id"],
            token_fingerprint=row["token_fingerprint"],
            event_type=SubscriptionEventType(row["event_type"]),
            from_google_state=(
                GoogleSubscriptionState(row["from_google_state"])
                if row["from_google_state"]
                else None
            ),
            to_google_state=GoogleSubscriptionState(row["to_google_state"]),
            from_entitlement_state=(
                EntitlementState(row["from_entitlement_state"])
                if row["from_entitlement_state"]
                else None
            ),
            to_entitlement_state=EntitlementState(row["to_entitlement_state"]),
            from_acknowledgement_state=(
                AcknowledgementState(row["from_acknowledgement_state"])
                if row["from_acknowledgement_state"]
                else None
            ),
            to_acknowledgement_state=AcknowledgementState(row["to_acknowledgement_state"]),
            from_period_end=_parse(row["from_period_end"]),
            to_period_end=_parse(row["to_period_end"]),
            created_at=_parse(row["created_at"]),
        )

    @staticmethod
    def _row_to_purchase_intent(row: sqlite3.Row) -> PurchaseIntent:
        return PurchaseIntent(
            intent_id=row["intent_id"],
            entitlement_id=row["entitlement_id"],
            intent_secret_hash=row["intent_secret_hash"],
            product_id=row["product_id"],
            base_plan_id=row["base_plan_id"],
            obfuscated_account_id=row["obfuscated_account_id"],
            expires_at=_parse(row["expires_at"]),
            expected_request_hash=row["expected_request_hash"],
            consumed_token_fingerprint=row["consumed_token_fingerprint"],
            integrity_token_fingerprint=row["integrity_token_fingerprint"],
            consumed_at=_parse(row["consumed_at"]),
            created_at=_parse(row["created_at"]),
        )

    @staticmethod
    def _row_to_bundle_claim(row: sqlite3.Row) -> BundleClaim:
        encrypted = row["encrypted_bundle"]
        return BundleClaim(
            bundle_id=row["bundle_id"],
            subscription_id=row["subscription_id"],
            claim_secret_hash=row["claim_secret_hash"],
            authorized_token_fingerprint=row["authorized_token_fingerprint"],
            encrypted_bundle=bytes(encrypted) if encrypted is not None else None,
            encryption_key_id=row["encryption_key_id"],
            expires_at=_parse(row["expires_at"]),
            first_delivered_at=_parse(row["first_delivered_at"]),
            confirmed_at=_parse(row["confirmed_at"]),
            destroyed_at=_parse(row["destroyed_at"]),
            abandoned_at=_parse(row["abandoned_at"]),
            created_at=_parse(row["created_at"]),
        )

    def _create_entitlement_sync(
        self,
        entitlement_id: str,
        obfuscated_account_id: str,
        auth_secret_hash: str,
        now: datetime,
    ) -> SyncEntitlement:
        conn = self._connect()
        try:
            try:
                conn.execute(
                    "INSERT INTO sync_entitlements ("
                    "entitlement_id, obfuscated_account_id, auth_secret_hash, created_at"
                    ") VALUES (?, ?, ?, ?)",
                    (
                        entitlement_id,
                        obfuscated_account_id,
                        auth_secret_hash,
                        _iso(now),
                    ),
                )
                conn.commit()
            except sqlite3.IntegrityError as exc:
                raise PurchaseTokenConflictException(
                    "Entitlement identity or obfuscated account ID is already registered"
                ) from exc
            row = conn.execute(
                "SELECT * FROM sync_entitlements WHERE entitlement_id = ?",
                (entitlement_id,),
            ).fetchone()
            return self._row_to_entitlement(row)
        finally:
            conn.close()

    async def create_entitlement(
        self,
        *,
        entitlement_id: str,
        obfuscated_account_id: str,
        auth_secret_hash: str,
        now: datetime,
    ) -> SyncEntitlement:
        """Create the stable identity used for Play purchase attribution."""
        return await asyncio.to_thread(
            self._create_entitlement_sync,
            entitlement_id,
            obfuscated_account_id,
            auth_secret_hash,
            now,
        )

    def _consume_entitlement_issuance_quota_sync(
        self,
        client_key_hash: str,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT window_started_at, request_count "
                "FROM entitlement_issuance_limits WHERE client_key_hash = ?",
                (client_key_hash,),
            ).fetchone()
            window_started_at = _parse(row["window_started_at"]) if row else None
            if window_started_at is None or now >= window_started_at + window:
                conn.execute(
                    "INSERT INTO entitlement_issuance_limits ("
                    "client_key_hash, window_started_at, request_count"
                    ") VALUES (?, ?, 1) ON CONFLICT(client_key_hash) DO UPDATE SET "
                    "window_started_at = excluded.window_started_at, request_count = 1",
                    (client_key_hash, _iso(now)),
                )
            elif row["request_count"] >= max_requests:
                conn.rollback()
                return max(
                    1,
                    math.ceil((window_started_at + window - now).total_seconds()),
                )
            else:
                conn.execute(
                    "UPDATE entitlement_issuance_limits SET request_count = request_count + 1 "
                    "WHERE client_key_hash = ?",
                    (client_key_hash,),
                )
            conn.execute(
                "DELETE FROM entitlement_issuance_limits "
                "WHERE client_key_hash <> ? AND window_started_at <= ?",
                (client_key_hash, _iso(now - window)),
            )
            conn.commit()
            return None
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def consume_entitlement_issuance_quota(
        self,
        client_key_hash: str,
        *,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        """Consume one durable anonymous-issuance slot or return retry seconds."""
        return await asyncio.to_thread(
            self._consume_entitlement_issuance_quota_sync,
            client_key_hash,
            now,
            window,
            max_requests,
        )

    def _get_entitlement_sync(self, entitlement_id: str) -> SyncEntitlement | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM sync_entitlements WHERE entitlement_id = ?",
                (entitlement_id,),
            ).fetchone()
            return self._row_to_entitlement(row) if row else None
        finally:
            conn.close()

    async def get_entitlement(self, entitlement_id: str) -> SyncEntitlement | None:
        """Fetch a stable entitlement identity by its opaque ID."""
        return await asyncio.to_thread(self._get_entitlement_sync, entitlement_id)

    def _consume_subscription_attempt_quota_sync(
        self,
        entitlement_id: str,
        operation_kind: str,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT window_started_at, request_count "
                "FROM subscription_attempt_limits "
                "WHERE entitlement_id = ? AND operation_kind = ?",
                (entitlement_id, operation_kind),
            ).fetchone()
            window_started_at = _parse(row["window_started_at"]) if row else None
            retry_after = None
            if window_started_at is None or now >= window_started_at + window:
                conn.execute(
                    "INSERT INTO subscription_attempt_limits ("
                    "entitlement_id, operation_kind, window_started_at, request_count"
                    ") VALUES (?, ?, ?, 1) "
                    "ON CONFLICT(entitlement_id, operation_kind) DO UPDATE SET "
                    "window_started_at = excluded.window_started_at, request_count = 1",
                    (entitlement_id, operation_kind, _iso(now)),
                )
            elif row["request_count"] >= max_requests:
                retry_after = max(
                    1,
                    math.ceil((window_started_at + window - now).total_seconds()),
                )
            else:
                conn.execute(
                    "UPDATE subscription_attempt_limits SET request_count = request_count + 1 "
                    "WHERE entitlement_id = ? AND operation_kind = ?",
                    (entitlement_id, operation_kind),
                )
            conn.execute(
                "DELETE FROM subscription_attempt_limits "
                "WHERE operation_kind = ? AND entitlement_id <> ? "
                "AND window_started_at <= ?",
                (operation_kind, entitlement_id, _iso(now - window)),
            )
            conn.commit()
            return retry_after
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def consume_subscription_attempt_quota(
        self,
        entitlement_id: str,
        operation_kind: str,
        *,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        """Consume one cheap durable slot before expensive subscription work."""
        return await asyncio.to_thread(
            self._consume_subscription_attempt_quota_sync,
            entitlement_id,
            operation_kind,
            now,
            window,
            max_requests,
        )

    def _consume_purchase_intent_issuance_quota_sync(
        self,
        entitlement_id: str,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            cutoff = _iso(now)
            conn.execute(
                "DELETE FROM play_integrity_replays WHERE intent_id IN ("
                "SELECT intent_id FROM purchase_intents WHERE expires_at <= ?)",
                (cutoff,),
            )
            conn.execute(
                "DELETE FROM purchase_intents WHERE expires_at <= ?",
                (cutoff,),
            )
            row = conn.execute(
                "SELECT window_started_at, request_count "
                "FROM purchase_intent_issuance_limits WHERE entitlement_id = ?",
                (entitlement_id,),
            ).fetchone()
            window_started_at = _parse(row["window_started_at"]) if row else None
            retry_after = None
            if window_started_at is None or now >= window_started_at + window:
                conn.execute(
                    "INSERT INTO purchase_intent_issuance_limits ("
                    "entitlement_id, window_started_at, request_count"
                    ") VALUES (?, ?, 1) ON CONFLICT(entitlement_id) DO UPDATE SET "
                    "window_started_at = excluded.window_started_at, request_count = 1",
                    (entitlement_id, cutoff),
                )
            elif row["request_count"] >= max_requests:
                retry_after = max(
                    1,
                    math.ceil((window_started_at + window - now).total_seconds()),
                )
            else:
                conn.execute(
                    "UPDATE purchase_intent_issuance_limits "
                    "SET request_count = request_count + 1 WHERE entitlement_id = ?",
                    (entitlement_id,),
                )
            conn.execute(
                "DELETE FROM purchase_intent_issuance_limits "
                "WHERE entitlement_id <> ? AND window_started_at <= ?",
                (entitlement_id, _iso(now - window)),
            )
            conn.commit()
            return retry_after
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def consume_purchase_intent_issuance_quota(
        self,
        entitlement_id: str,
        *,
        now: datetime,
        window: timedelta,
        max_requests: int,
    ) -> int | None:
        """Consume one durable intent-issuance slot and prune expired state."""
        return await asyncio.to_thread(
            self._consume_purchase_intent_issuance_quota_sync,
            entitlement_id,
            now,
            window,
            max_requests,
        )

    def _create_purchase_intent_sync(
        self,
        *,
        intent_id: str,
        entitlement_id: str,
        intent_secret_hash: str,
        product_id: str,
        base_plan_id: str,
        obfuscated_account_id: str,
        expires_at: datetime,
        now: datetime,
    ) -> PurchaseIntent:
        conn = self._connect()
        try:
            conn.execute(
                "INSERT INTO purchase_intents ("
                "intent_id, entitlement_id, intent_secret_hash, product_id, "
                "base_plan_id, obfuscated_account_id, expires_at, created_at"
                ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    intent_id,
                    entitlement_id,
                    intent_secret_hash,
                    product_id,
                    base_plan_id,
                    obfuscated_account_id,
                    _iso(expires_at),
                    _iso(now),
                ),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM purchase_intents WHERE intent_id = ?", (intent_id,)
            ).fetchone()
            return self._row_to_purchase_intent(row)
        except sqlite3.IntegrityError as exc:
            raise PurchaseTokenConflictException(
                "Purchase intent ID is already registered"
            ) from exc
        finally:
            conn.close()

    async def create_purchase_intent(
        self,
        *,
        intent_id: str,
        entitlement_id: str,
        intent_secret_hash: str,
        product_id: str,
        base_plan_id: str,
        obfuscated_account_id: str,
        expires_at: datetime,
        now: datetime,
    ) -> PurchaseIntent:
        """Persist an unconsumed, short-lived Billing authorization."""
        return await asyncio.to_thread(
            self._create_purchase_intent_sync,
            intent_id=intent_id,
            entitlement_id=entitlement_id,
            intent_secret_hash=intent_secret_hash,
            product_id=product_id,
            base_plan_id=base_plan_id,
            obfuscated_account_id=obfuscated_account_id,
            expires_at=expires_at,
            now=now,
        )

    def _get_purchase_intent_sync(self, intent_id: str) -> PurchaseIntent | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM purchase_intents WHERE intent_id = ?", (intent_id,)
            ).fetchone()
            return self._row_to_purchase_intent(row) if row else None
        finally:
            conn.close()

    async def get_purchase_intent(self, intent_id: str) -> PurchaseIntent | None:
        """Fetch a purchase intent without exposing its raw one-time secret."""
        return await asyncio.to_thread(self._get_purchase_intent_sync, intent_id)

    def _consume_purchase_intent_sync(
        self,
        *,
        intent_id: str,
        entitlement_id: str,
        expected_request_hash: str,
        token_fingerprint: str,
        integrity_token_fingerprint: str,
        now: datetime,
    ) -> PurchaseIntent:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT * FROM purchase_intents WHERE intent_id = ? AND entitlement_id = ?",
                (intent_id, entitlement_id),
            ).fetchone()
            if row is None:
                raise PurchaseIntentNotFoundException("Unknown purchase intent")
            intent = self._row_to_purchase_intent(row)
            if now >= intent.expires_at:
                raise PurchaseIntentExpiredException("Purchase intent has expired")

            replay_values = (
                expected_request_hash,
                token_fingerprint,
            )
            stored_values = (
                intent.expected_request_hash,
                intent.consumed_token_fingerprint,
            )
            if intent.consumed_at is not None:
                if replay_values != stored_values:
                    raise PurchaseIntentReplayException(
                        "Purchase intent was already consumed by another request"
                    )
            replay = conn.execute(
                "SELECT intent_id FROM play_integrity_replays "
                "WHERE integrity_token_fingerprint = ?",
                (integrity_token_fingerprint,),
            ).fetchone()
            if replay is not None and replay["intent_id"] != intent_id:
                raise PurchaseIntentReplayException(
                    "Play Integrity token was already used by another intent"
                )
            if replay is None:
                conn.execute(
                    "INSERT INTO play_integrity_replays ("
                    "integrity_token_fingerprint, intent_id, first_seen_at"
                    ") VALUES (?, ?, ?)",
                    (integrity_token_fingerprint, intent_id, _iso(now)),
                )

            conn.execute(
                "UPDATE purchase_intents SET expected_request_hash = ?, "
                "consumed_token_fingerprint = ?, integrity_token_fingerprint = ?, "
                "consumed_at = ? WHERE intent_id = ?",
                (
                    expected_request_hash,
                    token_fingerprint,
                    integrity_token_fingerprint,
                    (_iso(now) if intent.consumed_at is None else _iso(intent.consumed_at)),
                    intent_id,
                ),
            )
            conn.commit()
            updated = conn.execute(
                "SELECT * FROM purchase_intents WHERE intent_id = ?", (intent_id,)
            ).fetchone()
            return self._row_to_purchase_intent(updated)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def consume_purchase_intent(
        self,
        *,
        intent_id: str,
        entitlement_id: str,
        expected_request_hash: str,
        token_fingerprint: str,
        integrity_token_fingerprint: str,
        now: datetime,
    ) -> PurchaseIntent:
        """Consume once, permitting only byte-for-byte idempotent retries."""
        return await asyncio.to_thread(
            self._consume_purchase_intent_sync,
            intent_id=intent_id,
            entitlement_id=entitlement_id,
            expected_request_hash=expected_request_hash,
            token_fingerprint=token_fingerprint,
            integrity_token_fingerprint=integrity_token_fingerprint,
            now=now,
        )

    @staticmethod
    def _subscription_transition_events(
        existing: sqlite3.Row | None,
        snapshot: VerifiedSubscription,
    ) -> tuple[SubscriptionEventType, ...]:
        if existing is None:
            return (SubscriptionEventType.VERIFIED,)

        events: list[SubscriptionEventType] = []
        previous_acknowledgement = AcknowledgementState(existing["acknowledgement_state"])
        previous_entitlement = EntitlementState(existing["entitlement_state"])
        previous_period_end = _parse(existing["current_period_end"])
        if (
            previous_acknowledgement is AcknowledgementState.PENDING
            and snapshot.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED
        ):
            events.append(SubscriptionEventType.ACKNOWLEDGED)
        if (
            previous_period_end is not None
            and snapshot.current_period_end is not None
            and snapshot.current_period_end > previous_period_end
        ):
            events.append(SubscriptionEventType.RENEWED)
        if (
            snapshot.entitlement_state is EntitlementState.GRACE
            and previous_entitlement is not EntitlementState.GRACE
        ):
            events.append(SubscriptionEventType.GRACE_ENTERED)
        if (
            snapshot.entitlement_state is EntitlementState.SUSPENDED
            and previous_entitlement is not EntitlementState.SUSPENDED
        ):
            events.append(SubscriptionEventType.SUSPENDED)
        if snapshot.entitlement_state in {
            EntitlementState.ACTIVE,
            EntitlementState.CANCELED_ACTIVE,
        } and previous_entitlement in {
            EntitlementState.PENDING,
            EntitlementState.EXPIRED,
            EntitlementState.GRACE,
            EntitlementState.SUSPENDED,
        }:
            events.append(SubscriptionEventType.RECOVERED)
        if (
            snapshot.entitlement_state is EntitlementState.EXPIRED
            and previous_entitlement is not EntitlementState.EXPIRED
        ):
            events.append(SubscriptionEventType.EXPIRED)
        return tuple(events)

    @staticmethod
    def _record_subscription_event_sync(
        conn: sqlite3.Connection,
        *,
        subscription_id: str,
        snapshot: VerifiedSubscription,
        existing: sqlite3.Row | None,
        event_type: SubscriptionEventType,
        now: datetime,
    ) -> None:
        conn.execute(
            "INSERT INTO subscription_events ("
            "subscription_id, entitlement_id, token_fingerprint, event_type, "
            "from_google_state, to_google_state, from_entitlement_state, "
            "to_entitlement_state, from_acknowledgement_state, "
            "to_acknowledgement_state, from_period_end, to_period_end, created_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                subscription_id,
                snapshot.entitlement_id,
                snapshot.token_fingerprint,
                event_type.value,
                existing["google_state"] if existing is not None else None,
                snapshot.google_state.value,
                existing["entitlement_state"] if existing is not None else None,
                snapshot.entitlement_state.value,
                existing["acknowledgement_state"] if existing is not None else None,
                snapshot.acknowledgement_state.value,
                existing["current_period_end"] if existing is not None else None,
                _iso(snapshot.current_period_end),
                _iso(now),
            ),
        )

    def _store_verified_subscription_sync(
        self,
        snapshot: VerifiedSubscription,
        now: datetime,
    ) -> StoredSubscription:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            existing = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (snapshot.token_fingerprint,),
            ).fetchone()
            if existing and existing["entitlement_id"] != snapshot.entitlement_id:
                raise PurchaseTokenConflictException(
                    "Purchase token is already bound to another entitlement"
                )
            existing_last_verified_at = (
                _parse(existing["last_verified_at"]) if existing is not None else None
            )
            if (
                existing_last_verified_at is not None
                and snapshot.last_verified_at < existing_last_verified_at
            ):
                conn.rollback()
                return self._row_to_subscription(existing)

            predecessor_fingerprint = (
                snapshot.linked_token_fingerprint or snapshot.out_of_app_expired_token_fingerprint
            )
            predecessor = None
            current = None
            if predecessor_fingerprint:
                predecessor = conn.execute(
                    "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                    (predecessor_fingerprint,),
                ).fetchone()
                if predecessor is None or predecessor["entitlement_id"] != snapshot.entitlement_id:
                    raise SubscriptionLineageException(
                        "Linked purchase token is unknown or belongs to another entitlement"
                    )

            if existing is None:
                current = conn.execute(
                    "SELECT * FROM play_subscriptions WHERE entitlement_id = ? AND is_current = 1",
                    (snapshot.entitlement_id,),
                ).fetchone()
                if current is not None and predecessor_fingerprint is None:
                    raise SubscriptionLineageException(
                        "A new token must identify the current token it replaces"
                    )
                if current is not None and predecessor_fingerprint != current["token_fingerprint"]:
                    raise SubscriptionLineageException(
                        "Replacement token does not descend from the current token"
                    )
                if (
                    current is not None
                    and snapshot.entitlement_state not in ACCESS_ENTITLEMENT_STATES
                ):
                    raise GooglePlayVerificationException(
                        "A replacement subscription token does not grant SYNC access"
                    )
                inherited_bundle_id = (
                    snapshot.bundle_id
                    if snapshot.bundle_id is not None
                    else current["bundle_id"] if current is not None else None
                )
                conn.execute(
                    "UPDATE play_subscriptions SET is_current = 0, retired_at = ?, "
                    "replaced_by_token_fingerprint = ?, updated_at = ? "
                    "WHERE entitlement_id = ? AND is_current = 1",
                    (
                        _iso(now),
                        snapshot.token_fingerprint,
                        _iso(now),
                        snapshot.entitlement_id,
                    ),
                )
                subscription_id = str(uuid.uuid4())
                created_at = now
            else:
                subscription_id = existing["subscription_id"]
                created_at = _parse(existing["created_at"])
                inherited_bundle_id = snapshot.bundle_id or existing["bundle_id"]

            matrix_suspended = (
                existing["matrix_suspended"]
                if existing is not None
                else current["matrix_suspended"] if current is not None else None
            )

            transition_source = existing if existing is not None else current
            for event_type in self._subscription_transition_events(transition_source, snapshot):
                self._record_subscription_event_sync(
                    conn,
                    subscription_id=subscription_id,
                    snapshot=snapshot,
                    existing=transition_source,
                    event_type=event_type,
                    now=now,
                )

            values = (
                subscription_id,
                snapshot.entitlement_id,
                snapshot.token_fingerprint,
                snapshot.encrypted_purchase_token,
                snapshot.encryption_key_id,
                snapshot.package_name,
                snapshot.product_id,
                snapshot.base_plan_id,
                snapshot.latest_order_id,
                snapshot.google_state.value,
                snapshot.entitlement_state.value,
                _iso(snapshot.start_time),
                _iso(snapshot.current_period_end),
                _iso(snapshot.grace_deadline),
                snapshot.acknowledgement_state.value,
                _iso(snapshot.acknowledged_at),
                snapshot.linked_token_fingerprint,
                snapshot.out_of_app_expired_token_fingerprint,
                int(snapshot.binding_verified),
                inherited_bundle_id,
                _iso(snapshot.suspended_at),
                _iso(snapshot.unsuspended_at),
                matrix_suspended,
                _iso(snapshot.last_verified_at),
                _iso(snapshot.next_reconciliation_at),
                snapshot.last_error,
                _iso(created_at),
                _iso(now),
            )
            conn.execute(
                "INSERT INTO play_subscriptions ("
                "subscription_id, entitlement_id, token_fingerprint, "
                "encrypted_purchase_token, encryption_key_id, package_name, product_id, "
                "base_plan_id, latest_order_id, google_state, entitlement_state, "
                "start_time, current_period_end, grace_deadline, acknowledgement_state, "
                "acknowledged_at, linked_token_fingerprint, "
                "out_of_app_expired_token_fingerprint, binding_verified, bundle_id, "
                "suspended_at, unsuspended_at, matrix_suspended, last_verified_at, "
                "next_reconciliation_at, "
                "last_error, created_at, updated_at"
                ") VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) "
                "ON CONFLICT(token_fingerprint) DO UPDATE SET "
                "encrypted_purchase_token=excluded.encrypted_purchase_token, "
                "encryption_key_id=excluded.encryption_key_id, "
                "package_name=excluded.package_name, product_id=excluded.product_id, "
                "base_plan_id=excluded.base_plan_id, latest_order_id=excluded.latest_order_id, "
                "google_state=excluded.google_state, "
                "entitlement_state=excluded.entitlement_state, start_time=excluded.start_time, "
                "current_period_end=excluded.current_period_end, "
                "grace_deadline=excluded.grace_deadline, "
                "acknowledgement_state=excluded.acknowledgement_state, "
                "acknowledged_at=COALESCE(play_subscriptions.acknowledged_at, "
                "excluded.acknowledged_at), "
                "out_of_app_expired_token_fingerprint="
                "excluded.out_of_app_expired_token_fingerprint, "
                "binding_verified=excluded.binding_verified, bundle_id=excluded.bundle_id, "
                "suspended_at=excluded.suspended_at, unsuspended_at=excluded.unsuspended_at, "
                "matrix_suspended=excluded.matrix_suspended, "
                "last_verified_at=excluded.last_verified_at, "
                "next_reconciliation_at=excluded.next_reconciliation_at, "
                "last_error=excluded.last_error, updated_at=excluded.updated_at",
                values,
            )
            if existing is None and inherited_bundle_id is not None:
                conn.execute(
                    "UPDATE bundle_claims SET subscription_id = ? WHERE bundle_id = ?",
                    (subscription_id, inherited_bundle_id),
                )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (snapshot.token_fingerprint,),
            ).fetchone()
            return self._row_to_subscription(row)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def store_verified_subscription(
        self,
        snapshot: VerifiedSubscription,
        *,
        now: datetime,
    ) -> StoredSubscription:
        """Atomically bind a verified token and retire its predecessor."""
        return await asyncio.to_thread(self._store_verified_subscription_sync, snapshot, now)

    def _get_subscription_by_token_sync(self, token_fingerprint: str) -> StoredSubscription | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (token_fingerprint,),
            ).fetchone()
            return self._row_to_subscription(row) if row else None
        finally:
            conn.close()

    async def get_subscription_by_token(self, token_fingerprint: str) -> StoredSubscription | None:
        """Resolve an RTDN or client token fingerprint to its stored binding."""
        return await asyncio.to_thread(self._get_subscription_by_token_sync, token_fingerprint)

    def _list_subscription_events_sync(
        self,
        token_fingerprint: str,
    ) -> list[SubscriptionEvent]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM subscription_events WHERE token_fingerprint = ? "
                "ORDER BY event_id ASC",
                (token_fingerprint,),
            ).fetchall()
            return [self._row_to_subscription_event(row) for row in rows]
        finally:
            conn.close()

    async def list_subscription_events(
        self,
        token_fingerprint: str,
    ) -> list[SubscriptionEvent]:
        """Return the immutable audit history for one token fingerprint."""
        return await asyncio.to_thread(
            self._list_subscription_events_sync,
            token_fingerprint,
        )

    def _get_current_subscription_sync(self, entitlement_id: str) -> StoredSubscription | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE entitlement_id = ? AND is_current = 1",
                (entitlement_id,),
            ).fetchone()
            return self._row_to_subscription(row) if row else None
        finally:
            conn.close()

    async def get_current_subscription(self, entitlement_id: str) -> StoredSubscription | None:
        """Return the only token currently authoritative for an entitlement."""
        return await asyncio.to_thread(self._get_current_subscription_sync, entitlement_id)

    def _list_due_reconciliation_sync(self, now: datetime, limit: int) -> list[StoredSubscription]:
        conn = self._connect()
        try:
            access_states = tuple(state.value for state in ACCESS_ENTITLEMENT_STATES)
            now_iso = _iso(now)
            rows = conn.execute(
                "WITH current_subscriptions AS (SELECT *, CASE WHEN "
                "entitlement_state IN (?,?,?) AND "
                "(current_period_end IS NULL OR current_period_end > ?) "
                "THEN 0 ELSE 1 END AS desired_suspended "
                "FROM play_subscriptions WHERE is_current = 1) "
                "SELECT * FROM current_subscriptions WHERE next_reconciliation_at <= ? OR ("
                "bundle_id IS NOT NULL AND last_error IS NULL AND ("
                "matrix_suspended IS NULL OR matrix_suspended != desired_suspended)) "
                "ORDER BY CASE WHEN bundle_id IS NOT NULL AND last_error IS NULL AND ("
                "matrix_suspended IS NULL OR matrix_suspended != desired_suspended) "
                "THEN 0 ELSE 1 END, "
                "next_reconciliation_at ASC LIMIT ?",
                (
                    *access_states,
                    now_iso,
                    now_iso,
                    max(1, limit),
                ),
            ).fetchall()
            return [self._row_to_subscription(row) for row in rows]
        finally:
            conn.close()

    async def list_due_reconciliation(
        self, now: datetime, *, limit: int
    ) -> list[StoredSubscription]:
        """List current subscriptions due for Google refresh or Matrix enforcement."""
        return await asyncio.to_thread(self._list_due_reconciliation_sync, now, limit)

    def _reserve_paid_bundle_provisioning_sync(
        self,
        entitlement_id: str,
        token_fingerprint: str,
        operation_token: str,
        now: datetime,
        stale_before: datetime,
    ) -> PaidProvisioningReservation:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            subscription = conn.execute(
                "SELECT bundle_id FROM play_subscriptions "
                "WHERE entitlement_id = ? AND token_fingerprint = ? AND is_current = 1",
                (entitlement_id, token_fingerprint),
            ).fetchone()
            if subscription is None or subscription["bundle_id"] is not None:
                conn.rollback()
                return PaidProvisioningReservation(acquired=False)
            existing = conn.execute(
                "SELECT operation_token, started_at FROM paid_bundle_provisioning "
                "WHERE entitlement_id = ?",
                (entitlement_id,),
            ).fetchone()
            if existing is not None and _parse(existing["started_at"]) > stale_before:
                conn.rollback()
                return PaidProvisioningReservation(
                    acquired=existing["operation_token"] == operation_token
                )
            took_over_stale_owner = (
                existing is not None and existing["operation_token"] != operation_token
            )
            conn.execute(
                "INSERT INTO paid_bundle_provisioning ("
                "entitlement_id, token_fingerprint, operation_token, started_at"
                ") VALUES (?, ?, ?, ?) ON CONFLICT(entitlement_id) DO UPDATE SET "
                "token_fingerprint = excluded.token_fingerprint, "
                "operation_token = excluded.operation_token, started_at = excluded.started_at",
                (entitlement_id, token_fingerprint, operation_token, _iso(now)),
            )
            conn.commit()
            return PaidProvisioningReservation(
                acquired=True,
                took_over_stale_owner=took_over_stale_owner,
            )
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def reserve_paid_bundle_provisioning(
        self,
        entitlement_id: str,
        *,
        token_fingerprint: str,
        operation_token: str,
        now: datetime,
        stale_before: datetime,
    ) -> PaidProvisioningReservation:
        """Take the cross-process reservation and report stale-owner takeover."""
        return await asyncio.to_thread(
            self._reserve_paid_bundle_provisioning_sync,
            entitlement_id,
            token_fingerprint,
            operation_token,
            now,
            stale_before,
        )

    def _release_paid_bundle_provisioning_sync(
        self,
        entitlement_id: str,
        operation_token: str,
    ) -> bool:
        conn = self._connect()
        try:
            cursor = conn.execute(
                "DELETE FROM paid_bundle_provisioning "
                "WHERE entitlement_id = ? AND operation_token = ?",
                (entitlement_id, operation_token),
            )
            conn.commit()
            return cursor.rowcount == 1
        finally:
            conn.close()

    async def release_paid_bundle_provisioning(
        self,
        entitlement_id: str,
        *,
        operation_token: str,
    ) -> bool:
        """Release only the caller's paid-provisioning reservation."""
        return await asyncio.to_thread(
            self._release_paid_bundle_provisioning_sync,
            entitlement_id,
            operation_token,
        )

    def _store_paid_bundle_sync(
        self,
        *,
        token_fingerprint: str,
        provisioning_token: str,
        bundle_id: str,
        username: str,
        user_mxid: str,
        home_server: str,
        server_name: str,
        room_id: str,
        display_name: str | None,
        bundle_fingerprint: str,
        notes: str,
        claim_secret_hash: str,
        encrypted_bundle: bytes,
        encryption_key_id: str,
        expires_at: datetime,
        now: datetime,
    ) -> tuple[ProvisionedUser, BundleClaim]:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            subscription = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ? AND is_current = 1",
                (token_fingerprint,),
            ).fetchone()
            if subscription is None or subscription["bundle_id"] is not None:
                raise BundleClaimConflictException(
                    "Subscription is unknown, retired, or already has a bundle"
                )
            reservation = conn.execute(
                "SELECT operation_token, token_fingerprint "
                "FROM paid_bundle_provisioning WHERE entitlement_id = ?",
                (subscription["entitlement_id"],),
            ).fetchone()
            if (
                reservation is None
                or reservation["operation_token"] != provisioning_token
                or reservation["token_fingerprint"] != token_fingerprint
            ):
                raise BundleClaimConflictException("Paid provisioning reservation was lost")
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
                    PaymentStatus.PAYING.value,
                    bundle_fingerprint,
                    _iso(now),
                    notes,
                ),
            )
            self._record_event_sync(
                conn,
                bundle_id,
                BundleEventType.CREATED,
                f"Provisioned {user_mxid} for verified Google Play subscription",
            )
            conn.execute(
                "INSERT INTO bundle_claims ("
                "bundle_id, subscription_id, claim_secret_hash, "
                "authorized_token_fingerprint, encrypted_bundle, "
                "encryption_key_id, expires_at, created_at"
                ") VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    bundle_id,
                    subscription["subscription_id"],
                    claim_secret_hash,
                    token_fingerprint,
                    encrypted_bundle,
                    encryption_key_id,
                    _iso(expires_at),
                    _iso(now),
                ),
            )
            conn.execute(
                "UPDATE play_subscriptions SET bundle_id = ?, updated_at = ? "
                "WHERE subscription_id = ?",
                (bundle_id, _iso(now), subscription["subscription_id"]),
            )
            conn.execute(
                "DELETE FROM paid_bundle_provisioning "
                "WHERE entitlement_id = ? AND operation_token = ?",
                (subscription["entitlement_id"], provisioning_token),
            )
            conn.commit()
            user_row = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            claim_row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_user(user_row), self._row_to_bundle_claim(claim_row)
        except sqlite3.IntegrityError as exc:
            conn.rollback()
            raise BundleClaimConflictException(
                "Paid bundle could not be attached without violating ownership"
            ) from exc
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def store_paid_bundle(
        self,
        *,
        token_fingerprint: str,
        provisioning_token: str,
        bundle_id: str,
        username: str,
        user_mxid: str,
        home_server: str,
        server_name: str,
        room_id: str,
        display_name: str | None,
        bundle_fingerprint: str,
        notes: str,
        claim_secret_hash: str,
        encrypted_bundle: bytes,
        encryption_key_id: str,
        expires_at: datetime,
        now: datetime,
    ) -> tuple[ProvisionedUser, BundleClaim]:
        """Atomically store the account record, escrow, and subscription link."""
        return await asyncio.to_thread(
            self._store_paid_bundle_sync,
            token_fingerprint=token_fingerprint,
            provisioning_token=provisioning_token,
            bundle_id=bundle_id,
            username=username,
            user_mxid=user_mxid,
            home_server=home_server,
            server_name=server_name,
            room_id=room_id,
            display_name=display_name,
            bundle_fingerprint=bundle_fingerprint,
            notes=notes,
            claim_secret_hash=claim_secret_hash,
            encrypted_bundle=encrypted_bundle,
            encryption_key_id=encryption_key_id,
            expires_at=expires_at,
            now=now,
        )

    def _get_bundle_claim_for_entitlement_sync(self, entitlement_id: str) -> BundleClaim | None:
        conn = self._connect()
        try:
            row = conn.execute(
                "SELECT c.* FROM bundle_claims c "
                "JOIN play_subscriptions s ON s.subscription_id = c.subscription_id "
                "WHERE s.entitlement_id = ? AND s.is_current = 1",
                (entitlement_id,),
            ).fetchone()
            return self._row_to_bundle_claim(row) if row else None
        finally:
            conn.close()

    async def get_bundle_claim_for_entitlement(self, entitlement_id: str) -> BundleClaim | None:
        """Return the current subscription's escrow claim, if provisioned."""
        return await asyncio.to_thread(
            self._get_bundle_claim_for_entitlement_sync,
            entitlement_id,
        )

    def _get_returnable_paid_delivery_state_sync(
        self,
        entitlement_id: str,
    ) -> tuple[StoredSubscription | None, BundleClaim | None, ProvisionedUser | None]:
        conn = self._connect()
        try:
            conn.execute("BEGIN")
            subscription_row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE entitlement_id = ? AND is_current = 1",
                (entitlement_id,),
            ).fetchone()
            claim_row = conn.execute(
                "SELECT c.* FROM bundle_claims c "
                "JOIN play_subscriptions s ON s.subscription_id = c.subscription_id "
                "WHERE s.entitlement_id = ? AND s.is_current = 1",
                (entitlement_id,),
            ).fetchone()
            user_row = (
                conn.execute(
                    "SELECT * FROM provisioned_users WHERE bundle_id = ?",
                    (claim_row["bundle_id"],),
                ).fetchone()
                if claim_row is not None
                else None
            )
            conn.commit()
            return (
                self._row_to_subscription(subscription_row) if subscription_row else None,
                self._row_to_bundle_claim(claim_row) if claim_row else None,
                self._row_to_user(user_row) if user_row else None,
            )
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def get_returnable_paid_delivery_state(
        self,
        entitlement_id: str,
    ) -> tuple[StoredSubscription | None, BundleClaim | None, ProvisionedUser | None]:
        """Read subscription, claim, and account from one SQLite snapshot."""
        return await asyncio.to_thread(
            self._get_returnable_paid_delivery_state_sync,
            entitlement_id,
        )

    def _list_expired_bundle_claims_sync(
        self,
        now: datetime,
        stale_before: datetime,
        limit: int,
    ) -> list[BundleClaim]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM bundle_claims WHERE destroyed_at IS NULL "
                "AND expires_at <= ? AND COALESCE(next_reap_at, expires_at) <= ? "
                "AND (operation_token IS NULL OR operation_started_at <= ?) "
                "ORDER BY COALESCE(next_reap_at, expires_at) ASC LIMIT ?",
                (_iso(now), _iso(now), _iso(stale_before), max(1, limit)),
            ).fetchall()
            return [self._row_to_bundle_claim(row) for row in rows]
        finally:
            conn.close()

    async def list_expired_bundle_claims(
        self,
        now: datetime,
        *,
        stale_before: datetime,
        limit: int,
    ) -> list[BundleClaim]:
        """List abandoned escrow claims whose bootstrap access must be revoked."""
        return await asyncio.to_thread(
            self._list_expired_bundle_claims_sync,
            now,
            stale_before,
            limit,
        )

    def _reserve_bundle_claim_operation_sync(
        self,
        bundle_id: str,
        *,
        operation_token: str,
        operation_kind: str,
        now: datetime,
        stale_before: datetime,
        require_expired: bool,
        require_unexpired: bool,
    ) -> BundleClaim | None:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?",
                (bundle_id,),
            ).fetchone()
            if row is None:
                raise BundleClaimConflictException("Unknown bundle claim")
            if row["destroyed_at"] is not None or row["confirmed_at"] is not None:
                conn.rollback()
                return None
            if require_expired and _parse(row["expires_at"]) > now:
                conn.rollback()
                return None
            if require_unexpired and _parse(row["expires_at"]) <= now:
                conn.rollback()
                return None
            cursor = conn.execute(
                "UPDATE bundle_claims SET operation_token = ?, operation_kind = ?, "
                "operation_started_at = ? WHERE bundle_id = ? AND destroyed_at IS NULL "
                "AND confirmed_at IS NULL AND (operation_token IS NULL "
                "OR operation_started_at <= ?)",
                (
                    operation_token,
                    operation_kind,
                    _iso(now),
                    bundle_id,
                    _iso(stale_before),
                ),
            )
            if cursor.rowcount != 1:
                conn.rollback()
                return None
            conn.commit()
            reserved = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?",
                (bundle_id,),
            ).fetchone()
            return self._row_to_bundle_claim(reserved)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def reserve_bundle_rotation(
        self,
        bundle_id: str,
        *,
        operation_token: str,
        now: datetime,
        stale_before: datetime,
    ) -> BundleClaim:
        """Lease an unconfirmed claim while Matrix rotation proof is checked."""
        claim = await asyncio.to_thread(
            self._reserve_bundle_claim_operation_sync,
            bundle_id,
            operation_token=operation_token,
            operation_kind="rotation",
            now=now,
            stale_before=stale_before,
            require_expired=False,
            require_unexpired=True,
        )
        if claim is None:
            raise BundleClaimConflictException("Bundle claim is already being processed")
        return claim

    async def reserve_bundle_reap(
        self,
        bundle_id: str,
        *,
        operation_token: str,
        now: datetime,
        stale_before: datetime,
    ) -> bool:
        """Lease one expired claim before changing its Matrix account."""
        claim = await asyncio.to_thread(
            self._reserve_bundle_claim_operation_sync,
            bundle_id,
            operation_token=operation_token,
            operation_kind="reap",
            now=now,
            stale_before=stale_before,
            require_expired=True,
            require_unexpired=False,
        )
        return claim is not None

    async def reserve_bundle_delivery(
        self,
        bundle_id: str,
        *,
        operation_token: str,
        now: datetime,
        stale_before: datetime,
    ) -> BundleClaim:
        """Lease fresh escrow while one authenticated response is assembled."""
        claim = await asyncio.to_thread(
            self._reserve_bundle_claim_operation_sync,
            bundle_id,
            operation_token=operation_token,
            operation_kind="delivery",
            now=now,
            stale_before=stale_before,
            require_expired=False,
            require_unexpired=True,
        )
        if claim is None:
            raise BundleClaimConflictException(
                "Bundle claim is expired, terminal, or already being processed"
            )
        return claim

    def _release_bundle_claim_operation_sync(
        self,
        bundle_id: str,
        operation_token: str,
    ) -> bool:
        conn = self._connect()
        try:
            cursor = conn.execute(
                "UPDATE bundle_claims SET operation_token = NULL, operation_kind = NULL, "
                "operation_started_at = NULL WHERE bundle_id = ? AND operation_token = ?",
                (bundle_id, operation_token),
            )
            conn.commit()
            return cursor.rowcount == 1
        finally:
            conn.close()

    async def release_bundle_claim_operation(
        self,
        bundle_id: str,
        *,
        operation_token: str,
    ) -> bool:
        """Release only the caller's operation lease."""
        return await asyncio.to_thread(
            self._release_bundle_claim_operation_sync,
            bundle_id,
            operation_token,
        )

    def _reauthorize_pending_bundle_claim_sync(
        self,
        entitlement_id: str,
        token_fingerprint: str,
        claim_secret_hash: str,
    ) -> BundleClaim:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT c.* FROM bundle_claims c "
                "JOIN play_subscriptions s ON s.subscription_id = c.subscription_id "
                "WHERE s.entitlement_id = ? AND s.token_fingerprint = ? AND s.is_current = 1",
                (entitlement_id, token_fingerprint),
            ).fetchone()
            if (
                row is None
                or row["confirmed_at"] is not None
                or row["destroyed_at"] is not None
                or row["encrypted_bundle"] is None
                or row["operation_token"] is not None
                or not row["authorized_token_fingerprint"]
                or row["authorized_token_fingerprint"] == token_fingerprint
            ):
                raise BundleClaimConflictException("Pending bundle claim cannot be reauthorized")
            conn.execute(
                "UPDATE bundle_claims SET claim_secret_hash = ?, "
                "authorized_token_fingerprint = ? WHERE bundle_id = ?",
                (claim_secret_hash, token_fingerprint, row["bundle_id"]),
            )
            conn.commit()
            updated = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?",
                (row["bundle_id"],),
            ).fetchone()
            return self._row_to_bundle_claim(updated)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def reauthorize_pending_bundle_claim(
        self,
        entitlement_id: str,
        *,
        token_fingerprint: str,
        claim_secret_hash: str,
    ) -> BundleClaim:
        """Bind inherited pending escrow to a fully verified replacement secret."""
        return await asyncio.to_thread(
            self._reauthorize_pending_bundle_claim_sync,
            entitlement_id,
            token_fingerprint,
            claim_secret_hash,
        )

    def _complete_bundle_delivery_sync(
        self,
        bundle_id: str,
        operation_token: str,
        now: datetime,
    ) -> BundleClaim:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            cursor = conn.execute(
                "UPDATE bundle_claims SET first_delivered_at = "
                "COALESCE(first_delivered_at, ?), operation_token = NULL, "
                "operation_kind = NULL, operation_started_at = NULL "
                "WHERE bundle_id = ? AND operation_kind = 'delivery' "
                "AND operation_token = ? AND destroyed_at IS NULL "
                "AND confirmed_at IS NULL AND encrypted_bundle IS NOT NULL",
                (_iso(now), bundle_id, operation_token),
            )
            if cursor.rowcount != 1:
                raise BundleClaimConflictException("Bundle delivery lease was lost")
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_bundle_claim(row)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def complete_bundle_delivery(
        self,
        bundle_id: str,
        *,
        operation_token: str,
        now: datetime,
    ) -> BundleClaim:
        """Stamp delivery and release only the caller's escrow lease."""
        return await asyncio.to_thread(
            self._complete_bundle_delivery_sync,
            bundle_id,
            operation_token,
            now,
        )

    def _terminalize_related_state_on_revoke_sync(
        self,
        conn: sqlite3.Connection,
        bundle_id: str,
        revoked_at: datetime,
        reap_operation_token: str | None,
    ) -> None:
        """Destroy paid bootstrap escrow in the bundle revocation transaction."""
        if reap_operation_token is not None:
            cursor = conn.execute(
                "UPDATE bundle_claims SET encrypted_bundle = NULL, "
                "destroyed_at = COALESCE(destroyed_at, ?), "
                "abandoned_at = COALESCE(abandoned_at, ?), operation_token = NULL, "
                "operation_kind = NULL, operation_started_at = NULL "
                "WHERE bundle_id = ? AND operation_kind = 'reap' "
                "AND operation_token = ? AND destroyed_at IS NULL "
                "AND confirmed_at IS NULL",
                (
                    _iso(revoked_at),
                    _iso(revoked_at),
                    bundle_id,
                    reap_operation_token,
                ),
            )
            if cursor.rowcount != 1:
                raise BundleClaimConflictException("Bundle claim reap lease was lost")
            return
        conn.execute(
            "UPDATE bundle_claims SET encrypted_bundle = NULL, "
            "destroyed_at = COALESCE(destroyed_at, ?), operation_token = NULL, "
            "operation_kind = NULL, operation_started_at = NULL WHERE bundle_id = ?",
            (_iso(revoked_at), bundle_id),
        )

    def _abandon_bundle_claim_sync(
        self,
        bundle_id: str,
        now: datetime,
        operation_token: str | None,
    ) -> BundleClaim:
        conn = self._connect()
        try:
            query = (
                "UPDATE bundle_claims SET encrypted_bundle = NULL, "
                "destroyed_at = COALESCE(destroyed_at, ?), "
                "abandoned_at = COALESCE(abandoned_at, ?), operation_token = NULL, "
                "operation_kind = NULL, operation_started_at = NULL WHERE bundle_id = ?"
            )
            parameters = [_iso(now), _iso(now), bundle_id]
            if operation_token is not None:
                query += " AND operation_kind = 'reap' AND operation_token = ?"
                parameters.append(operation_token)
            cursor = conn.execute(query, parameters)
            if cursor.rowcount != 1:
                raise BundleClaimConflictException("Bundle claim reap lease was lost")
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_bundle_claim(row)
        finally:
            conn.close()

    async def abandon_bundle_claim(
        self,
        bundle_id: str,
        *,
        now: datetime,
        operation_token: str | None = None,
    ) -> BundleClaim:
        """Destroy expired escrow without falsely marking rotation confirmed."""
        return await asyncio.to_thread(
            self._abandon_bundle_claim_sync,
            bundle_id,
            now,
            operation_token,
        )

    def _reschedule_bundle_claim_reap_sync(
        self,
        bundle_id: str,
        next_reap_at: datetime,
        operation_token: str,
    ) -> BundleClaim:
        conn = self._connect()
        try:
            cursor = conn.execute(
                "UPDATE bundle_claims SET next_reap_at = ?, operation_token = NULL, "
                "operation_kind = NULL, operation_started_at = NULL "
                "WHERE bundle_id = ? AND operation_kind = 'reap' AND operation_token = ?",
                (_iso(next_reap_at), bundle_id, operation_token),
            )
            if cursor.rowcount != 1:
                raise BundleClaimConflictException("Bundle claim reap lease was lost")
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return self._row_to_bundle_claim(row)
        finally:
            conn.close()

    async def reschedule_bundle_claim_reap(
        self,
        bundle_id: str,
        *,
        next_reap_at: datetime,
        operation_token: str,
    ) -> BundleClaim:
        """Move a failed reaper attempt aside without extending escrow TTL."""
        return await asyncio.to_thread(
            self._reschedule_bundle_claim_reap_sync,
            bundle_id,
            next_reap_at,
            operation_token,
        )

    def _release_abandoned_bundle_claim_sync(self, entitlement_id: str, now: datetime) -> str:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT c.bundle_id, c.confirmed_at, c.destroyed_at, "
                "c.abandoned_at, u.status "
                "FROM bundle_claims c "
                "JOIN play_subscriptions s ON s.subscription_id = c.subscription_id "
                "JOIN provisioned_users u ON u.bundle_id = c.bundle_id "
                "WHERE s.entitlement_id = ? AND s.is_current = 1",
                (entitlement_id,),
            ).fetchone()
            if (
                row is None
                or row["confirmed_at"] is not None
                or row["destroyed_at"] is None
                or row["abandoned_at"] is None
                or BundleStatus(row["status"]) is not BundleStatus.REVOKED
            ):
                raise BundleClaimConflictException("Bundle claim is not abandoned")
            bundle_id = row["bundle_id"]
            conn.execute("DELETE FROM bundle_claims WHERE bundle_id = ?", (bundle_id,))
            conn.execute(
                "UPDATE play_subscriptions SET bundle_id = NULL, updated_at = ? "
                "WHERE entitlement_id = ? AND is_current = 1 AND bundle_id = ?",
                (_iso(now), entitlement_id, bundle_id),
            )
            conn.commit()
            return bundle_id
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def release_abandoned_bundle_claim(self, entitlement_id: str, *, now: datetime) -> str:
        """Detach destroyed unconfirmed escrow so a paid retry can reprovision."""
        return await asyncio.to_thread(
            self._release_abandoned_bundle_claim_sync,
            entitlement_id,
            now,
        )

    def _confirm_paid_bundle_rotation_sync(
        self,
        bundle_id: str,
        now: datetime,
        operation_token: str,
    ) -> tuple[ProvisionedUser, BundleClaim]:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            user = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            claim = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if user is None or claim is None:
                raise BundleClaimConflictException("Unknown paid bundle claim")
            if BundleStatus(user["status"]) is BundleStatus.REVOKED:
                raise BundleClaimConflictException("Revoked bundle cannot be confirmed")
            if claim["operation_kind"] != "rotation" or claim["operation_token"] != operation_token:
                raise BundleClaimConflictException("Bundle rotation lease was lost")

            if claim["destroyed_at"] is None:
                first_login = _parse(user["first_login_at"]) or now
                conn.execute(
                    "UPDATE provisioned_users SET status = ?, rotated_at = ?, "
                    "first_login_at = ? WHERE bundle_id = ?",
                    (
                        BundleStatus.ROTATED.value,
                        _iso(now),
                        _iso(first_login),
                        bundle_id,
                    ),
                )
                self._record_event_sync(
                    conn,
                    bundle_id,
                    BundleEventType.ROTATED,
                    "Server validated Matrix rotation proof",
                )
                conn.execute(
                    "UPDATE bundle_claims SET encrypted_bundle = NULL, "
                    "confirmed_at = ?, destroyed_at = ?, operation_token = NULL, "
                    "operation_kind = NULL, operation_started_at = NULL WHERE bundle_id = ?",
                    (_iso(now), _iso(now), bundle_id),
                )
            conn.commit()
            updated_user = conn.execute(
                "SELECT * FROM provisioned_users WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            updated_claim = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            return (
                self._row_to_user(updated_user),
                self._row_to_bundle_claim(updated_claim),
            )
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def confirm_paid_bundle_rotation(
        self,
        bundle_id: str,
        *,
        now: datetime,
        operation_token: str,
    ) -> tuple[ProvisionedUser, BundleClaim]:
        """Atomically record validated rotation and destroy bundle ciphertext."""
        return await asyncio.to_thread(
            self._confirm_paid_bundle_rotation_sync,
            bundle_id,
            now,
            operation_token,
        )

    def _mark_subscription_acknowledged_sync(
        self, token_fingerprint: str, now: datetime
    ) -> StoredSubscription:
        conn = self._connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (token_fingerprint,),
            ).fetchone()
            if row is None:
                raise PurchaseTokenConflictException("Unknown purchase token")
            existing = self._row_to_subscription(row)
            if existing.acknowledgement_state is AcknowledgementState.PENDING:
                self._record_subscription_event_sync(
                    conn,
                    subscription_id=existing.subscription_id,
                    snapshot=replace(
                        existing,
                        acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
                        acknowledged_at=existing.acknowledged_at or now,
                    ),
                    existing=row,
                    event_type=SubscriptionEventType.ACKNOWLEDGED,
                    now=now,
                )
            conn.execute(
                "UPDATE play_subscriptions SET acknowledgement_state = ?, "
                "acknowledged_at = COALESCE(acknowledged_at, ?), updated_at = ? "
                "WHERE token_fingerprint = ?",
                (
                    AcknowledgementState.ACKNOWLEDGED.value,
                    _iso(now),
                    _iso(now),
                    token_fingerprint,
                ),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (token_fingerprint,),
            ).fetchone()
            return self._row_to_subscription(row)
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    async def mark_subscription_acknowledged(
        self, token_fingerprint: str, *, now: datetime
    ) -> StoredSubscription:
        """Record server acknowledgement after bundle escrow is durable."""
        return await asyncio.to_thread(
            self._mark_subscription_acknowledged_sync,
            token_fingerprint,
            now,
        )

    def _record_subscription_enforcement_sync(
        self,
        token_fingerprint: str,
        suspended: bool,
        now: datetime,
        last_error: str | None,
    ) -> StoredSubscription:
        conn = self._connect()
        try:
            source = conn.execute(
                "SELECT entitlement_id FROM play_subscriptions WHERE token_fingerprint = ?",
                (token_fingerprint,),
            ).fetchone()
            if source is None:
                raise PurchaseTokenConflictException("Unknown purchase token")
            timestamp_column = "suspended_at" if suspended else "unsuspended_at"
            conn.execute(
                f"UPDATE play_subscriptions SET {timestamp_column} = ?, "
                "matrix_suspended = ?, last_error = ?, updated_at = ? "
                "WHERE entitlement_id = ? AND is_current = 1",
                (
                    _iso(now),
                    int(suspended),
                    last_error,
                    _iso(now),
                    source["entitlement_id"],
                ),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE entitlement_id = ? AND is_current = 1",
                (source["entitlement_id"],),
            ).fetchone()
            if row is None:
                raise PurchaseTokenConflictException("Unknown purchase token")
            return self._row_to_subscription(row)
        finally:
            conn.close()

    async def record_subscription_enforcement(
        self,
        token_fingerprint: str,
        *,
        suspended: bool,
        now: datetime,
        last_error: str | None = None,
    ) -> StoredSubscription:
        """Record observed Matrix state on the entitlement's current token."""
        return await asyncio.to_thread(
            self._record_subscription_enforcement_sync,
            token_fingerprint,
            suspended,
            now,
            last_error,
        )

    def _record_subscription_error_sync(
        self,
        token_fingerprint: str,
        last_error: str,
        now: datetime,
        next_reconciliation_at: datetime | None,
    ) -> StoredSubscription:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE play_subscriptions SET last_error = ?, updated_at = ?, "
                "next_reconciliation_at = COALESCE(?, next_reconciliation_at) "
                "WHERE token_fingerprint = ?",
                (
                    last_error,
                    _iso(now),
                    _iso(next_reconciliation_at),
                    token_fingerprint,
                ),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM play_subscriptions WHERE token_fingerprint = ?",
                (token_fingerprint,),
            ).fetchone()
            if row is None:
                raise PurchaseTokenConflictException("Unknown purchase token")
            return self._row_to_subscription(row)
        finally:
            conn.close()

    async def record_subscription_error(
        self,
        token_fingerprint: str,
        *,
        last_error: str,
        now: datetime,
        next_reconciliation_at: datetime | None = None,
    ) -> StoredSubscription:
        """Record a failed reconciliation without claiming enforcement changed."""
        return await asyncio.to_thread(
            self._record_subscription_error_sync,
            token_fingerprint,
            last_error,
            now,
            next_reconciliation_at,
        )
