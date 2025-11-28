"""API routes for credits service"""

import logging
from typing import Dict

from fastapi import APIRouter, HTTPException, status

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
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health", response_model=Dict[str, str])
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
async def create_account(request: AccountCreateRequest):
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
async def get_balance(request: BalanceRequest):
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
async def top_up(request: TopUpRequest):
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
        new_balance = await billing_service.top_up(request.user_id, request.amount)

        return TopUpResponse(user_id=request.user_id, amount_added=request.amount, new_balance=new_balance)

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
async def bill(request: BillRequest):
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
        new_balance = await billing_service.bill(request.user_id, request.amount, request.description)

        return BillResponse(user_id=request.user_id, amount_billed=request.amount, new_balance=new_balance)

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
