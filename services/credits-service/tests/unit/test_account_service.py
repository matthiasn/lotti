"""Unit tests for account service"""

import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, Mock

from src.services.account_service import AccountService
from src.core.exceptions import AccountAlreadyExistsException, AccountNotFoundException


class TestAccountService:
    """Test cases for AccountService"""

    @pytest.fixture
    def mock_client(self):
        """Create a mock TigerBeetle client"""
        client = Mock()
        client.user_id_to_account_id = Mock(return_value=12345)
        client.generate_transfer_id = Mock(return_value=1)
        client.create_account = AsyncMock()
        client.create_transfer = AsyncMock()
        client.get_account_balance = AsyncMock()
        return client

    @pytest.fixture
    def account_service(self, mock_client):
        """Create an AccountService instance with mocked client"""
        return AccountService(tigerbeetle_client=mock_client)

    @pytest.mark.asyncio
    async def test_create_account_default_balance(self, account_service, mock_client):
        """Test creating account with default zero balance"""
        account_id, balance = await account_service.create_account("user@example.com")

        assert account_id == 12345
        assert balance == Decimal("0.00")
        mock_client.create_account.assert_called_once_with(12345, "user@example.com")
        mock_client.create_transfer.assert_not_called()

    @pytest.mark.asyncio
    async def test_create_account_with_initial_balance(self, account_service, mock_client):
        """Test creating account with initial balance"""
        account_id, balance = await account_service.create_account("user@example.com", Decimal("10.00"))

        assert account_id == 12345
        assert balance == Decimal("10.00")
        mock_client.create_account.assert_called_once_with(12345, "user@example.com")
        mock_client.create_transfer.assert_called_once()

        # Verify transfer details
        call_kwargs = mock_client.create_transfer.call_args.kwargs
        assert call_kwargs["debit_account_id"] == 1  # SYSTEM_ACCOUNT_ID
        assert call_kwargs["credit_account_id"] == 12345
        assert call_kwargs["amount_cents"] == 1000  # $10.00 in cents

    @pytest.mark.asyncio
    async def test_create_account_already_exists(self, account_service, mock_client):
        """Test creating account that already exists"""
        mock_client.create_account.side_effect = AccountAlreadyExistsException("Account already exists")

        with pytest.raises(AccountAlreadyExistsException):
            await account_service.create_account("user@example.com")

    @pytest.mark.asyncio
    async def test_account_exists_true(self, account_service, mock_client):
        """Test checking if account exists (returns True)"""
        mock_client.get_account_balance.return_value = 1000

        exists = await account_service.account_exists("user@example.com")

        assert exists is True
        mock_client.user_id_to_account_id.assert_called_once_with("user@example.com")
        mock_client.get_account_balance.assert_called_once_with(12345)

    @pytest.mark.asyncio
    async def test_account_exists_false(self, account_service, mock_client):
        """Test checking if account exists (returns False)"""
        mock_client.get_account_balance.side_effect = AccountNotFoundException("Account not found")

        exists = await account_service.account_exists("user@example.com")

        assert exists is False
