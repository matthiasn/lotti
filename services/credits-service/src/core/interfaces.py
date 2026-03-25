"""Service interfaces for dependency injection"""

from __future__ import annotations

from abc import ABC, abstractmethod
from decimal import Decimal


class ITigerBeetleClient(ABC):
    """Interface for TigerBeetle client operations"""

    @abstractmethod
    async def connect(self) -> None:
        """Connect to TigerBeetle"""
        pass

    @abstractmethod
    async def disconnect(self) -> None:
        """Disconnect from TigerBeetle"""
        pass

    @abstractmethod
    async def create_account(self, account_id: int, user_id: str, is_system_account: bool = False) -> None:
        """Create a new account in TigerBeetle with zero balance"""
        pass

    @abstractmethod
    async def get_account_balance(self, account_id: int) -> int:
        """Get account balance in microcents"""
        pass

    @abstractmethod
    async def create_transfer(
        self,
        transfer_id: int,
        debit_account_id: int,
        credit_account_id: int,
        amount_microcents: int,
    ) -> None:
        """Create a transfer between accounts"""
        pass

    @abstractmethod
    def user_id_to_account_id(self, user_id: str) -> int:
        """Convert user_id to TigerBeetle account_id"""
        pass

    @abstractmethod
    def generate_transfer_id(self) -> int:
        """Generate a unique transfer ID"""
        pass


class IAccountService(ABC):
    """Interface for account management"""

    @abstractmethod
    async def create_account(self, user_id: str, initial_balance: Decimal | None = None) -> tuple[int, Decimal]:
        """
        Create a new account

        Args:
            user_id: User identifier
            initial_balance: Initial balance in USD (defaults to 0.00)

        Returns:
            Tuple of (account_id, balance)
        """
        pass

    @abstractmethod
    async def account_exists(self, user_id: str) -> bool:
        """Check if an account exists"""
        pass


class IBalanceService(ABC):
    """Interface for balance queries"""

    @abstractmethod
    async def get_balance(self, user_id: str) -> Decimal:
        """Get current balance for a user"""
        pass


class IBillingService(ABC):
    """Interface for billing operations"""

    @abstractmethod
    async def top_up(self, user_id: str, amount: Decimal) -> Decimal:
        """
        Add credits to an account

        Returns:
            New balance
        """
        pass

    @abstractmethod
    async def top_up_microcents(self, user_id: str, amount_microcents: int) -> Decimal:
        """
        Add credits to an account using exact internal units.

        Returns:
            New balance
        """
        pass

    @abstractmethod
    async def bill(self, user_id: str, amount: Decimal) -> Decimal:
        """
        Bill an account

        Returns:
            New balance
        """
        pass

    @abstractmethod
    async def bill_microcents(self, user_id: str, amount_microcents: int) -> Decimal:
        """
        Bill an account using exact internal units.

        Returns:
            New balance
        """
        pass


class IUserRegistryService(ABC):
    """Interface for user registry operations"""

    @abstractmethod
    async def register_user(self, user_id: str, display_name: str | None = None) -> None:
        """Register a user in the registry"""
        pass

    @abstractmethod
    async def get_user(self, user_id: str) -> dict | None:
        """Get user info by ID. Returns dict with user_id, display_name, created_at or None."""
        pass

    @abstractmethod
    async def list_users(self, page: int = 1, page_size: int = 20) -> tuple[list[dict], int]:
        """List users with pagination. Returns (users, total_count)."""
        pass

    @abstractmethod
    async def user_exists(self, user_id: str) -> bool:
        """Check if a user is registered"""
        pass


class ITransactionLogService(ABC):
    """Interface for transaction log operations"""

    @abstractmethod
    async def log_transaction(
        self,
        user_id: str,
        tx_type: str,
        amount: Decimal,
        balance_after: Decimal,
        description: str | None = None,
    ) -> None:
        """Log a transaction"""
        pass

    @abstractmethod
    async def get_transactions(
        self, user_id: str, page: int = 1, page_size: int = 20
    ) -> tuple[list[dict], int]:
        """Get transactions for a user with pagination. Returns (transactions, total_count)."""
        pass
