"""Billing and transaction service"""

from __future__ import annotations

import asyncio
import logging
from decimal import Decimal

from ..core.constants import SYSTEM_ACCOUNT_ID
from ..core.exceptions import (
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)
from ..core.interfaces import IBillingService, ITransactionLogService, ITigerBeetleClient
from ..core.money import microcents_to_usd, usd_to_microcents

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
        self._system_account_lock = asyncio.Lock()

    async def _ensure_system_account(self) -> None:
        """Ensure system account exists"""
        if self._system_account_initialized:
            return

        async with self._system_account_lock:
            if self._system_account_initialized:
                return

            try:
                # Try to get balance to check if it exists
                await self.client.get_account_balance(SYSTEM_ACCOUNT_ID)
            except AccountNotFoundException:
                # Create system account with zero balance
                # System account allows overdrafts for "minting" credits
                logger.info("Creating system account")
                await self.client.create_account(
                    SYSTEM_ACCOUNT_ID,
                    "system",
                    is_system_account=True,
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

        return await self.top_up_microcents(user_id, usd_to_microcents(amount))

    async def top_up_microcents(self, user_id: str, amount_microcents: int) -> Decimal:
        """Add credits to an account using exact internal units."""
        if amount_microcents <= 0:
            raise InvalidAmountException("Top-up amount must be positive")

        amount_usd = microcents_to_usd(amount_microcents)
        logger.info(f"Top-up requested for ${amount_usd}")

        await self._ensure_system_account()

        account_id = self.client.user_id_to_account_id(user_id)

        # Transfer from system to user (credit user account)
        transfer_id = self.client.generate_transfer_id()

        try:
            await self.client.create_transfer(
                transfer_id=transfer_id,
                debit_account_id=SYSTEM_ACCOUNT_ID,  # System pays
                credit_account_id=account_id,  # User receives
                amount_microcents=amount_microcents,
            )

            # Get new balance
            new_balance_microcents = await self.client.get_account_balance(account_id)
            new_balance = microcents_to_usd(new_balance_microcents)

            logger.info(f"Top-up successful. New balance: ${new_balance}")

            # Log the transaction (best-effort; transfer is already committed)
            if self.transaction_log is not None:
                try:
                    await self.transaction_log.log_transaction(
                        user_id,
                        "topup",
                        amount_usd,
                        new_balance,
                    )
                except Exception:
                    logger.exception("Failed to log top-up transaction")

            return new_balance

        except AccountNotFoundException:
            logger.warning("Top-up failed: account not found")
            raise

    async def bill(self, user_id: str, amount: Decimal) -> Decimal:
        """
        Bill an account (deduct credits)

        Args:
            user_id: User identifier
            amount: Amount to bill in USD

        Returns:
            New balance in USD

        Raises:
            InvalidAmountException: If amount is invalid
            AccountNotFoundException: If account doesn't exist
            InsufficientBalanceException: If insufficient balance
        """
        if amount <= 0:
            raise InvalidAmountException("Bill amount must be positive")

        return await self.bill_microcents(user_id, usd_to_microcents(amount))

    async def bill_microcents(self, user_id: str, amount_microcents: int) -> Decimal:
        """Bill an account using exact internal units."""
        if amount_microcents <= 0:
            raise InvalidAmountException("Bill amount must be positive")

        amount_usd = microcents_to_usd(amount_microcents)
        logger.info(f"Billing requested for ${amount_usd}")

        await self._ensure_system_account()

        account_id = self.client.user_id_to_account_id(user_id)

        # Transfer from user to system (debit user account)
        # TigerBeetle will atomically check and enforce balance constraints
        transfer_id = self.client.generate_transfer_id()

        try:
            await self.client.create_transfer(
                transfer_id=transfer_id,
                debit_account_id=account_id,  # User pays
                credit_account_id=SYSTEM_ACCOUNT_ID,  # System receives
                amount_microcents=amount_microcents,
            )

            # Get new balance
            new_balance_microcents = await self.client.get_account_balance(account_id)
            new_balance = microcents_to_usd(new_balance_microcents)

            logger.info(f"Billing successful. New balance: ${new_balance}")

            # Log the transaction (best-effort; transfer is already committed)
            if self.transaction_log is not None:
                try:
                    await self.transaction_log.log_transaction(
                        user_id,
                        "bill",
                        amount_usd,
                        new_balance,
                    )
                except Exception:
                    logger.exception("Failed to log bill transaction")

            return new_balance

        except (AccountNotFoundException, InsufficientBalanceException):
            logger.warning("Billing failed")
            raise
