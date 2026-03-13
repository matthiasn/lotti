"""Billing and transaction service"""

from __future__ import annotations

import logging
from decimal import Decimal

from ..core.constants import CURRENCY_PRECISION, SYSTEM_ACCOUNT_ID
from ..core.exceptions import (
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)
from ..core.interfaces import IBillingService, ITransactionLogService, ITigerBeetleClient

logger = logging.getLogger(__name__)


class BillingService(IBillingService):
    """Service for billing operations (top-up and bill)"""

    def __init__(
        self,
        tigerbeetle_client: ITigerBeetleClient,
        transaction_log: ITransactionLogService | None = None,
    ):
        """
        Initialize billing service

        Args:
            tigerbeetle_client: TigerBeetle client instance
            transaction_log: Optional transaction log for recording transactions
        """
        self.client = tigerbeetle_client
        self.transaction_log = transaction_log
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
            # Create system account with zero balance
            # System account allows overdrafts for "minting" credits
            logger.info("Creating system account")
            await self.client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)
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

            # Log the transaction (best-effort; transfer is already committed)
            if self.transaction_log is not None:
                try:
                    await self.transaction_log.log_transaction(
                        user_id, "topup", amount, new_balance
                    )
                except Exception:
                    logger.exception("Failed to log top-up transaction for user %s", user_id)

            return new_balance

        except AccountNotFoundException:
            logger.warning(f"Account not found for user {user_id}")
            raise

    async def bill(self, user_id: str, amount: Decimal, description: str | None = None) -> Decimal:
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

        # Transfer from user to system (debit user account)
        # TigerBeetle will atomically check and enforce balance constraints
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

            # Log the transaction (best-effort; transfer is already committed)
            if self.transaction_log is not None:
                try:
                    await self.transaction_log.log_transaction(
                        user_id, "bill", amount, new_balance, description
                    )
                except Exception:
                    logger.exception("Failed to log bill transaction for user %s", user_id)

            return new_balance

        except (AccountNotFoundException, InsufficientBalanceException):
            logger.warning(f"Billing failed for user {user_id}")
            raise
