"""FastAPI routes for Paddle web checkout and its webhook."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Header, HTTPException, Request, status

from ..container import container
from ..core.exceptions import (
    AlreadySubscribedException,
    BundleClaimConflictException,
    BundleClaimRateLimitException,
    CheckoutSessionException,
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PaddleUnavailableException,
    PaddleWebhookException,
    PaymentPendingException,
    WebCheckoutRateLimitException,
)
from ..core.features import web_subscriptions_enabled
from ..core.models import (
    BundleDeliveryRequest,
    CheckoutSessionResponse,
    CheckoutSessionStatusRequest,
    CheckoutSessionStatusResponse,
    CreateCheckoutSessionRequest,
    PaidBundleResponse,
    PortalSessionRequest,
    PortalSessionResponse,
)
from .routes import bearer_secret

logger = logging.getLogger(__name__)

router = APIRouter()


def _require_web_subscriptions_enabled() -> None:
    if not web_subscriptions_enabled():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Web SYNC subscriptions are disabled",
        )


def _rate_limited(
    exc: WebCheckoutRateLimitException | BundleClaimRateLimitException,
) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=str(exc),
        headers={"Retry-After": str(exc.retry_after_seconds)},
    )


@router.post(
    "/client/web-checkout/sessions",
    response_model=CheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["web-checkout"],
)
async def create_checkout_session(
    request: CreateCheckoutSessionRequest,
    authorization: str = Header(default=""),
) -> CheckoutSessionResponse:
    """Authorize one checkout launch and return the page the app opens."""
    _require_web_subscriptions_enabled()
    try:
        created = await container.get_web_checkout_service().create_session(
            entitlement_id=request.entitlement_id,
            auth_secret=bearer_secret(authorization),
            plan=request.plan,
            claim_secret=request.claim_secret,
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except WebCheckoutRateLimitException as exc:
        raise _rate_limited(exc) from exc
    except InvalidSubscriptionProductException as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except AlreadySubscribedException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return CheckoutSessionResponse(**created.__dict__)


@router.post(
    "/client/web-checkout/session-status",
    response_model=CheckoutSessionStatusResponse,
    tags=["web-checkout"],
)
async def checkout_session_status(
    request: CheckoutSessionStatusRequest,
) -> CheckoutSessionStatusResponse:
    """Polled while the browser tab is open; the session id is the credential."""
    _require_web_subscriptions_enabled()
    try:
        state = await container.get_web_checkout_service().session_state(request.session_id)
    except CheckoutSessionException as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return CheckoutSessionStatusResponse(state=state.value)


@router.post(
    "/client/web-checkout/claims",
    response_model=PaidBundleResponse,
    tags=["web-checkout"],
)
async def claim_web_bundle(
    request: BundleDeliveryRequest,
    authorization: str = Header(default=""),
) -> PaidBundleResponse:
    """Provision on the first call after payment; redeliver the same escrow after."""
    _require_web_subscriptions_enabled()
    try:
        result = await container.get_web_checkout_service().claim(
            entitlement_id=request.entitlement_id,
            auth_secret=bearer_secret(authorization),
            claim_secret=request.claim_secret,
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except BundleClaimRateLimitException as exc:
        raise _rate_limited(exc) from exc
    except PaymentPendingException as exc:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=str(exc)) from exc
    except GooglePlayVerificationException as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=str(exc)
        ) from exc
    except BundleClaimConflictException as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return PaidBundleResponse(
        **result.delivery.__dict__,
        entitlement_state=result.subscription.entitlement_state.value,
    )


@router.post(
    "/client/web-checkout/portal-sessions",
    response_model=PortalSessionResponse,
    tags=["web-checkout"],
)
async def create_portal_session(
    request: PortalSessionRequest,
    authorization: str = Header(default=""),
) -> PortalSessionResponse:
    """Link to Paddle's portal, where the user cancels or changes payment."""
    _require_web_subscriptions_enabled()
    try:
        url = await container.get_web_checkout_service().portal_url(
            entitlement_id=request.entitlement_id,
            auth_secret=bearer_secret(authorization),
        )
    except EntitlementAuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except WebCheckoutRateLimitException as exc:
        raise _rate_limited(exc) from exc
    except PaymentPendingException as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except PaddleUnavailableException as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    return PortalSessionResponse(url=url)


@router.post("/webhooks/paddle", tags=["web-checkout"])
async def receive_paddle_webhook(
    request: Request,
    paddle_signature: str = Header(default=""),
) -> dict:
    """Apply a signed Paddle notification. Paddle retries anything but a 2xx."""
    _require_web_subscriptions_enabled()
    raw_body = await request.body()
    try:
        outcome = await container.get_paddle_subscription_service().handle_webhook(
            raw_body,
            paddle_signature,
        )
    except PaddleWebhookException as exc:
        logger.warning("Rejected Paddle webhook: %s", exc)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return {"outcome": outcome}
