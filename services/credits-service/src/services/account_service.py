"""Account management service"""

import logging
from decimal import Decimal
from typing import Optional

from ..core.constants import CURRENCY_PRECISION
from ..core.exceptions import AccountAlreadyExistsException
from ..core.interfaces import IAccountService, ITigerBeetleClient

logger = logging.getLogger(__name__)


class AccountService(IAccountService):
    """Service for managing user accounts"""

    def __init__(self, tigerbeetle_client: ITigerBeetleClient):
        """
        Initialize account service

        Args:
            tigerbeetle_client: TigerBeetle client instance
        """
        self.client = tigerbeetle_client

    async def create_account(self, user_id: str, initial_balance: Optional[Decimal] = None) -> tuple[int, Decimal]:
        """
        Create a new account

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

        logger.info(f"Creating account for user {user_id} with balance ${initial_balance}")

        # Convert user_id to account_id
        account_id = self.client.user_id_to_account_id(user_id)

        # Convert USD to cents
        initial_balance_cents = int(initial_balance * CURRENCY_PRECISION)

        try:
            await self.client.create_account(account_id, user_id, initial_balance_cents)
            logger.info(f"Successfully created account {account_id} for user {user_id}")
            return account_id, initial_balance

        except AccountAlreadyExistsException:
            logger.warning(f"Account for user {user_id} already exists")
            raise

    async def account_exists(self, user_id: str) -> bool:
        """
        Check if an account exists

        Args:
            user_id: User identifier

        Returns:
            True if account exists, False otherwise
        """
        try:
            account_id = self.client.user_id_to_account_id(user_id)
            await self.client.get_account_balance(account_id)
            return True
        except Exception:
            return False
