"""Unit tests for balance service"""

import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, Mock

from src.services.balance_service import BalanceService
from src.core.exceptions import AccountNotFoundException


class TestBalanceService:
    """Test cases for BalanceService"""

    @pytest.fixture
    def mock_client(self):
        """Create a mock TigerBeetle client"""
        client = Mock()
        client.user_id_to_account_id = Mock(return_value=12345)
        client.get_account_balance = AsyncMock()
        return client

    @pytest.fixture
    def balance_service(self, mock_client):
        """Create a BalanceService instance with mocked client"""
        return BalanceService(tigerbeetle_client=mock_client)

    @pytest.mark.asyncio
    async def test_get_balance_success(self, balance_service, mock_client):
        """Test getting balance successfully"""
        mock_client.get_account_balance.return_value = 1500  # $15.00 in cents

        balance = await balance_service.get_balance("user@example.com")

        assert balance == Decimal("15.00")
        mock_client.user_id_to_account_id.assert_called_once_with("user@example.com")
        mock_client.get_account_balance.assert_called_once_with(12345)

    @pytest.mark.asyncio
    async def test_get_balance_zero(self, balance_service, mock_client):
        """Test getting zero balance"""
        mock_client.get_account_balance.return_value = 0

        balance = await balance_service.get_balance("user@example.com")

        assert balance == Decimal("0.00")

    @pytest.mark.asyncio
    async def test_get_balance_account_not_found(self, balance_service, mock_client):
        """Test getting balance for non-existent account"""
        mock_client.get_account_balance.side_effect = AccountNotFoundException("Account not found")

        with pytest.raises(AccountNotFoundException):
            await balance_service.get_balance("user@example.com")

    @pytest.mark.asyncio
    async def test_get_balance_fractional_cents(self, balance_service, mock_client):
        """Test balance conversion from cents to USD"""
        mock_client.get_account_balance.return_value = 12345  # $123.45 in cents

        balance = await balance_service.get_balance("user@example.com")

        assert balance == Decimal("123.45")
