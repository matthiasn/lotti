"""TigerBeetle client implementation"""

import hashlib
import logging
import uuid
from typing import Optional

from tigerbeetle import (
    Account,
    AccountFlags,
    ClientAsync,
    CreateAccountResult,
    CreateTransferResult,
    Transfer,
    TransferFlags,
)

from ..core.constants import (
    LEDGER_ID,
    ACCOUNT_CODE_USER,
)
from ..core.exceptions import (
    TigerBeetleException,
    DatabaseConnectionException,
    AccountAlreadyExistsException,
    AccountNotFoundException,
    InsufficientBalanceException,
)
from ..core.interfaces import ITigerBeetleClient

logger = logging.getLogger(__name__)


class TigerBeetleClient(ITigerBeetleClient):
    """TigerBeetle client for ledger operations"""

    def __init__(self, cluster_id: int = 0, addresses: str = "3000"):
        """
        Initialize TigerBeetle client

        Args:
            cluster_id: TigerBeetle cluster ID
            addresses: TigerBeetle server addresses (e.g., "3000" or "localhost:3000")
        """
        self.cluster_id = cluster_id
        self.addresses = addresses
        self._client: Optional[ClientAsync] = None

    async def connect(self) -> None:
        """Connect to TigerBeetle"""
        try:
            logger.info(f"Connecting to TigerBeetle at {self.addresses} (cluster {self.cluster_id})")
            self._client = ClientAsync(cluster_id=self.cluster_id, replica_addresses=self.addresses)
            logger.info("Successfully connected to TigerBeetle")
        except Exception as e:
            logger.error(f"Failed to connect to TigerBeetle: {e}")
            raise DatabaseConnectionException(f"Failed to connect to TigerBeetle: {e}") from e

    async def disconnect(self) -> None:
        """Disconnect from TigerBeetle"""
        if self._client:
            try:
                # close() returns None, no need to await
                self._client.close()
                logger.info("Disconnected from TigerBeetle")
            except Exception as e:
                logger.warning(f"Error during TigerBeetle disconnect: {e}")
            finally:
                self._client = None

    def _ensure_connected(self) -> ClientAsync:
        """Ensure client is connected and return the client"""
        if not self._client:
            raise DatabaseConnectionException("Not connected to TigerBeetle")
        return self._client

    def user_id_to_account_id(self, user_id: str) -> int:
        """
        Convert user_id string to a TigerBeetle account_id (128-bit integer)

        Uses SHA-256 hash to generate a deterministic account ID from user_id
        """
        # Hash the user_id to get a deterministic account ID
        hash_bytes = hashlib.sha256(user_id.encode()).digest()
        # Take first 16 bytes and convert to int (128-bit)
        account_id = int.from_bytes(hash_bytes[:16], byteorder="big")
        return account_id

    async def create_account(self, account_id: int, user_id: str, is_system_account: bool = False) -> None:
        """
        Create a new account in TigerBeetle

        Args:
            account_id: Unique account ID (128-bit integer)
            user_id: User identifier (for logging purposes)
            is_system_account: Whether this is the system account (allows overdrafts)

        Raises:
            AccountAlreadyExistsException: If account already exists
            TigerBeetleException: On other TigerBeetle errors

        Note:
            TigerBeetle requires accounts to be created with zero balance.
            Use create_transfer() to set an initial balance after creation.
            User accounts enforce DEBITS_MUST_NOT_EXCEED_CREDITS to prevent overdrafts.
        """
        client = self._ensure_connected()

        try:
            # TigerBeetle requires accounts to be created with zero balance
            # Initial balance must be set via transfers after creation

            # User accounts: Prevent overdrafts by enforcing debits <= credits
            # System account: Allow unlimited debits for "minting" credits
            if is_system_account:
                flags = AccountFlags.NONE  # System can overdraft (mint credits)
            else:
                flags = AccountFlags.DEBITS_MUST_NOT_EXCEED_CREDITS  # Users cannot overdraft

            account = Account(
                id=account_id,
                debits_pending=0,
                debits_posted=0,
                credits_pending=0,
                credits_posted=0,  # Must be zero on creation
                user_data_128=0,  # Could store user metadata here
                user_data_64=0,
                user_data_32=0,
                ledger=LEDGER_ID,  # USD ledger
                code=ACCOUNT_CODE_USER,  # User account type
                flags=flags,
                timestamp=0,  # Let TigerBeetle set the timestamp
            )

            errors = await client.create_accounts([account])

            if errors:
                error = errors[0]
                if error.result in (
                    CreateAccountResult.exists,
                    CreateAccountResult.exists_with_different_flags,
                ):
                    logger.warning(f"Account {account_id} already exists")
                    raise AccountAlreadyExistsException(f"Account for user {user_id} already exists")
                else:
                    logger.error(f"TigerBeetle error creating account: {error}")
                    raise TigerBeetleException(f"Failed to create account: {error}")

            logger.info(f"Created account {account_id} for user {user_id}")

        except (AccountAlreadyExistsException, TigerBeetleException):
            raise
        except Exception as e:
            logger.error(f"Unexpected error creating account: {e}")
            raise TigerBeetleException(f"Unexpected error creating account: {e}") from e

    async def get_account_balance(self, account_id: int) -> int:
        """
        Get account balance in cents

        Returns:
            Balance in cents (credits - debits)

        Raises:
            AccountNotFoundException: If account doesn't exist
            TigerBeetleException: On other errors
        """
        client = self._ensure_connected()

        try:
            accounts = await client.lookup_accounts([account_id])

            if not accounts:
                logger.warning(f"Account {account_id} not found")
                raise AccountNotFoundException(f"Account {account_id} not found")

            account = accounts[0]
            # Balance = credits - debits
            balance_cents = account.credits_posted - account.debits_posted

            logger.debug(f"Account {account_id} balance: {balance_cents} cents")
            return balance_cents

        except AccountNotFoundException:
            raise
        except Exception as e:
            logger.error(f"Error getting account balance: {e}")
            raise TigerBeetleException(f"Error getting account balance: {e}") from e

    async def create_transfer(
        self,
        transfer_id: int,
        debit_account_id: int,
        credit_account_id: int,
        amount_cents: int,
    ) -> None:
        """
        Create a transfer between accounts

        Args:
            transfer_id: Unique transfer ID
            debit_account_id: Account to debit (sender)
            credit_account_id: Account to credit (receiver)
            amount_cents: Amount in cents

        Raises:
            AccountNotFoundException: If either account doesn't exist
            InsufficientBalanceException: If debit account has insufficient balance
            TigerBeetleException: On other transfer errors
        """
        client = self._ensure_connected()

        try:
            transfer = Transfer(
                id=transfer_id,
                debit_account_id=debit_account_id,
                credit_account_id=credit_account_id,
                amount=amount_cents,
                pending_id=0,
                user_data_128=0,
                user_data_64=0,
                user_data_32=0,
                timeout=0,
                ledger=LEDGER_ID,
                code=1,  # Standard transfer code
                flags=TransferFlags.NONE,
                timestamp=0,
            )

            errors = await client.create_transfers([transfer])

            if errors:
                error = errors[0]
                if error.result in (
                    CreateTransferResult.debit_account_not_found,
                    CreateTransferResult.credit_account_not_found,
                ):
                    logger.warning(f"Account not found for transfer: {error}")
                    raise AccountNotFoundException("Account not found for transfer")
                elif error.result == CreateTransferResult.exceeds_credits:
                    logger.warning(f"Insufficient balance for transfer: {error}")
                    raise InsufficientBalanceException(f"Insufficient balance for account {debit_account_id}")
                else:
                    logger.error(f"TigerBeetle error creating transfer: {error}")
                    raise TigerBeetleException(f"Failed to create transfer: {error}")

            logger.info(
                f"Created transfer {transfer_id}: {amount_cents} cents from {debit_account_id} to {credit_account_id}"
            )

        except (TigerBeetleException, AccountNotFoundException, InsufficientBalanceException):
            raise
        except Exception as e:
            logger.error(f"Unexpected error creating transfer: {e}")
            raise TigerBeetleException(f"Unexpected error creating transfer: {e}") from e

    def generate_transfer_id(self) -> int:
        """Generate a unique 128-bit transfer ID using UUID4"""
        return uuid.uuid4().int
