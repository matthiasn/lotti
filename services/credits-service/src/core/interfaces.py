"""Service interfaces for dependency injection"""

from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Optional


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
    async def create_account(self, account_id: int, user_id: str) -> None:
        """Create a new account in TigerBeetle with zero balance"""
        pass

    @abstractmethod
    async def get_account_balance(self, account_id: int) -> int:
        """Get account balance in cents"""
        pass

    @abstractmethod
    async def create_transfer(
        self,
        transfer_id: int,
        debit_account_id: int,
        credit_account_id: int,
        amount_cents: int,
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
    async def create_account(self, user_id: str, initial_balance: Optional[Decimal] = None) -> tuple[int, Decimal]:
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
    async def bill(self, user_id: str, amount: Decimal, description: Optional[str] = None) -> Decimal:
        """
        Bill an account

        Returns:
            New balance
        """
        pass
