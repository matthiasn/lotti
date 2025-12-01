"""Unit tests for AccountService"""

from decimal import Decimal

import pytest

from src.core.constants import SYSTEM_ACCOUNT_ID
from src.core.exceptions import AccountAlreadyExistsException
from src.services.account_service import AccountService


@pytest.mark.unit
class TestAccountService:
    """Unit tests for AccountService business logic"""

    @pytest.fixture
    def account_service(self, mock_client):
        """Create AccountService with mock client"""
        return AccountService(mock_client)

    @pytest.fixture
    async def service_with_system_account(self, mock_client):
        """Create AccountService with system account already initialized"""
        # Pre-create system account for initial balance transfers
        await mock_client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)
        return AccountService(mock_client)

    async def test_create_account_with_zero_balance(self, account_service, mock_client, user_id):
        """Test creating account with default zero balance"""
        account_id, balance = await account_service.create_account(user_id)

        assert balance == Decimal("0.00")
        assert account_id == mock_client.user_id_to_account_id(user_id)

        # Verify account exists in mock
        stored_balance = await mock_client.get_account_balance(account_id)
        assert stored_balance == 0

    async def test_create_account_with_explicit_zero_balance(self, account_service, mock_client, user_id):
        """Test creating account with explicitly specified zero balance"""
        account_id, balance = await account_service.create_account(user_id, initial_balance=Decimal("0.00"))

        assert balance == Decimal("0.00")
        stored_balance = await mock_client.get_account_balance(account_id)
        assert stored_balance == 0

    async def test_create_account_with_initial_balance(self, service_with_system_account, mock_client, user_id):
        """Test creating account with initial balance triggers transfer from system"""
        initial_balance = Decimal("50.00")
        account_id, balance = await service_with_system_account.create_account(user_id, initial_balance=initial_balance)

        assert balance == initial_balance
        stored_balance = await mock_client.get_account_balance(account_id)
        assert stored_balance == 5000  # 50.00 * 100 cents

    async def test_create_account_with_fractional_balance(self, service_with_system_account, mock_client, user_id):
        """Test creating account with fractional initial balance"""
        initial_balance = Decimal("25.50")
        account_id, balance = await service_with_system_account.create_account(user_id, initial_balance=initial_balance)

        assert balance == initial_balance
        stored_balance = await mock_client.get_account_balance(account_id)
        assert stored_balance == 2550  # 25.50 * 100 cents

    async def test_create_duplicate_account_raises_exception(self, account_service, mock_client, user_id):
        """Test that creating duplicate account raises AccountAlreadyExistsException"""
        # Create account first time
        await account_service.create_account(user_id)

        # Try to create again
        with pytest.raises(AccountAlreadyExistsException):
            await account_service.create_account(user_id)

    async def test_account_exists_returns_true_for_existing_account(self, account_service, mock_client, user_id):
        """Test account_exists returns True for existing account"""
        await account_service.create_account(user_id)

        exists = await account_service.account_exists(user_id)
        assert exists is True

    async def test_account_exists_returns_false_for_nonexistent_account(self, account_service, user_id):
        """Test account_exists returns False for non-existent account"""
        exists = await account_service.account_exists(user_id)
        assert exists is False

    async def test_user_id_maps_to_consistent_account_id(self, account_service, mock_client):
        """Test that same user_id always maps to same account_id"""
        user_id = "consistent_user_123"

        account_id1 = mock_client.user_id_to_account_id(user_id)
        account_id2 = mock_client.user_id_to_account_id(user_id)

        assert account_id1 == account_id2

    async def test_different_users_get_different_account_ids(self, mock_client):
        """Test that different user_ids map to different account_ids"""
        user_id1 = "user_one"
        user_id2 = "user_two"

        account_id1 = mock_client.user_id_to_account_id(user_id1)
        account_id2 = mock_client.user_id_to_account_id(user_id2)

        assert account_id1 != account_id2
