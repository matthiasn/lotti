"""Balance query service"""

import logging
from decimal import Decimal

from ..core.constants import CURRENCY_PRECISION
from ..core.exceptions import AccountNotFoundException
from ..core.interfaces import IBalanceService, ITigerBeetleClient

logger = logging.getLogger(__name__)


class BalanceService(IBalanceService):
    """Service for querying account balances"""

    def __init__(self, tigerbeetle_client: ITigerBeetleClient):
        """
        Initialize balance service

        Args:
            tigerbeetle_client: TigerBeetle client instance
        """
        self.client = tigerbeetle_client

    async def get_balance(self, user_id: str) -> Decimal:
        """
        Get current balance for a user

        Args:
            user_id: User identifier

        Returns:
            Current balance in USD

        Raises:
            AccountNotFoundException: If account doesn't exist
        """
        logger.debug(f"Getting balance for user {user_id}")

        account_id = self.client.user_id_to_account_id(user_id)

        try:
            balance_cents = await self.client.get_account_balance(account_id)
            balance_usd = Decimal(balance_cents) / CURRENCY_PRECISION

            logger.debug(f"User {user_id} balance: ${balance_usd}")
            return balance_usd

        except AccountNotFoundException:
            logger.warning(f"Account not found for user {user_id}")
            raise
