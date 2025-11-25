"""Billing and transaction service"""

import logging
from decimal import Decimal
from typing import Optional

from ..core.constants import CURRENCY_PRECISION
from ..core.exceptions import (
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)
from ..core.interfaces import IBillingService, ITigerBeetleClient

logger = logging.getLogger(__name__)

# System account for credits (acts as a bank)
SYSTEM_ACCOUNT_ID = 1


class BillingService(IBillingService):
    """Service for billing operations (top-up and bill)"""

    def __init__(self, tigerbeetle_client: ITigerBeetleClient):
        """
        Initialize billing service

        Args:
            tigerbeetle_client: TigerBeetle client instance
        """
        self.client = tigerbeetle_client
        self._system_account_initialized = False

    async def _ensure_system_account(self) -> None:
        """Ensure system account exists"""
        if self._system_account_initialized:
            return

        try:
            # Try to get balance to check if it exists
            await self.client.get_account_balance(SYSTEM_ACCOUNT_ID)
            self._system_account_initialized = True
        except AccountNotFoundException:
            # Create system account with zero balance initially
            # TigerBeetle requires accounts to be created with zero balance
            logger.info("Creating system account")
            await self.client.create_account(
                SYSTEM_ACCOUNT_ID,
                "system",
                initial_balance_cents=0,  # Must start at zero
            )
            self._system_account_initialized = True

    async def top_up(self, user_id: str, amount: Decimal) -> Decimal:
        """
        Add credits to an account

        Args:
            user_id: User identifier
            amount: Amount to add in USD

        Returns:
            New balance in USD

        Raises:
            InvalidAmountException: If amount is invalid
            AccountNotFoundException: If account doesn't exist
        """
        if amount <= 0:
            raise InvalidAmountException("Top-up amount must be positive")

        logger.info(f"Top-up ${amount} for user {user_id}")

        await self._ensure_system_account()

        account_id = self.client.user_id_to_account_id(user_id)
        amount_cents = int(amount * CURRENCY_PRECISION)

        # Transfer from system to user (credit user account)
        transfer_id = self.client.generate_transfer_id()

        try:
            await self.client.create_transfer(
                transfer_id=transfer_id,
                debit_account_id=SYSTEM_ACCOUNT_ID,  # System pays
                credit_account_id=account_id,  # User receives
                amount_cents=amount_cents,
            )

            # Get new balance
            new_balance_cents = await self.client.get_account_balance(account_id)
            new_balance = Decimal(new_balance_cents) / CURRENCY_PRECISION

            logger.info(f"Top-up successful. New balance for {user_id}: ${new_balance}")
            return new_balance

        except AccountNotFoundException:
            logger.warning(f"Account not found for user {user_id}")
            raise

    async def bill(self, user_id: str, amount: Decimal, description: Optional[str] = None) -> Decimal:
        """
        Bill an account (deduct credits)

        Args:
            user_id: User identifier
            amount: Amount to bill in USD
            description: Optional description of the charge

        Returns:
            New balance in USD

        Raises:
            InvalidAmountException: If amount is invalid
            AccountNotFoundException: If account doesn't exist
            InsufficientBalanceException: If insufficient balance
        """
        if amount <= 0:
            raise InvalidAmountException("Bill amount must be positive")

        desc_str = f" ({description})" if description else ""
        logger.info(f"Billing ${amount} for user {user_id}{desc_str}")

        await self._ensure_system_account()

        account_id = self.client.user_id_to_account_id(user_id)
        amount_cents = int(amount * CURRENCY_PRECISION)

        # Check current balance
        current_balance_cents = await self.client.get_account_balance(account_id)
        if current_balance_cents < amount_cents:
            current_balance = Decimal(current_balance_cents) / CURRENCY_PRECISION
            raise InsufficientBalanceException(
                f"Insufficient balance. Current: ${current_balance}, Required: ${amount}"
            )

        # Transfer from user to system (debit user account)
        transfer_id = self.client.generate_transfer_id()

        try:
            await self.client.create_transfer(
                transfer_id=transfer_id,
                debit_account_id=account_id,  # User pays
                credit_account_id=SYSTEM_ACCOUNT_ID,  # System receives
                amount_cents=amount_cents,
            )

            # Get new balance
            new_balance_cents = await self.client.get_account_balance(account_id)
            new_balance = Decimal(new_balance_cents) / CURRENCY_PRECISION

            logger.info(f"Billing successful. New balance for {user_id}: ${new_balance}")
            return new_balance

        except AccountNotFoundException:
            logger.warning(f"Account not found for user {user_id}")
            raise
