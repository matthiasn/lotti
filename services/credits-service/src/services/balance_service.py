"""Balance query service"""

import logging
from decimal import Decimal

from ..core.exceptions import AccountNotFoundException
from ..core.interfaces import IBalanceService, ITigerBeetleClient
from ..core.money import microcents_to_usd

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
        logger.debug("Getting balance")

        account_id = self.client.user_id_to_account_id(user_id)

        try:
            balance_microcents = await self.client.get_account_balance(account_id)
            balance_usd = microcents_to_usd(balance_microcents)

            logger.debug(f"Balance lookup succeeded: ${balance_usd}")
            return balance_usd

        except AccountNotFoundException:
            logger.warning("Balance lookup failed: account not found")
            raise
