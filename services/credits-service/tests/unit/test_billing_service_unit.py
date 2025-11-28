"""Unit tests for billing service"""

import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, Mock

from src.services.billing_service import BillingService, SYSTEM_ACCOUNT_ID
from src.core.exceptions import (
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)


class TestBillingService:
    """Test cases for BillingService"""

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
    def billing_service(self, mock_client):
        """Create a BillingService instance with mocked client"""
        service = BillingService(tigerbeetle_client=mock_client)
        # Pre-initialize system account to avoid extra calls in tests
        service._system_account_initialized = True
        return service

    @pytest.mark.asyncio
    async def test_ensure_system_account_creates_if_missing(self, mock_client):
        """Test system account creation when it doesn't exist"""
        mock_client.get_account_balance.side_effect = AccountNotFoundException("Account not found")
        service = BillingService(tigerbeetle_client=mock_client)

        await service._ensure_system_account()

        mock_client.create_account.assert_called_once_with(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)
        assert service._system_account_initialized is True

    @pytest.mark.asyncio
    async def test_ensure_system_account_already_exists(self, mock_client):
        """Test system account check when it already exists"""
        mock_client.get_account_balance.return_value = 0
        service = BillingService(tigerbeetle_client=mock_client)

        await service._ensure_system_account()

        mock_client.get_account_balance.assert_called_once_with(SYSTEM_ACCOUNT_ID)
        mock_client.create_account.assert_not_called()
        assert service._system_account_initialized is True

    @pytest.mark.asyncio
    async def test_top_up_success(self, billing_service, mock_client):
        """Test successful top-up"""
        mock_client.get_account_balance.return_value = 2500  # $25.00 after top-up

        new_balance = await billing_service.top_up("user@example.com", Decimal("10.00"))

        assert new_balance == Decimal("25.00")
        mock_client.create_transfer.assert_called_once()

        # Verify transfer details
        call_kwargs = mock_client.create_transfer.call_args.kwargs
        assert call_kwargs["debit_account_id"] == SYSTEM_ACCOUNT_ID
        assert call_kwargs["credit_account_id"] == 12345
        assert call_kwargs["amount_cents"] == 1000  # $10.00 in cents

    @pytest.mark.asyncio
    async def test_top_up_invalid_amount(self, billing_service, mock_client):
        """Test top-up with invalid amount"""
        with pytest.raises(InvalidAmountException, match="must be positive"):
            await billing_service.top_up("user@example.com", Decimal("0.00"))

        with pytest.raises(InvalidAmountException, match="must be positive"):
            await billing_service.top_up("user@example.com", Decimal("-10.00"))

    @pytest.mark.asyncio
    async def test_top_up_account_not_found(self, billing_service, mock_client):
        """Test top-up for non-existent account"""
        mock_client.create_transfer.side_effect = AccountNotFoundException("Account not found")

        with pytest.raises(AccountNotFoundException):
            await billing_service.top_up("user@example.com", Decimal("10.00"))

    @pytest.mark.asyncio
    async def test_bill_success(self, billing_service, mock_client):
        """Test successful billing"""
        mock_client.get_account_balance.return_value = 500  # $5.00 after billing

        new_balance = await billing_service.bill("user@example.com", Decimal("10.00"))

        assert new_balance == Decimal("5.00")
        mock_client.create_transfer.assert_called_once()

        # Verify transfer details
        call_kwargs = mock_client.create_transfer.call_args.kwargs
        assert call_kwargs["debit_account_id"] == 12345
        assert call_kwargs["credit_account_id"] == SYSTEM_ACCOUNT_ID
        assert call_kwargs["amount_cents"] == 1000  # $10.00 in cents

    @pytest.mark.asyncio
    async def test_bill_with_description(self, billing_service, mock_client):
        """Test billing with description"""
        mock_client.get_account_balance.return_value = 500

        await billing_service.bill("user@example.com", Decimal("10.00"), description="AI API usage")

        mock_client.create_transfer.assert_called_once()

    @pytest.mark.asyncio
    async def test_bill_invalid_amount(self, billing_service, mock_client):
        """Test billing with invalid amount"""
        with pytest.raises(InvalidAmountException, match="must be positive"):
            await billing_service.bill("user@example.com", Decimal("0.00"))

        with pytest.raises(InvalidAmountException, match="must be positive"):
            await billing_service.bill("user@example.com", Decimal("-10.00"))

    @pytest.mark.asyncio
    async def test_bill_insufficient_balance(self, billing_service, mock_client):
        """Test billing with insufficient balance"""
        mock_client.create_transfer.side_effect = InsufficientBalanceException("Insufficient balance")

        with pytest.raises(InsufficientBalanceException):
            await billing_service.bill("user@example.com", Decimal("100.00"))

    @pytest.mark.asyncio
    async def test_bill_account_not_found(self, billing_service, mock_client):
        """Test billing for non-existent account"""
        mock_client.create_transfer.side_effect = AccountNotFoundException("Account not found")

        with pytest.raises(AccountNotFoundException):
            await billing_service.bill("user@example.com", Decimal("10.00"))
