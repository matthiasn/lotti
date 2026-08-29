"""FastAPI routes for the matrix provisioning service."""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Header, HTTPException, Query, Request, status

from ..container import container
from ..core.constants import (
    DEFAULT_EVENT_LIMIT,
    DEFAULT_PAGE_SIZE,
    MAX_EVENT_LIMIT,
    MAX_PAGE_SIZE,
)
from ..core.exceptions import (
    BundleClaimConflictException,
    BundleClaimRateLimitException,
    BundleNotFoundException,
    EntitlementAuthenticationException,
    EntitlementRateLimitException,
    GooglePlayUnavailableException,
    GooglePlayVerificationException,
    InvalidBundleStateException,
    InvalidSubscriptionProductException,
    PubSubAuthenticationException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseIntentRateLimitException,
    PurchaseIntentReplayException,
    PurchaseTokenConflictException,
    PurchaseVerificationRateLimitException,
    SubscriptionLineageException,
    SynapseUnavailableException,
    UsernameAlreadyProvisionedException,
)
from ..core.models import (
    BundleDeliveryRequest,
    BundleEvent,
    BundleStatus,
    ConfirmPaidRotationRequest,
    CreateBundleRequest,
    CreateBundleResponse,
    CreatePurchaseIntentRequest,
    EntitlementCredentialsResponse,
    PaidBundleResponse,
    PaymentStatus,
    ProvisionedUser,
    ProvisionedUserListResponse,
    PurchaseIntentResponse,
    StatsResponse,
    UpdateUserRequest,
    VerifyPurchaseRequest,
)
from ..core.subscriptions import PurchaseSubmission

logger = logging.getLogger(__name__)

router = APIRouter()


def _bearer_secret(authorization: str) -> str:
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Entitlement bearer credential required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return parts[1]


def _require_subscriptions_enabled() -> None:
    if os.getenv("ENABLE_PLAY_SUBSCRIPTIONS", "false").lower() not in (
        "1",
        "true",
        "yes",
    ):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Play SYNC subscriptions are disabled",
        )


# ---------------------------------------------------------------------------
# Google Play SYNC subscriptions
# ---------------------------------------------------------------------------


@router.post(
    "/client/subscriptions/entitlements",
    response_model=EntitlementCredentialsResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["subscriptions"],
)
async def create_sync_entitlement(request: Request) -> EntitlementCredentialsResponse:
    """Issue the stable app identity that purchases are attributed to."""
    _require_subscriptions_enabled()
    try:
        credentials = await container.get_subscription_identity_service().create_entitlement(
            client_identifier=request.client.host if request.client is not None else "unknown",
            now=datetime.now(timezone.utc),
        )
        return EntitlementCredentialsResponse(**credentials.__dict__)
    except EntitlementRateLimitException as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc


@router.post(
    "/client/subscriptions/purchase-intents",
    response_model=PurchaseIntentResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["subscriptions"],
)
async def create_purchase_intent(
    request: CreatePurchaseIntentRequest,
    authorization: str = Header(default=""),
) -> PurchaseIntentResponse:
    """Authorize one Billing launch for an authenticated entitlement."""
    _require_subscriptions_enabled()
    try:
        intent = await container.get_subscription_identity_service().create_purchase_intent(
            entitlement_id=request.entitlement_id,
            auth_secret=_bearer_secret(authorization),
            product_id=request.product_id,
            base_plan_id=request.base_plan_id,
            now=datetime.now(timezone.utc),
        )
        return PurchaseIntentResponse(**intent.__dict__)
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except InvalidSubscriptionProductException as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except PurchaseIntentRateLimitException as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc


@router.post(
    "/client/subscriptions/purchases/verify",
    response_model=PaidBundleResponse,
    tags=["subscriptions"],
)
async def verify_subscription_purchase(
    request: VerifyPurchaseRequest,
    authorization: str = Header(default=""),
) -> PaidBundleResponse:
    """Verify with Google, persist entitlement, and deliver one paid bundle."""
    _require_subscriptions_enabled()
    submission = PurchaseSubmission(**request.model_dump())
    now = datetime.now(timezone.utc)
    try:
        verified = await container.get_subscription_service().verify_purchase(
            submission,
            entitlement_auth_secret=_bearer_secret(authorization),
            now=now,
        )
        current = await container.get_subscription_repository().get_current_subscription(
            verified.subscription.entitlement_id
        )
        if current is None:
            raise BundleClaimConflictException("Verified subscription is missing")
        await container.get_subscription_access_service().enforce(current, now=now)
        delivery = await container.get_paid_bundle_service().provision_or_deliver(
            verified,
            submission,
            now=now,
        )
        return PaidBundleResponse(
            **delivery.__dict__,
            entitlement_state=current.entitlement_state.value,
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except PurchaseIntentExpiredException as exc:
        raise HTTPException(status_code=status.HTTP_410_GONE, detail=str(exc)) from exc
    except (
        PurchaseIntentNotFoundException,
        PurchaseIntentReplayException,
        PurchaseTokenConflictException,
        SubscriptionLineageException,
    ) as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except (
        GooglePlayVerificationException,
        InvalidSubscriptionProductException,
    ) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except GooglePlayUnavailableException as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    except PurchaseVerificationRateLimitException as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc
    except BundleClaimConflictException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post(
    "/client/subscriptions/bundle-claims/deliver",
    response_model=PaidBundleResponse,
    tags=["subscriptions"],
)
async def deliver_paid_bundle(
    request: BundleDeliveryRequest,
    authorization: str = Header(default=""),
) -> PaidBundleResponse:
    """Retry a lost paid-bundle response without replaying a purchase proof."""
    _require_subscriptions_enabled()
    try:
        now = datetime.now(timezone.utc)
        await container.get_subscription_identity_service().authenticate_bundle_claim_operation(
            request.entitlement_id,
            _bearer_secret(authorization),
            now=now,
        )
        subscription = await container.get_subscription_repository().get_current_subscription(
            request.entitlement_id
        )
        if subscription is None:
            raise BundleClaimConflictException("Subscription is missing")
        await container.get_subscription_access_service().enforce(subscription, now=now)
        delivery = await container.get_paid_bundle_service().deliver_existing_claim(
            entitlement_id=request.entitlement_id,
            claim_secret=request.claim_secret,
            now=datetime.now(timezone.utc),
        )
        return PaidBundleResponse(
            **delivery.__dict__,
            entitlement_state=subscription.entitlement_state.value,
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except BundleClaimRateLimitException as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc
    except GooglePlayVerificationException as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(exc),
        ) from exc
    except BundleClaimConflictException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post(
    "/client/subscriptions/bundle-claims/confirm-rotation",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["subscriptions"],
)
async def confirm_paid_bundle_rotation(
    request: ConfirmPaidRotationRequest,
    authorization: str = Header(default=""),
) -> None:
    """Destroy escrow only after server-observed Matrix rotation proof."""
    _require_subscriptions_enabled()
    try:
        await container.get_bundle_rotation_service().confirm_rotation(
            entitlement_id=request.entitlement_id,
            entitlement_auth_secret=_bearer_secret(authorization),
            bundle_id=request.bundle_id,
            claim_secret=request.claim_secret,
            now=datetime.now(timezone.utc),
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except BundleClaimRateLimitException as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc
    except BundleClaimConflictException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post(
    "/google-play/rtdn",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["subscriptions"],
)
async def receive_google_play_notification(
    envelope: dict,
    authorization: str = Header(default=""),
) -> None:
    """Authenticate Pub/Sub and re-query the notification's known Play token."""
    _require_subscriptions_enabled()
    try:
        await container.get_google_play_notifications().handle(
            envelope,
            authorization=authorization,
            now=datetime.now(timezone.utc),
        )
    except PubSubAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except GooglePlayVerificationException as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except GooglePlayUnavailableException as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------


@router.post(
    "/bundles",
    response_model=CreateBundleResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["bundles"],
)
async def create_bundle(request: CreateBundleRequest) -> CreateBundleResponse:
    """Provision a Matrix account and return its bundle.

    The bundle string is returned exactly once and is never stored. Copy it
    before leaving the page.
    """
    try:
        return await container.get_bundle_service().create_bundle(request)
    except UsernameAlreadyProvisionedException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except SynapseUnavailableException as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.get("/bundles", response_model=ProvisionedUserListResponse, tags=["bundles"])
async def list_bundles(
    page: int = Query(1, ge=1),
    page_size: int = Query(DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
    bundle_status: BundleStatus | None = Query(None, alias="status"),
    payment_status: PaymentStatus | None = Query(None),
) -> ProvisionedUserListResponse:
    """List provisioned users, newest first."""
    users, total = await container.get_repository().list_users(
        page=page,
        page_size=page_size,
        status=bundle_status,
        payment_status=payment_status,
    )
    return ProvisionedUserListResponse(users=users, total=total, page=page, page_size=page_size)


@router.get("/bundles/{bundle_id}", response_model=ProvisionedUser, tags=["bundles"])
async def get_bundle(bundle_id: str) -> ProvisionedUser:
    """Fetch a single provisioned user record."""
    user = await container.get_repository().get(bundle_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        )
    return user


@router.patch("/bundles/{bundle_id}", response_model=ProvisionedUser, tags=["bundles"])
async def update_bundle(bundle_id: str, request: UpdateUserRequest) -> ProvisionedUser:
    """Update payment status and/or notes."""
    try:
        return await container.get_repository().update(
            bundle_id,
            payment_status=request.payment_status,
            notes=request.notes,
            retention_days=request.retention_days,
            retention_exempt=request.retention_exempt,
            clear_retention_override=request.clear_retention_override,
        )
    except BundleNotFoundException as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        ) from exc


@router.get("/bundles/{bundle_id}/events", response_model=list[BundleEvent], tags=["bundles"])
async def get_bundle_events(
    bundle_id: str,
    limit: int = Query(
        DEFAULT_EVENT_LIMIT,
        ge=1,
        le=MAX_EVENT_LIMIT,
        description="Most recent entries to return",
    ),
) -> list[BundleEvent]:
    """Return a bundle's most recent audit entries, oldest first."""
    repository = container.get_repository()
    if await repository.get(bundle_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        )
    return await repository.get_events(bundle_id, limit)


@router.post(
    "/client/bundles/{bundle_id}/rotated",
    response_model=ProvisionedUser,
    tags=["client"],
)
async def confirm_rotation(bundle_id: str) -> ProvisionedUser:
    """Confirm that the client rotated the temporary password (Phase 2).

    Called by the Lotti client after a successful rotation. Idempotent, so a
    retry after a dropped response is safe.

    Deliberately namespaced under ``/client/`` rather than ``/bundles/`` so the
    auth middleware's prefix matching leaves it on the regular API key. The
    Lotti app must never need an admin credential to report its own rotation.
    """
    try:
        return await container.get_bundle_service().confirm_rotation(bundle_id)
    except BundleNotFoundException as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        ) from exc
    except InvalidBundleStateException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/bundles/{bundle_id}/revoke", response_model=ProvisionedUser, tags=["bundles"])
async def revoke_bundle(
    bundle_id: str,
    reason: str = Query("", description="Recorded in the audit trail"),
    deactivate_account: bool = Query(
        False, description="Also deactivate the Matrix account on Synapse"
    ),
) -> ProvisionedUser:
    """Revoke a bundle, optionally deactivating the underlying account."""
    try:
        return await container.get_bundle_service().revoke(
            bundle_id, reason=reason, deactivate_account=deactivate_account
        )
    except BundleNotFoundException as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        ) from exc
    except SynapseUnavailableException as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------


@router.get("/stats", response_model=StatsResponse, tags=["stats"])
async def get_stats(
    signup_history_days: int = Query(90, ge=1, le=730),
) -> StatsResponse:
    """Aggregate counts for the admin dashboard."""
    return await container.get_repository().get_stats(signup_history_days)


@router.get("/bundles/{bundle_id}/usage", tags=["stats"])
async def get_usage(bundle_id: str) -> dict:
    """Fetch live per-user activity and media usage from the Synapse admin API."""
    repository = container.get_repository()
    user = await repository.get(bundle_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        )

    admin_client = container.get_admin_client()
    try:
        activity = await admin_client.get_user_activity(user.user_mxid)
        media = await admin_client.get_media_usage(user.user_mxid)
    except Exception as exc:  # noqa: BLE001 - surfaced as a gateway error
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Could not read usage for {user.user_mxid}: {exc}",
        ) from exc

    # The retention figures ride along so the UI can state the window that will
    # actually be applied instead of guessing at one. A client-side default
    # would silently disagree with RETENTION_DAYS and purge more than the
    # configured policy allows.
    service_default = container.get_retention_service().default_retention_days

    # `media_length_bytes` is what the homeserver holds *now*, which drops to
    # near zero after a sweep. Adding back what previous purges reclaimed gives
    # the volume the account has produced over its life — otherwise a two-year
    # heavy user reads as lighter than someone who joined last week.
    purged_bytes, purged_files = await repository.purged_totals(bundle_id)

    return {
        "bundle_id": bundle_id,
        "user_mxid": user.user_mxid,
        "device_count": activity.device_count,
        "last_seen_ts": activity.last_seen_ts,
        "deactivated": activity.deactivated,
        "media_count": media.media_count,
        "media_length_bytes": media.media_length_bytes,
        "purged_media_bytes": purged_bytes,
        "purged_media_count": purged_files,
        "lifetime_media_bytes": media.media_length_bytes + purged_bytes,
        "lifetime_media_count": media.media_count + purged_files,
        "active_days": user.active_days,
        "retention_days_default": service_default,
        "retention_days_effective": (
            service_default if user.retention_days is None else user.retention_days
        ),
    }


# ---------------------------------------------------------------------------
# Retention
# ---------------------------------------------------------------------------


@router.post("/bundles/{bundle_id}/purge", tags=["retention"])
async def purge_room(
    bundle_id: str,
    retention_days: int | None = Query(None, description="Override the default retention window"),
    include_media: bool = Query(
        True, description="Also delete media files, which is what frees disk"
    ),
) -> dict:
    """Reclaim storage for one user older than the retention window.

    Purges room events and, by default, deletes the user's media. Media is the
    bulk of the storage, so history-only runs free very little.
    """
    try:
        return await container.get_retention_service().purge_room(
            bundle_id, retention_days, include_media
        )
    except BundleNotFoundException as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        ) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except SynapseUnavailableException as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/purges", tags=["retention"])
async def purge_all(
    retention_days: int | None = Query(None, description="Override the default window"),
    include_media: bool = Query(
        True, description="Also delete media files, which is what frees disk"
    ),
) -> dict:
    """Reclaim storage across every redeemed, non-revoked sync room."""
    try:
        started = await container.get_retention_service().purge_all(retention_days, include_media)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return {"started": len(started), "purges": started}


@router.get("/purges", tags=["retention"])
async def list_purges(bundle_id: str | None = Query(None)) -> dict:
    """List purge runs, newest first."""
    return {"purges": await container.get_repository().list_purges(bundle_id)}


@router.get("/purges/{purge_id}", tags=["retention"])
async def get_purge_status(purge_id: str) -> dict:
    """Poll Synapse for a purge's current status and persist it."""
    try:
        current = await container.get_retention_service().refresh_purge_status(purge_id)
    except SynapseUnavailableException as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    return {"purge_id": purge_id, "status": current}
