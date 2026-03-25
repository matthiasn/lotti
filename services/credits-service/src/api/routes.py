"""API routes for credits service"""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from shared.auth import AuthContext, require_admin_api_key, require_internal_or_admin_api_key

from ..container import container
from ..core.exceptions import (
    AccountAlreadyExistsException,
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)
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
    TransactionListResponse,
    TransactionRecord,
    UserInfo,
    UserListResponse,
)
from ..core.money import microcents_to_usd, usd_to_microcents

logger = logging.getLogger(__name__)

router = APIRouter()


class Paging:
    """FastAPI dependency for clamped pagination parameters"""

    def __init__(self, page: int = 1, page_size: int = 20):
        self.page = max(1, page)
        self.page_size = max(1, min(100, page_size))


@router.get("/health", response_model=dict[str, str])
async def health_check():
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
async def create_account(
    request: AccountCreateRequest,
    _: AuthContext = Depends(require_admin_api_key),
):
    """
    Create a new account for a user

    Args:
        request: Account creation request

    Returns:
        Account information with balance

    Raises:
        409: Account already exists
        500: Internal server error
    """
    try:
        account_service = container.get_account_service()
        account_id, balance = await account_service.create_account(request.user_id, request.initial_balance)

        return AccountCreateResponse(account_id=account_id, user_id=request.user_id, balance=balance)

    except AccountAlreadyExistsException as e:
        logger.warning(f"Account creation failed: {e}")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        logger.exception("Error creating account")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


@router.post(
    "/balance",
    response_model=BalanceResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Account not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def get_balance(
    request: BalanceRequest,
    _: AuthContext = Depends(require_admin_api_key),
):
    """
    Get account balance

    Args:
        request: Balance query request

    Returns:
        Current balance

    Raises:
        404: Account not found
        500: Internal server error
    """
    try:
        balance_service = container.get_balance_service()
        balance = await balance_service.get_balance(request.user_id)

        return BalanceResponse(user_id=request.user_id, balance=balance)

    except AccountNotFoundException as e:
        logger.warning(f"Balance query failed: {e}")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        logger.exception("Error getting balance")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


@router.post(
    "/topup",
    response_model=TopUpResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid amount"},
        404: {"model": ErrorResponse, "description": "Account not found"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def top_up(
    request: TopUpRequest,
    _: AuthContext = Depends(require_internal_or_admin_api_key),
):
    """
    Add credits to an account

    Args:
        request: Top-up request

    Returns:
        Updated balance information

    Raises:
        400: Invalid amount
        404: Account not found
        500: Internal server error
    """
    try:
        billing_service = container.get_billing_service()
        amount_microcents = (
            request.amount_microcents
            if request.amount_microcents is not None
            else usd_to_microcents(request.amount)
        )
        new_balance = await billing_service.top_up_microcents(request.user_id, amount_microcents)

        return TopUpResponse(
            user_id=request.user_id,
            amount_added=microcents_to_usd(amount_microcents),
            new_balance=new_balance,
        )

    except InvalidAmountException as e:
        logger.warning(f"Top-up failed: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except AccountNotFoundException as e:
        logger.warning(f"Top-up failed: {e}")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        logger.exception("Error processing top-up")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


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
async def bill(
    request: BillRequest,
    _: AuthContext = Depends(require_internal_or_admin_api_key),
):
    """
    Bill an account (deduct credits)

    Args:
        request: Bill request

    Returns:
        Updated balance information

    Raises:
        400: Invalid amount
        402: Insufficient balance
        404: Account not found
        500: Internal server error
    """
    try:
        billing_service = container.get_billing_service()
        amount_microcents = (
            request.amount_microcents
            if request.amount_microcents is not None
            else usd_to_microcents(request.amount)
        )
        new_balance = await billing_service.bill_microcents(request.user_id, amount_microcents)

        return BillResponse(
            user_id=request.user_id,
            amount_billed=microcents_to_usd(amount_microcents),
            new_balance=new_balance,
        )

    except InvalidAmountException as e:
        logger.warning(f"Billing failed: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except InsufficientBalanceException as e:
        logger.warning(f"Billing failed: {e}")
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=str(e))
    except AccountNotFoundException as e:
        logger.warning(f"Billing failed: {e}")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        logger.exception("Error processing bill")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


@router.get("/users", response_model=UserListResponse)
async def list_users(
    paging: Paging = Depends(),
    _: AuthContext = Depends(require_admin_api_key),
):
    """List all registered users with pagination"""
    try:
        user_registry = container.get_user_registry()
        balance_service = container.get_balance_service()

        users, total = await user_registry.list_users(page=paging.page, page_size=paging.page_size)

        # Fetch balances concurrently to avoid N+1 sequential lookups
        async def _get_balance(uid: str):
            try:
                return await balance_service.get_balance(uid)
            except AccountNotFoundException:
                return None

        balances = await asyncio.gather(*[_get_balance(u["user_id"]) for u in users])

        user_infos = [
            UserInfo(
                user_id=user["user_id"],
                display_name=user.get("display_name"),
                created_at=user["created_at"],
                balance=balance,
            )
            for user, balance in zip(users, balances)
        ]

        return UserListResponse(
            users=user_infos,
            total=total,
            page=paging.page,
            page_size=paging.page_size,
        )

    except Exception:
        logger.exception("Error listing users")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


@router.get(
    "/users/{user_id}",
    response_model=UserInfo,
    responses={404: {"model": ErrorResponse, "description": "User not found"}},
)
async def get_user(
    user_id: str,
    _: AuthContext = Depends(require_admin_api_key),
):
    """Get user details including balance"""
    try:
        user_registry = container.get_user_registry()
        user = await user_registry.get_user(user_id)

        if user is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User '{user_id}' not found",
            )

        balance = None
        try:
            balance_service = container.get_balance_service()
            balance = await balance_service.get_balance(user_id)
        except AccountNotFoundException:
            pass

        return UserInfo(
            user_id=user["user_id"],
            display_name=user.get("display_name"),
            created_at=user["created_at"],
            balance=balance,
        )

    except HTTPException:
        raise
    except Exception:
        logger.exception("Error getting user")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


@router.get(
    "/users/{user_id}/transactions",
    response_model=TransactionListResponse,
    responses={404: {"model": ErrorResponse, "description": "User not found"}},
)
async def get_transactions(
    user_id: str,
    paging: Paging = Depends(),
    _: AuthContext = Depends(require_admin_api_key),
):
    """Get transaction history for a user"""
    try:
        user_registry = container.get_user_registry()
        if not await user_registry.user_exists(user_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User '{user_id}' not found",
            )

        transaction_log = container.get_transaction_log()
        transactions, total = await transaction_log.get_transactions(
            user_id, page=paging.page, page_size=paging.page_size
        )

        transaction_records = [
            TransactionRecord(
                id=tx["id"],
                user_id=tx["user_id"],
                type=tx["type"],
                amount=tx["amount"],
                description=tx.get("description"),
                balance_after=tx["balance_after"],
                created_at=tx["created_at"],
            )
            for tx in transactions
        ]

        return TransactionListResponse(
            transactions=transaction_records,
            total=total,
            page=paging.page,
            page_size=paging.page_size,
        )

    except HTTPException:
        raise
    except Exception:
        logger.exception("Error getting transactions")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )
