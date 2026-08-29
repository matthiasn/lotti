"""Google Play subscription states and their sync-access interpretation."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class GoogleSubscriptionState(str, Enum):
    """States returned by ``purchases.subscriptionsv2.get``."""

    UNSPECIFIED = "SUBSCRIPTION_STATE_UNSPECIFIED"
    PENDING = "SUBSCRIPTION_STATE_PENDING"
    ACTIVE = "SUBSCRIPTION_STATE_ACTIVE"
    PAUSED = "SUBSCRIPTION_STATE_PAUSED"
    IN_GRACE_PERIOD = "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
    ON_HOLD = "SUBSCRIPTION_STATE_ON_HOLD"
    CANCELED = "SUBSCRIPTION_STATE_CANCELED"
    EXPIRED = "SUBSCRIPTION_STATE_EXPIRED"
    PENDING_PURCHASE_CANCELED = "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED"


class EntitlementState(str, Enum):
    """Small internal state machine used to enforce Matrix sync access."""

    PENDING = "pending"
    ACTIVE = "active"
    GRACE = "grace"
    CANCELED_ACTIVE = "canceled_active"
    SUSPENDED = "suspended"
    EXPIRED = "expired"


class AcknowledgementState(str, Enum):
    """Acknowledgement state returned by Google Play."""

    PENDING = "ACKNOWLEDGEMENT_STATE_PENDING"
    ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"


@dataclass(frozen=True)
class SyncEntitlement:
    """Stable server identity to which Play purchases are attributed."""

    entitlement_id: str
    obfuscated_account_id: str
    auth_secret_hash: str
    created_at: datetime
    disabled_at: datetime | None


@dataclass(frozen=True)
class PurchaseIntent:
    """One-time authorization binding a Billing launch to an entitlement."""

    intent_id: str
    entitlement_id: str
    intent_secret_hash: str
    product_id: str
    base_plan_id: str
    obfuscated_account_id: str
    expires_at: datetime
    expected_request_hash: str | None
    consumed_token_fingerprint: str | None
    integrity_token_fingerprint: str | None
    consumed_at: datetime | None
    created_at: datetime


@dataclass(frozen=True)
class EntitlementCredentials:
    """One-time response when a stable anonymous entitlement is created."""

    entitlement_id: str
    auth_secret: str
    obfuscated_account_id: str


@dataclass(frozen=True)
class PurchaseIntentCredentials:
    """One-time Billing launch authorization returned to an authenticated app."""

    intent_id: str
    intent_secret: str
    product_id: str
    base_plan_id: str
    obfuscated_account_id: str
    expires_at: datetime


@dataclass(frozen=True)
class PurchaseSubmission:
    """Client proof set submitted after Play Billing reports a purchase."""

    package_name: str
    product_id: str
    base_plan_id: str
    entitlement_id: str
    purchase_intent_id: str
    purchase_token: str
    intent_secret: str
    claim_secret: str
    integrity_token: str


@dataclass(frozen=True)
class VerifiedPurchaseResult:
    """Durably stored verification result, safe to expose to orchestration."""

    subscription: StoredSubscription
    request_hash: str
    claim_secret_hash: str


@dataclass(frozen=True)
class BundleClaim:
    """Short-lived encrypted escrow for reliable paid bundle delivery."""

    bundle_id: str
    subscription_id: str
    claim_secret_hash: str
    authorized_token_fingerprint: str
    encrypted_bundle: bytes | None
    encryption_key_id: str
    expires_at: datetime
    first_delivered_at: datetime | None
    confirmed_at: datetime | None
    destroyed_at: datetime | None
    created_at: datetime


@dataclass(frozen=True)
class PaidBundleDelivery:
    """Paid provisioning outcome, with credentials only when import is needed."""

    bundle_id: str
    bundle: str | None
    expires_at: datetime | None
    rotation_challenge: str | None
    bundle_import_required: bool = True


@dataclass(frozen=True)
class VerifiedSubscription:
    """Security-checked Google snapshot ready for an atomic persistence write."""

    entitlement_id: str
    token_fingerprint: str
    encrypted_purchase_token: bytes
    encryption_key_id: str
    package_name: str
    product_id: str
    base_plan_id: str
    latest_order_id: str | None
    google_state: GoogleSubscriptionState
    entitlement_state: EntitlementState
    start_time: datetime | None
    current_period_end: datetime | None
    grace_deadline: datetime | None
    acknowledgement_state: AcknowledgementState
    binding_verified: bool
    last_verified_at: datetime
    next_reconciliation_at: datetime
    linked_token_fingerprint: str | None = None
    out_of_app_expired_token_fingerprint: str | None = None
    bundle_id: str | None = None
    acknowledged_at: datetime | None = None
    suspended_at: datetime | None = None
    unsuspended_at: datetime | None = None
    last_error: str | None = None


@dataclass(frozen=True)
class StoredSubscription(VerifiedSubscription):
    """Persisted subscription including lifecycle and lineage metadata."""

    subscription_id: str = ""
    is_current: bool = True
    replaced_by_token_fingerprint: str | None = None
    retired_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass(frozen=True)
class GooglePlayLineItem:
    """Subscription line item returned by Android Publisher v2."""

    product_id: str
    base_plan_id: str | None
    expiry_time: datetime | None
    latest_successful_order_id: str | None


@dataclass(frozen=True)
class GooglePlaySnapshot:
    """Parsed, but not yet entitlement-authorized, Google purchase response."""

    state: GoogleSubscriptionState
    acknowledgement_state: AcknowledgementState
    line_items: tuple[GooglePlayLineItem, ...]
    start_time: datetime | None
    linked_purchase_token: str | None
    obfuscated_external_account_id: str | None
    obfuscated_external_profile_id: str | None
    test_purchase: bool
    expired_purchase_token: str | None
    expired_obfuscated_external_account_id: str | None
    expired_obfuscated_external_profile_id: str | None


@dataclass(frozen=True)
class RealtimeDeveloperNotification:
    """Trusted fields decoded from a Google Play RTDN Pub/Sub envelope."""

    package_name: str
    purchase_token: str
    notification_type: int
    event_time: datetime


@dataclass(frozen=True)
class RealtimeDeveloperTestNotification:
    """Authenticated Google Play Pub/Sub connectivity test signal."""

    package_name: str
    event_time: datetime


@dataclass(frozen=True)
class NormalizedEntitlement:
    """Result of interpreting an authoritative Google subscription snapshot."""

    state: EntitlementState
    access_granted: bool
    access_deadline: datetime | None


def _require_aware(value: datetime | None, name: str) -> datetime:
    if value is None or value.tzinfo is None or value.utcoffset() is None:
        raise ValueError(f"{name} must be timezone-aware")
    return value


def normalize_entitlement(
    play_state: GoogleSubscriptionState,
    *,
    expiry_time: datetime | None,
    now: datetime,
) -> NormalizedEntitlement:
    """Translate Google state into the access state enforced by Lotti.

    Google dynamically extends a grace-period line item's ``expiryTime`` to
    the authoritative grace deadline. Access is therefore allowed strictly
    before that timestamp and is removed at the boundary; this service never
    adds a second local grace window.
    """
    current_time = _require_aware(now, "now")

    if play_state is GoogleSubscriptionState.PENDING:
        return NormalizedEntitlement(EntitlementState.PENDING, False, None)

    if play_state is GoogleSubscriptionState.EXPIRED:
        return NormalizedEntitlement(EntitlementState.EXPIRED, False, None)

    grantable_states = {
        GoogleSubscriptionState.ACTIVE: EntitlementState.ACTIVE,
        GoogleSubscriptionState.IN_GRACE_PERIOD: EntitlementState.GRACE,
        GoogleSubscriptionState.CANCELED: EntitlementState.CANCELED_ACTIVE,
    }
    if play_state in grantable_states:
        deadline = _require_aware(expiry_time, "expiry_time")
        if current_time < deadline:
            return NormalizedEntitlement(grantable_states[play_state], True, deadline)
        if play_state is GoogleSubscriptionState.IN_GRACE_PERIOD:
            return NormalizedEntitlement(EntitlementState.SUSPENDED, False, None)
        return NormalizedEntitlement(EntitlementState.EXPIRED, False, None)

    return NormalizedEntitlement(EntitlementState.SUSPENDED, False, None)
