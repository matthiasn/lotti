"""FastAPI routes for the matrix provisioning service."""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query, status

from ..container import container
from ..core.constants import DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE
from ..core.exceptions import (
    BundleNotFoundException,
    InvalidBundleStateException,
    SynapseUnavailableException,
    UsernameAlreadyProvisionedException,
)
from ..core.models import (
    BundleEvent,
    BundleStatus,
    CreateBundleRequest,
    CreateBundleResponse,
    PaymentStatus,
    ProvisionedUser,
    ProvisionedUserListResponse,
    StatsResponse,
    UpdateUserRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter()


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
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc


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
    return ProvisionedUserListResponse(
        users=users, total=total, page=page, page_size=page_size
    )


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


@router.get(
    "/bundles/{bundle_id}/events", response_model=list[BundleEvent], tags=["bundles"]
)
async def get_bundle_events(bundle_id: str) -> list[BundleEvent]:
    """Return a bundle's audit trail, oldest first."""
    repository = container.get_repository()
    if await repository.get(bundle_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Unknown bundle {bundle_id}"
        )
    return await repository.get_events(bundle_id)


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
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=str(exc)
        ) from exc


@router.post(
    "/bundles/{bundle_id}/revoke", response_model=ProvisionedUser, tags=["bundles"]
)
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
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------


@router.get("/stats", response_model=StatsResponse, tags=["stats"])
async def get_stats(
    signup_history_days: int = Query(90, ge=1, le=730)
) -> StatsResponse:
    """Aggregate counts for the admin dashboard."""
    return await container.get_repository().get_stats(signup_history_days)


@router.get("/bundles/{bundle_id}/usage", tags=["stats"])
async def get_usage(bundle_id: str) -> dict:
    """Fetch live per-user activity and media usage from the Synapse admin API."""
    user = await container.get_repository().get(bundle_id)
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

    return {
        "bundle_id": bundle_id,
        "user_mxid": user.user_mxid,
        "device_count": activity.device_count,
        "last_seen_ts": activity.last_seen_ts,
        "deactivated": activity.deactivated,
        "media_count": media.media_count,
        "media_length_bytes": media.media_length_bytes,
        "active_days": user.active_days,
    }


# ---------------------------------------------------------------------------
# Retention
# ---------------------------------------------------------------------------


@router.post("/bundles/{bundle_id}/purge", tags=["retention"])
async def purge_room(
    bundle_id: str,
    retention_days: int | None = Query(
        None, description="Override the default retention window"
    ),
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
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    except SynapseUnavailableException as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc


@router.post("/purges", tags=["retention"])
async def purge_all(
    retention_days: int | None = Query(None, description="Override the default window"),
    include_media: bool = Query(
        True, description="Also delete media files, which is what frees disk"
    ),
) -> dict:
    """Reclaim storage across every redeemed, non-revoked sync room."""
    try:
        started = await container.get_retention_service().purge_all(
            retention_days, include_media
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
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
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)
        ) from exc
    return {"purge_id": purge_id, "status": current}
