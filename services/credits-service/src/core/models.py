"""Core domain models"""

from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field


class AccountCreateRequest(BaseModel):
    """Request to create a new account"""

    user_id: str = Field(..., description="Unique user identifier")
    initial_balance: Decimal = Field(default=Decimal("0.00"), description="Initial balance in USD", ge=0)


class AccountCreateResponse(BaseModel):
    """Response after creating an account"""

    account_id: int = Field(..., description="TigerBeetle account ID")
    user_id: str = Field(..., description="User identifier")
    balance: Decimal = Field(..., description="Current balance in USD")


class BalanceRequest(BaseModel):
    """Request to get account balance"""

    user_id: str = Field(..., description="User identifier")


class BalanceResponse(BaseModel):
    """Response with account balance"""

    user_id: str = Field(..., description="User identifier")
    balance: Decimal = Field(..., description="Current balance in USD")


class TopUpRequest(BaseModel):
    """Request to add credits to an account"""

    user_id: str = Field(..., description="User identifier")
    amount: Decimal = Field(..., description="Amount to add in USD", gt=0)


class TopUpResponse(BaseModel):
    """Response after adding credits"""

    user_id: str = Field(..., description="User identifier")
    amount_added: Decimal = Field(..., description="Amount added in USD")
    new_balance: Decimal = Field(..., description="New balance in USD")


class BillRequest(BaseModel):
    """Request to bill an account"""

    user_id: str = Field(..., description="User identifier")
    amount: Decimal = Field(..., description="Amount to bill in USD", gt=0)
    description: Optional[str] = Field(None, description="Description of the charge (e.g., 'Gemini API call')")


class BillResponse(BaseModel):
    """Response after billing an account"""

    user_id: str = Field(..., description="User identifier")
    amount_billed: Decimal = Field(..., description="Amount billed in USD")
    new_balance: Decimal = Field(..., description="New balance in USD")


class ErrorResponse(BaseModel):
    """Standard error response"""

    error: str = Field(..., description="Error message")
    detail: Optional[str] = Field(None, description="Additional error details")
