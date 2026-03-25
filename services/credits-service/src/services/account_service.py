"""Account management service"""

from __future__ import annotations

import asyncio
import logging
from decimal import Decimal

from ..core.constants import SYSTEM_ACCOUNT_ID
from ..core.exceptions import AccountAlreadyExistsException, AccountNotFoundException
from ..core.interfaces import IAccountService, ITigerBeetleClient, IUserRegistryService
from ..core.money import usd_to_microcents

logger = logging.getLogger(__name__)


class AccountService(IAccountService):
    """Service for managing user accounts"""

    def __init__(
        self,
        tigerbeetle_client: ITigerBeetleClient,
        user_registry: IUserRegistryService | None = None,
    ):
        """
        Initialize account service

        Args:
            tigerbeetle_client: TigerBeetle client instance
            user_registry: Optional user registry for tracking user metadata
        """
        self.client = tigerbeetle_client
        self.user_registry = user_registry
        self._system_account_initialized = False
        self._system_account_lock = asyncio.Lock()

    async def _ensure_system_account(self) -> None:
        """Ensure the internal system account exists before minting credits."""
        if self._system_account_initialized:
            return

        async with self._system_account_lock:
            if self._system_account_initialized:
                return

            try:
                await self.client.get_account_balance(SYSTEM_ACCOUNT_ID)
            except AccountNotFoundException:
                logger.info("Creating system account")
                await self.client.create_account(
                    SYSTEM_ACCOUNT_ID,
                    "system",
                    is_system_account=True,
                )

            self._system_account_initialized = True

    async def create_account(self, user_id: str, initial_balance: Decimal | None = None) -> tuple[int, Decimal]:
        """
        Create a new account and set its initial balance

        Args:
            user_id: User identifier
            initial_balance: Initial balance in USD (defaults to 0.00)

        Returns:
            Tuple of (account_id, balance)

        Raises:
            AccountAlreadyExistsException: If account already exists
        """
        if initial_balance is None:
            initial_balance = Decimal("0.00")

        logger.info(f"Creating account with initial balance ${initial_balance}")

        # Convert user_id to account_id
        account_id = self.client.user_id_to_account_id(user_id)

        try:
            # Create the account with zero balance (TigerBeetle requirement)
            await self.client.create_account(account_id, user_id)
            logger.info("Successfully created account")

            # Register user in the user registry (best-effort; failure must not
            # roll back a successful TigerBeetle account creation)
            if self.user_registry is not None:
                try:
                    await self.user_registry.register_user(user_id)
                except Exception:
                    logger.exception(
                        "Failed to register user in registry; account was created successfully",
                    )

            # If an initial balance is specified, transfer from system account
            if initial_balance > 0:
                await self._ensure_system_account()
                initial_balance_microcents = usd_to_microcents(initial_balance)
                transfer_id = self.client.generate_transfer_id()
                await self.client.create_transfer(
                    transfer_id=transfer_id,
                    debit_account_id=SYSTEM_ACCOUNT_ID,
                    credit_account_id=account_id,
                    amount_microcents=initial_balance_microcents,
                )
                logger.info(f"Transferred initial balance of ${initial_balance} to account")

            return account_id, initial_balance

        except AccountAlreadyExistsException:
            logger.warning("Account already exists")
            raise

    async def account_exists(self, user_id: str) -> bool:
        """
        Check if an account exists

        Args:
            user_id: User identifier

        Returns:
            True if account exists, False otherwise

        Raises:
            TigerBeetleException: On database connection or other errors
        """
        try:
            account_id = self.client.user_id_to_account_id(user_id)
            await self.client.get_account_balance(account_id)
            return True
        except AccountNotFoundException:
            return False
