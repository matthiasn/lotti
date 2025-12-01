"""Unit tests for BalanceService"""

from decimal import Decimal

import pytest

from src.core.constants import SYSTEM_ACCOUNT_ID
from src.core.exceptions import AccountNotFoundException
from src.services.balance_service import BalanceService


@pytest.mark.unit
class TestBalanceService:
    """Unit tests for BalanceService business logic"""

    @pytest.fixture
    def balance_service(self, mock_client):
        """Create BalanceService with mock client"""
        return BalanceService(mock_client)

    @pytest.fixture
    async def account_with_balance(self, mock_client, user_id):
        """Create an account with a known balance for testing"""
        # Create system account first
        await mock_client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)

        # Create user account
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        # Add some balance via transfer from system
        transfer_id = mock_client.generate_transfer_id()
        await mock_client.create_transfer(
            transfer_id=transfer_id,
            debit_account_id=SYSTEM_ACCOUNT_ID,
            credit_account_id=account_id,
            amount_cents=10000,  # $100.00
        )
        return user_id

    async def test_get_balance_returns_zero_for_new_account(self, balance_service, mock_client, user_id):
        """Test getting balance for account with zero balance"""
        # Create account with zero balance
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        balance = await balance_service.get_balance(user_id)
        assert balance == Decimal("0.00")

    async def test_get_balance_returns_correct_amount(self, balance_service, account_with_balance):
        """Test getting balance returns correct USD amount"""
        user_id = account_with_balance

        balance = await balance_service.get_balance(user_id)
        assert balance == Decimal("100.00")

    async def test_get_balance_converts_cents_to_usd(self, balance_service, mock_client, user_id):
        """Test that balance is correctly converted from cents to USD"""
        # Create system account
        await mock_client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)

        # Create user account with specific cent value
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        # Add 1234 cents = $12.34
        transfer_id = mock_client.generate_transfer_id()
        await mock_client.create_transfer(
            transfer_id=transfer_id,
            debit_account_id=SYSTEM_ACCOUNT_ID,
            credit_account_id=account_id,
            amount_cents=1234,
        )

        balance = await balance_service.get_balance(user_id)
        assert balance == Decimal("12.34")

    async def test_get_balance_handles_fractional_cents(self, balance_service, mock_client, user_id):
        """Test balance with odd cent values"""
        # Create system account
        await mock_client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)

        # Create user account
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        # Add 1 cent = $0.01
        transfer_id = mock_client.generate_transfer_id()
        await mock_client.create_transfer(
            transfer_id=transfer_id,
            debit_account_id=SYSTEM_ACCOUNT_ID,
            credit_account_id=account_id,
            amount_cents=1,
        )

        balance = await balance_service.get_balance(user_id)
        assert balance == Decimal("0.01")

    async def test_get_balance_nonexistent_account_raises_exception(self, balance_service, user_id):
        """Test that getting balance for non-existent account raises exception"""
        with pytest.raises(AccountNotFoundException):
            await balance_service.get_balance(user_id)

    async def test_get_balance_uses_correct_account_id(self, balance_service, mock_client, user_id):
        """Test that get_balance uses the correct account_id conversion"""
        # Create account
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        # This should work - uses same conversion
        balance = await balance_service.get_balance(user_id)
        assert balance == Decimal("0.00")
