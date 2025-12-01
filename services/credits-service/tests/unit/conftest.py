"""Fixtures for unit tests with mocked TigerBeetle client"""

import uuid

import pytest

from src.core.exceptions import AccountAlreadyExistsException, AccountNotFoundException
from src.core.interfaces import ITigerBeetleClient


class MockTigerBeetleClient(ITigerBeetleClient):
    """Mock TigerBeetle client for unit testing"""

    def __init__(self):
        self._accounts: dict[int, dict] = {}
        self._transfer_counter = 0

    async def connect(self) -> None:
        pass

    async def disconnect(self) -> None:
        pass

    async def create_account(self, account_id: int, user_id: str, is_system_account: bool = False) -> None:
        if account_id in self._accounts:
            raise AccountAlreadyExistsException(f"Account {account_id} already exists")
        self._accounts[account_id] = {
            "user_id": user_id,
            "balance_cents": 0,
            "is_system_account": is_system_account,
        }

    async def get_account_balance(self, account_id: int) -> int:
        if account_id not in self._accounts:
            raise AccountNotFoundException(f"Account {account_id} not found")
        return self._accounts[account_id]["balance_cents"]

    async def create_transfer(
        self,
        transfer_id: int,
        debit_account_id: int,
        credit_account_id: int,
        amount_cents: int,
    ) -> None:
        if debit_account_id not in self._accounts:
            raise AccountNotFoundException(f"Debit account {debit_account_id} not found")
        if credit_account_id not in self._accounts:
            raise AccountNotFoundException(f"Credit account {credit_account_id} not found")

        debit_account = self._accounts[debit_account_id]
        credit_account = self._accounts[credit_account_id]

        # System accounts can go negative (overdraft allowed for minting)
        if not debit_account["is_system_account"]:
            from src.core.exceptions import InsufficientBalanceException

            if debit_account["balance_cents"] < amount_cents:
                raise InsufficientBalanceException(
                    f"Insufficient balance: {debit_account['balance_cents']} < {amount_cents}"
                )

        debit_account["balance_cents"] -= amount_cents
        credit_account["balance_cents"] += amount_cents

    def user_id_to_account_id(self, user_id: str) -> int:
        # Simple hash-based conversion for testing
        return abs(hash(user_id)) % (10**18)

    def generate_transfer_id(self) -> int:
        self._transfer_counter += 1
        return self._transfer_counter


@pytest.fixture
def mock_client():
    """Provide a fresh mock TigerBeetle client for each test"""
    return MockTigerBeetleClient()


@pytest.fixture
def user_id():
    """Generate a unique user ID for each test"""
    return f"test_user_{uuid.uuid4().hex[:16]}"
