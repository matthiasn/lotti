"""Core domain models"""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator

from .constants import USERNAME_PATTERN


class BundleStatus(str, Enum):
    """Lifecycle of a provisioning bundle.

    The transitions are strictly forward-only, except that any non-terminal
    status may be ``REVOKED`` by an admin::

        UNUSED ──▶ REDEEMED ──▶ ROTATED
           │           │
           └───────────┴──────▶ REVOKED

    ``REDEEMED`` means the homeserver shows evidence of a sign-in (observed by
    polling). ``ROTATED`` means the client confirmed it replaced the temporary
    password. The gap between the two is the partial-rotation window: the
    account is live but still reachable with the bundle's password.
    """

    UNUSED = "unused"
    REDEEMED = "redeemed"
    ROTATED = "rotated"
    REVOKED = "revoked"

    @property
    def is_terminal(self) -> bool:
        """Whether no further transition is possible."""
        return self in (BundleStatus.ROTATED, BundleStatus.REVOKED)


class PaymentStatus(str, Enum):
    """Manually tracked contribution status.

    Phase 1 sets this by hand. It is deliberately a small closed set so a
    payment provider or Substack sync can drive the same field later without a
    schema change.
    """

    UNKNOWN = "unknown"
    PAYING = "paying"
    NON_PAYING = "non_paying"
    COMPLIMENTARY = "complimentary"


class BundleEventType(str, Enum):
    """Audit trail entry types for a bundle."""

    CREATED = "created"
    REDEEMED = "redeemed"
    ROTATED = "rotated"
    REVOKED = "revoked"
    PAYMENT_STATUS_CHANGED = "payment_status_changed"
    RETENTION_CHANGED = "retention_changed"
    PURGED = "purged"
    NOTE_UPDATED = "note_updated"
    POLL_FAILED = "poll_failed"


class ProvisionedUser(BaseModel):
    """A provisioned account and the bundle that created it.

    Bundle and user are 1:1: every provisioning run creates a fresh Matrix
    account, so re-issuing access to someone means provisioning a new user
    rather than re-minting a bundle for an existing one.
    """

    bundle_id: str = Field(..., description="Opaque bundle identifier (UUID4)")
    username: str = Field(..., description="Localpart of the provisioned user")
    user_mxid: str = Field(..., description="Full MXID, e.g. @user:example.com")
    home_server: str = Field(..., description="Homeserver base URL")
    server_name: str = Field(..., description="Homeserver domain part of the MXID")
    room_id: str = Field(..., description="Matrix room ID of the sync room")
    display_name: str | None = Field(None, description="Display name of the account")

    status: BundleStatus = Field(
        default=BundleStatus.UNUSED, description="Bundle redemption status"
    )
    payment_status: PaymentStatus = Field(
        default=PaymentStatus.UNKNOWN, description="Contribution status"
    )

    bundle_fingerprint: str = Field(
        ...,
        description=(
            "SHA-256 of the encoded bundle. The bundle itself is never stored — "
            "this exists only to correlate a bundle a user shows you with its record."
        ),
    )

    created_at: datetime = Field(..., description="When the account was provisioned")
    first_login_at: datetime | None = Field(
        None, description="First observed sign-in, i.e. when the bundle was redeemed"
    )
    rotated_at: datetime | None = Field(
        None, description="When the client confirmed password rotation"
    )
    revoked_at: datetime | None = Field(None, description="When an admin revoked the bundle")
    last_seen_at: datetime | None = Field(
        None, description="Most recent device activity reported by Synapse"
    )
    last_polled_at: datetime | None = Field(
        None, description="When the redemption poller last checked this account"
    )

    notes: str = Field(default="", description="Free-form admin notes")

    retention_days: int | None = Field(
        None,
        description=(
            "Per-user retention window. None inherits the service default, so "
            "changing the default moves everyone who has not been pinned."
        ),
    )
    retention_exempt: bool = Field(
        default=False,
        description="Skip this user entirely in the scheduled retention sweep",
    )

    @property
    def effective_retention_days(self) -> int | None:
        """The user's own window, or None to mean 'inherit the default'."""
        return self.retention_days

    @property
    def active_days(self) -> int | None:
        """Days since first login, or ``None`` if never redeemed.

        This is the Phase 3 "how long has this user been active" measure. It
        counts from first login rather than creation so that an unredeemed
        bundle sitting for a month does not read as an active user.
        """
        if self.first_login_at is None:
            return None
        return (datetime.now(self.first_login_at.tzinfo) - self.first_login_at).days


class BundleEvent(BaseModel):
    """An entry in a bundle's audit trail."""

    id: int = Field(..., description="Monotonic event ID")
    bundle_id: str = Field(..., description="Bundle this event belongs to")
    event_type: BundleEventType = Field(..., description="What happened")
    detail: str = Field(default="", description="Human-readable context")
    created_at: datetime = Field(..., description="When the event was recorded")


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class CreateBundleRequest(BaseModel):
    """Request to provision a new user and mint their bundle."""

    username: str = Field(..., description="Localpart for the new user")
    display_name: str | None = Field(None, description="Optional display name")
    notes: str = Field(default="", description="Optional admin notes")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        """Reject localparts Synapse would mangle or that read badly in the UI."""
        import re

        normalised = v.strip().lower()
        if not re.match(USERNAME_PATTERN, normalised):
            raise ValueError(
                "Username must be 3-64 characters, start with a letter or digit, "
                "and contain only lowercase letters, digits, dot, underscore or hyphen"
            )
        return normalised


class CreateBundleResponse(BaseModel):
    """Response after provisioning.

    ``bundle`` is returned exactly once, at creation, and is never persisted.
    If it is lost, revoke the record and provision a new user.
    """

    bundle: str = Field(..., description="Base64url provisioning bundle — shown once")
    user: ProvisionedUser = Field(..., description="The stored record")


class UpdateUserRequest(BaseModel):
    """Request to update the manually maintained fields of a record."""

    payment_status: PaymentStatus | None = Field(None, description="New payment status")
    notes: str | None = Field(None, description="Replacement admin notes")
    retention_days: int | None = Field(
        None, description="Per-user retention window; omit to leave unchanged"
    )
    retention_exempt: bool | None = Field(
        None, description="Exclude this user from the scheduled sweep"
    )
    clear_retention_override: bool = Field(
        default=False,
        description=(
            "Reset retention_days to None so the user follows the service "
            "default again. Needed because None already means 'unchanged'."
        ),
    )


class ProvisionedUserListResponse(BaseModel):
    """Paginated list of provisioned users."""

    users: list[ProvisionedUser] = Field(..., description="Records for this page")
    total: int = Field(..., description="Total records matching the filter")
    page: int = Field(..., description="1-based page number")
    page_size: int = Field(..., description="Records per page")


class StatsResponse(BaseModel):
    """Aggregate counts for the admin dashboard."""

    total_provisioned: int = Field(..., description="All records ever created")
    unused: int = Field(..., description="Bundles not yet redeemed")
    redeemed: int = Field(..., description="Signed in but rotation unconfirmed")
    rotated: int = Field(..., description="Rotation confirmed")
    revoked: int = Field(..., description="Revoked by an admin")
    paying: int = Field(..., description="Users marked as paying")
    non_paying: int = Field(..., description="Users marked as non-paying")
    unknown_payment: int = Field(..., description="Users with no payment status set")
    complimentary: int = Field(..., description="Users on a complimentary arrangement")
    signups_by_day: dict[str, int] = Field(
        default_factory=dict, description="ISO date → count of accounts provisioned"
    )
