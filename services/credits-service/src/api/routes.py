"""API routes for credits service"""

from typing import Dict

from fastapi import APIRouter, status

from ..container import container
from ..core.models import (
    AccountCreateRequest,
    AccountCreateResponse,
    BalanceRequest,
    BalanceResponse,
    BillRequest,
    BillResponse,
    ErrorResponse,
    TopUpRequest,
    TopUpResponse,
)

router = APIRouter()


@router.get("/health", response_model=Dict[str, str])
async def health_check() -> Dict[str, str]:
    """Health check endpoint"""
    return {"status": "healthy"}


@router.post(
    "/accounts",
    response_model=AccountCreateResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        409: {"model": ErrorResponse, "description": "Account already exists"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def create_account(request: AccountCreateRequest) -> AccountCreateResponse:
    """Create a new account for a user."""
    account_service = container.get_account_service()
    account_id, balance = await account_service.create_account(request.user_id, request.initial_balance)
    return AccountCreateResponse(account_id=account_id, user_id=request.user_id, balance=balance)


@router.post(
    "/balance",
    response_model=BalanceResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Account not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def get_balance(request: BalanceRequest) -> BalanceResponse:
    """Get account balance."""
    balance_service = container.get_balance_service()
    balance = await balance_service.get_balance(request.user_id)
    return BalanceResponse(user_id=request.user_id, balance=balance)


@router.post(
    "/topup",
    response_model=TopUpResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid amount"},
        404: {"model": ErrorResponse, "description": "Account not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def top_up(request: TopUpRequest) -> TopUpResponse:
    """Add credits to an account."""
    billing_service = container.get_billing_service()
    new_balance = await billing_service.top_up(request.user_id, request.amount)
    return TopUpResponse(user_id=request.user_id, amount_added=request.amount, new_balance=new_balance)


@router.post(
    "/bill",
    response_model=BillResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid amount"},
        402: {"model": ErrorResponse, "description": "Insufficient balance"},
        404: {"model": ErrorResponse, "description": "Account not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def bill(request: BillRequest) -> BillResponse:
    """Bill an account (deduct credits)."""
    billing_service = container.get_billing_service()
    new_balance = await billing_service.bill(request.user_id, request.amount, request.description)
    return BillResponse(user_id=request.user_id, amount_billed=request.amount, new_balance=new_balance)
