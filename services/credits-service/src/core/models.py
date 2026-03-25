"""Core domain models"""

from __future__ import annotations

from decimal import Decimal

from pydantic import BaseModel, Field, field_validator, model_validator


class AccountCreateRequest(BaseModel):
    """Request to create a new account"""

    user_id: str = Field(..., description="Unique user identifier")
    initial_balance: Decimal = Field(default=Decimal("0.00"), description="Initial balance in USD", ge=0)

    @field_validator("initial_balance")
    @classmethod
    def validate_initial_balance(cls, v: Decimal) -> Decimal:
        """Ensure initial balance is non-negative"""
        if v < 0:
            raise ValueError("Initial balance must be non-negative")
        return v


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
    amount: Decimal | None = Field(default=None, description="Amount to add in USD", gt=0)
    amount_microcents: int | None = Field(
        default=None,
        description="Exact internal billing amount in microcents",
        gt=0,
    )

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: Decimal | None) -> Decimal | None:
        """Ensure amount is positive"""
        if v is None:
            return v
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v

    @model_validator(mode="after")
    def validate_amount_source(self) -> "TopUpRequest":
        """Require exactly one amount representation."""
        if (self.amount is None) == (self.amount_microcents is None):
            raise ValueError("Provide exactly one of amount or amount_microcents")
        return self


class TopUpResponse(BaseModel):
    """Response after adding credits"""

    user_id: str = Field(..., description="User identifier")
    amount_added: Decimal = Field(..., description="Amount added in USD")
    new_balance: Decimal = Field(..., description="New balance in USD")


class BillRequest(BaseModel):
    """Request to bill an account"""

    user_id: str = Field(..., description="User identifier")
    amount: Decimal | None = Field(default=None, description="Amount to bill in USD", gt=0)
    amount_microcents: int | None = Field(
        default=None,
        description="Exact internal billing amount in microcents",
        gt=0,
    )
    request_id: str | None = Field(None, description="Opaque request identifier for traceability")

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: Decimal | None) -> Decimal | None:
        """Ensure amount is positive"""
        if v is None:
            return v
        if v <= 0:
            raise ValueError("Amount must be positive")
        return v

    @model_validator(mode="after")
    def validate_amount_source(self) -> "BillRequest":
        """Require exactly one amount representation."""
        if (self.amount is None) == (self.amount_microcents is None):
            raise ValueError("Provide exactly one of amount or amount_microcents")
        return self


class BillResponse(BaseModel):
    """Response after billing an account"""

    user_id: str = Field(..., description="User identifier")
    amount_billed: Decimal = Field(..., description="Amount billed in USD")
    new_balance: Decimal = Field(..., description="New balance in USD")


class ErrorResponse(BaseModel):
    """Standard error response"""

    error: str = Field(..., description="Error message")
    detail: str | None = Field(None, description="Additional error details")


class UserInfo(BaseModel):
    """User information"""

    user_id: str = Field(..., description="Unique user identifier (UUID)")
    display_name: str | None = Field(None, description="User display name")
    created_at: str = Field(..., description="ISO 8601 creation timestamp")
    balance: Decimal | None = Field(None, description="Current balance in USD")


class UserListResponse(BaseModel):
    """Paginated list of users"""

    users: list[UserInfo] = Field(..., description="List of users")
    total: int = Field(..., description="Total number of users")
    page: int = Field(..., description="Current page number")
    page_size: int = Field(..., description="Number of users per page")


class TransactionRecord(BaseModel):
    """A single transaction record"""

    id: int = Field(..., description="Transaction ID")
    user_id: str = Field(..., description="User identifier")
    type: str = Field(..., description="Transaction type: 'topup' or 'bill'")
    amount: Decimal = Field(..., description="Transaction amount in USD")
    description: str | None = Field(None, description="Transaction description")
    balance_after: Decimal = Field(..., description="Balance after transaction in USD")
    created_at: str = Field(..., description="ISO 8601 timestamp")


class TransactionListResponse(BaseModel):
    """Paginated list of transactions"""

    transactions: list[TransactionRecord] = Field(..., description="List of transactions")
    total: int = Field(..., description="Total number of transactions")
    page: int = Field(..., description="Current page number")
    page_size: int = Field(..., description="Number of transactions per page")
