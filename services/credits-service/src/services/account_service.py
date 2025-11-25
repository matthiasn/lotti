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

        logger.info(f"Creating account for user {user_id} with balance ${initial_balance}")

        # Convert user_id to account_id
        account_id = self.client.user_id_to_account_id(user_id)

        try:
            # Create the account with zero balance (TigerBeetle requirement)
            await self.client.create_account(account_id, user_id)
            logger.info(f"Successfully created account {account_id} for user {user_id}")

            # If an initial balance is specified, transfer from system account
            if initial_balance > 0:
                from ..services.billing_service import SYSTEM_ACCOUNT_ID

                initial_balance_cents = int(initial_balance * CURRENCY_PRECISION)
                transfer_id = self.client.generate_transfer_id()
                await self.client.create_transfer(
                    transfer_id=transfer_id,
                    debit_account_id=SYSTEM_ACCOUNT_ID,
                    credit_account_id=account_id,
                    amount_cents=initial_balance_cents,
                )
                logger.info(f"Transferred initial balance of ${initial_balance} to account {account_id}")

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
