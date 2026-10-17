"""A paid account in a chosen suspension state, shared by the erasure tests."""

# ruff: noqa: S105,S106 - explicit non-production credential fixtures

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from src.core.subscriptions import (
    AcknowledgementState,
    EntitlementState,
    GoogleSubscriptionState,
    SubscriptionProvider,
    VerifiedSubscription,
)
from tests.conftest import seed_user

NOW = datetime(2026, 10, 17, 12, tzinfo=timezone.utc)


async def paid_account(repository, name, *, suspended_at=None, unsuspended_at=None, claim=True):
    """Seed a provisioned user, its subscription and (optionally) its bundle claim."""
    user = await seed_user(repository, name)
    await repository.create_entitlement(
        entitlement_id=f"entitlement-{name}",
        obfuscated_account_id=f"obfuscated-{name}",
        auth_secret_hash="auth-hash",
        now=NOW - timedelta(days=90),
    )
    stored = await repository.store_verified_subscription(
        VerifiedSubscription(
            entitlement_id=f"entitlement-{name}",
            token_fingerprint=f"fp-{name}",
            encrypted_purchase_token=b"sealed",
            encryption_key_id="key-v1",
            package_name="paddle",
            product_id="pro_lotti_sync",
            base_plan_id="pri_monthly",
            latest_order_id=None,
            google_state=GoogleSubscriptionState.EXPIRED,
            entitlement_state=EntitlementState.EXPIRED,
            start_time=NOW - timedelta(days=90),
            current_period_end=None,
            grace_deadline=None,
            acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            binding_verified=True,
            last_verified_at=NOW - timedelta(days=90),
            next_reconciliation_at=NOW,
            bundle_id=user.bundle_id,
            provider=SubscriptionProvider.PADDLE,
        ),
        now=NOW - timedelta(days=90),
    )
    if claim:
        conn = repository._connect()
        try:
            conn.execute(
                "INSERT INTO bundle_claims (bundle_id, subscription_id, claim_secret_hash, "
                "authorized_token_fingerprint, encryption_key_id, expires_at, confirmed_at, "
                "destroyed_at, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    user.bundle_id,
                    stored.subscription_id,
                    "claim-hash",
                    stored.token_fingerprint,
                    "key-v1",
                    (NOW - timedelta(days=89)).isoformat(),
                    (NOW - timedelta(days=90)).isoformat(),
                    (NOW - timedelta(days=90)).isoformat(),
                    (NOW - timedelta(days=90)).isoformat(),
                ),
            )
            conn.commit()
        finally:
            conn.close()
    if suspended_at is not None:
        await repository.record_subscription_enforcement(
            stored.token_fingerprint, suspended=True, now=suspended_at
        )
    if unsuspended_at is not None:
        await repository.record_subscription_enforcement(
            stored.token_fingerprint, suspended=False, now=unsuspended_at
        )
    return user
