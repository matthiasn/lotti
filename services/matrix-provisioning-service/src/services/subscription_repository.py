"""SQLite persistence for Google Play subscription ownership and state."""

from __future__ import annotations

import asyncio
import sqlite3
import uuid
from datetime import datetime

from ..core.constants import BUSY_TIMEOUT_SECONDS, DEFAULT_DB_PATH
from ..core.exceptions import (
    BundleClaimConflictException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    SubscriptionLineageException,
)
from ..core.subscriptions import (
    AcknowledgementState,
    BundleClaim,
    EntitlementState,
    GoogleSubscriptionState,
    PurchaseIntent,
    StoredSubscription,
    SyncEntitlement,
    VerifiedSubscription,
)
from ..core.models import BundleEventType, BundleStatus, PaymentStatus, ProvisionedUser
from .provisioning_repository import ProvisioningRepository


_SCHEMA = """
CREATE TABLE IF NOT EXISTS sync_entitlements (
    entitlement_id         TEXT PRIMARY KEY,
    obfuscated_account_id  TEXT NOT NULL UNIQUE,
    auth_secret_hash       TEXT NOT NULL,
    created_at             TEXT NOT NULL,
    disabled_at            TEXT
);

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
    encrypted_bundle     BLOB,
    encryption_key_id    TEXT NOT NULL,
    expires_at           TEXT NOT NULL,
    first_delivered_at   TEXT,
    confirmed_at         TEXT,
    destroyed_at         TEXT,
    created_at           TEXT NOT NULL,
    FOREIGN KEY (bundle_id) REFERENCES provisioned_users (bundle_id) ON DELETE CASCADE,
    FOREIGN KEY (subscription_id) REFERENCES play_subscriptions (subscription_id)
);
"""


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _parse(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


class SubscriptionRepository(ProvisioningRepository):
    """Owns stable entitlements and replay-safe Play token bindings."""

    def __init__(self, db_path: str = DEFAULT_DB_PATH):
        super().__init__(db_path)
        self._ensure_subscription_db()

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
            last_verified_at=_parse(row["last_verified_at"]),
            next_reconciliation_at=_parse(row["next_reconciliation_at"]),
            last_error=row["last_error"],
            subscription_id=row["subscription_id"],
            created_at=_parse(row["created_at"]),
            updated_at=_parse(row["updated_at"]),
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
            encrypted_bundle=bytes(encrypted) if encrypted is not None else None,
            encryption_key_id=row["encryption_key_id"],
            expires_at=_parse(row["expires_at"]),
            first_delivered_at=_parse(row["first_delivered_at"]),
            confirmed_at=_parse(row["confirmed_at"]),
            destroyed_at=_parse(row["destroyed_at"]),
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
                    _iso(now) if intent.consumed_at is None else _iso(intent.consumed_at),
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

            predecessor_fingerprint = (
                snapshot.linked_token_fingerprint or snapshot.out_of_app_expired_token_fingerprint
            )
            predecessor = None
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
                inherited_bundle_id = (
                    snapshot.bundle_id
                    if snapshot.bundle_id is not None
                    else current["bundle_id"]
                    if current is not None
                    else None
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
                "suspended_at, unsuspended_at, last_verified_at, next_reconciliation_at, "
                "last_error, created_at, updated_at"
                ") VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) "
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
                "acknowledged_at=excluded.acknowledged_at, "
                "out_of_app_expired_token_fingerprint="
                "excluded.out_of_app_expired_token_fingerprint, "
                "binding_verified=excluded.binding_verified, bundle_id=excluded.bundle_id, "
                "suspended_at=excluded.suspended_at, unsuspended_at=excluded.unsuspended_at, "
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
            rows = conn.execute(
                "SELECT * FROM play_subscriptions "
                "WHERE is_current = 1 AND next_reconciliation_at <= ? "
                "ORDER BY next_reconciliation_at ASC LIMIT ?",
                (_iso(now), max(1, limit)),
            ).fetchall()
            return [self._row_to_subscription(row) for row in rows]
        finally:
            conn.close()

    async def list_due_reconciliation(
        self, now: datetime, *, limit: int
    ) -> list[StoredSubscription]:
        """List current subscriptions whose Google state must be refreshed."""
        return await asyncio.to_thread(self._list_due_reconciliation_sync, now, limit)

    def _store_paid_bundle_sync(
        self,
        *,
        token_fingerprint: str,
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
                "bundle_id, subscription_id, claim_secret_hash, encrypted_bundle, "
                "encryption_key_id, expires_at, created_at"
                ") VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    bundle_id,
                    subscription["subscription_id"],
                    claim_secret_hash,
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

    def _list_expired_bundle_claims_sync(self, now: datetime, limit: int) -> list[BundleClaim]:
        conn = self._connect()
        try:
            rows = conn.execute(
                "SELECT * FROM bundle_claims WHERE destroyed_at IS NULL "
                "AND expires_at <= ? ORDER BY expires_at ASC LIMIT ?",
                (_iso(now), max(1, limit)),
            ).fetchall()
            return [self._row_to_bundle_claim(row) for row in rows]
        finally:
            conn.close()

    async def list_expired_bundle_claims(self, now: datetime, *, limit: int) -> list[BundleClaim]:
        """List abandoned escrow claims whose bootstrap access must be revoked."""
        return await asyncio.to_thread(
            self._list_expired_bundle_claims_sync,
            now,
            limit,
        )

    def _mark_bundle_delivered_sync(self, bundle_id: str, now: datetime) -> BundleClaim:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE bundle_claims SET first_delivered_at = "
                "COALESCE(first_delivered_at, ?) WHERE bundle_id = ?",
                (_iso(now), bundle_id),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleClaimConflictException("Unknown bundle claim")
            return self._row_to_bundle_claim(row)
        finally:
            conn.close()

    async def mark_bundle_delivered(self, bundle_id: str, *, now: datetime) -> BundleClaim:
        """Stamp the first successful delivery without moving it on retries."""
        return await asyncio.to_thread(self._mark_bundle_delivered_sync, bundle_id, now)

    def _destroy_bundle_claim_sync(self, bundle_id: str, now: datetime) -> BundleClaim:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE bundle_claims SET encrypted_bundle = NULL, "
                "confirmed_at = COALESCE(confirmed_at, ?), "
                "destroyed_at = COALESCE(destroyed_at, ?) WHERE bundle_id = ?",
                (_iso(now), _iso(now), bundle_id),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleClaimConflictException("Unknown bundle claim")
            return self._row_to_bundle_claim(row)
        finally:
            conn.close()

    async def destroy_bundle_claim(self, bundle_id: str, *, now: datetime) -> BundleClaim:
        """Irreversibly remove bundle ciphertext after validated rotation proof."""
        return await asyncio.to_thread(self._destroy_bundle_claim_sync, bundle_id, now)

    def _abandon_bundle_claim_sync(self, bundle_id: str, now: datetime) -> BundleClaim:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE bundle_claims SET encrypted_bundle = NULL, "
                "destroyed_at = COALESCE(destroyed_at, ?) WHERE bundle_id = ?",
                (_iso(now), bundle_id),
            )
            conn.commit()
            row = conn.execute(
                "SELECT * FROM bundle_claims WHERE bundle_id = ?", (bundle_id,)
            ).fetchone()
            if row is None:
                raise BundleClaimConflictException("Unknown bundle claim")
            return self._row_to_bundle_claim(row)
        finally:
            conn.close()

    async def abandon_bundle_claim(self, bundle_id: str, *, now: datetime) -> BundleClaim:
        """Destroy expired escrow without falsely marking rotation confirmed."""
        return await asyncio.to_thread(self._abandon_bundle_claim_sync, bundle_id, now)

    def _confirm_paid_bundle_rotation_sync(
        self, bundle_id: str, now: datetime
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
                    "confirmed_at = ?, destroyed_at = ? WHERE bundle_id = ?",
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
        self, bundle_id: str, *, now: datetime
    ) -> tuple[ProvisionedUser, BundleClaim]:
        """Atomically record validated rotation and destroy bundle ciphertext."""
        return await asyncio.to_thread(
            self._confirm_paid_bundle_rotation_sync,
            bundle_id,
            now,
        )

    def _mark_subscription_acknowledged_sync(
        self, token_fingerprint: str, now: datetime
    ) -> StoredSubscription:
        conn = self._connect()
        try:
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
            if row is None:
                raise PurchaseTokenConflictException("Unknown purchase token")
            return self._row_to_subscription(row)
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
            timestamp_column = "suspended_at" if suspended else "unsuspended_at"
            conn.execute(
                f"UPDATE play_subscriptions SET {timestamp_column} = ?, "
                "last_error = ?, updated_at = ? WHERE token_fingerprint = ?",
                (_iso(now), last_error, _iso(now), token_fingerprint),
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

    async def record_subscription_enforcement(
        self,
        token_fingerprint: str,
        *,
        suspended: bool,
        now: datetime,
        last_error: str | None = None,
    ) -> StoredSubscription:
        """Record observed Matrix enforcement state and its latest error."""
        return await asyncio.to_thread(
            self._record_subscription_enforcement_sync,
            token_fingerprint,
            suspended,
            now,
            last_error,
        )

    def _record_subscription_error_sync(
        self, token_fingerprint: str, last_error: str, now: datetime
    ) -> StoredSubscription:
        conn = self._connect()
        try:
            conn.execute(
                "UPDATE play_subscriptions SET last_error = ?, updated_at = ? "
                "WHERE token_fingerprint = ?",
                (last_error, _iso(now), token_fingerprint),
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
        self, token_fingerprint: str, *, last_error: str, now: datetime
    ) -> StoredSubscription:
        """Record a failed reconciliation without claiming enforcement changed."""
        return await asyncio.to_thread(
            self._record_subscription_error_sync,
            token_fingerprint,
            last_error,
            now,
        )
