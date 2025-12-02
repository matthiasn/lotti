"""Unit tests for BillingService"""

from decimal import Decimal

import pytest

from src.core.constants import SYSTEM_ACCOUNT_ID
from src.core.exceptions import (
    AccountNotFoundException,
    InsufficientBalanceException,
    InvalidAmountException,
)
from src.services.billing_service import BillingService


@pytest.mark.unit
class TestBillingService:
    """Unit tests for BillingService business logic"""

    @pytest.fixture
    def billing_service(self, mock_client):
        """Create BillingService with mock client"""
        return BillingService(mock_client)

    @pytest.fixture
    async def user_account(self, mock_client, user_id):
        """Create a user account for testing"""
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)
        return user_id

    @pytest.fixture
    async def funded_account(self, mock_client, user_id):
        """Create a user account with $100 balance"""
        # Create system account
        await mock_client.create_account(SYSTEM_ACCOUNT_ID, "system", is_system_account=True)

        # Create user account
        account_id = mock_client.user_id_to_account_id(user_id)
        await mock_client.create_account(account_id, user_id)

        # Fund with $100
        transfer_id = mock_client.generate_transfer_id()
        await mock_client.create_transfer(
            transfer_id=transfer_id,
            debit_account_id=SYSTEM_ACCOUNT_ID,
            credit_account_id=account_id,
            amount_cents=10000,
        )
        return user_id


class TestTopUp(TestBillingService):
    """Tests for the top_up method"""

    async def test_top_up_adds_credits(self, billing_service, user_account, mock_client):
        """Test that top_up adds credits to account"""
        user_id = user_account
        amount = Decimal("50.00")

        new_balance = await billing_service.top_up(user_id, amount)

        assert new_balance == Decimal("50.00")
        account_id = mock_client.user_id_to_account_id(user_id)
        assert await mock_client.get_account_balance(account_id) == 5000

    async def test_top_up_creates_system_account_if_missing(self, billing_service, user_account, mock_client):
        """Test that top_up creates system account if it doesn't exist"""
        user_id = user_account

        # System account shouldn't exist yet
        assert SYSTEM_ACCOUNT_ID not in mock_client._accounts

        await billing_service.top_up(user_id, Decimal("10.00"))

        # System account should now exist
        assert SYSTEM_ACCOUNT_ID in mock_client._accounts

    async def test_top_up_accumulates_balance(self, billing_service, user_account):
        """Test that multiple top-ups accumulate balance"""
        user_id = user_account

        await billing_service.top_up(user_id, Decimal("25.00"))
        new_balance = await billing_service.top_up(user_id, Decimal("30.00"))

        assert new_balance == Decimal("55.00")

    async def test_top_up_with_fractional_amount(self, billing_service, user_account):
        """Test top-up with fractional dollar amount"""
        user_id = user_account

        new_balance = await billing_service.top_up(user_id, Decimal("10.75"))
        assert new_balance == Decimal("10.75")

    async def test_top_up_with_small_amount(self, billing_service, user_account):
        """Test top-up with small amount (1 cent)"""
        user_id = user_account

        new_balance = await billing_service.top_up(user_id, Decimal("0.01"))
        assert new_balance == Decimal("0.01")

    async def test_top_up_zero_raises_exception(self, billing_service, user_account):
        """Test that top_up with zero amount raises exception"""
        user_id = user_account

        with pytest.raises(InvalidAmountException) as exc_info:
            await billing_service.top_up(user_id, Decimal("0.00"))
        assert "positive" in str(exc_info.value).lower()

    async def test_top_up_negative_raises_exception(self, billing_service, user_account):
        """Test that top_up with negative amount raises exception"""
        user_id = user_account

        with pytest.raises(InvalidAmountException) as exc_info:
            await billing_service.top_up(user_id, Decimal("-10.00"))
        assert "positive" in str(exc_info.value).lower()

    async def test_top_up_nonexistent_account_raises_exception(self, billing_service, user_id):
        """Test that top_up for non-existent account raises exception"""
        with pytest.raises(AccountNotFoundException):
            await billing_service.top_up(user_id, Decimal("10.00"))


class TestBill(TestBillingService):
    """Tests for the bill method"""

    async def test_bill_deducts_credits(self, billing_service, funded_account, mock_client):
        """Test that bill deducts credits from account"""
        user_id = funded_account

        new_balance = await billing_service.bill(user_id, Decimal("25.00"))

        assert new_balance == Decimal("75.00")
        account_id = mock_client.user_id_to_account_id(user_id)
        assert await mock_client.get_account_balance(account_id) == 7500

    async def test_bill_with_description(self, billing_service, funded_account):
        """Test billing with optional description"""
        user_id = funded_account

        new_balance = await billing_service.bill(user_id, Decimal("5.00"), description="API call to GPT-4")

        assert new_balance == Decimal("95.00")

    async def test_bill_exact_balance(self, billing_service, funded_account):
        """Test billing exact balance amount (should succeed)"""
        user_id = funded_account

        new_balance = await billing_service.bill(user_id, Decimal("100.00"))
        assert new_balance == Decimal("0.00")

    async def test_bill_with_fractional_amount(self, billing_service, funded_account):
        """Test billing with fractional amount"""
        user_id = funded_account

        new_balance = await billing_service.bill(user_id, Decimal("0.25"))
        assert new_balance == Decimal("99.75")

    async def test_bill_with_small_amount(self, billing_service, funded_account):
        """Test billing with small amount (1 cent)"""
        user_id = funded_account

        new_balance = await billing_service.bill(user_id, Decimal("0.01"))
        assert new_balance == Decimal("99.99")

    async def test_bill_multiple_times(self, billing_service, funded_account):
        """Test multiple billing operations"""
        user_id = funded_account

        await billing_service.bill(user_id, Decimal("10.00"))
        await billing_service.bill(user_id, Decimal("20.00"))
        new_balance = await billing_service.bill(user_id, Decimal("30.00"))

        assert new_balance == Decimal("40.00")

    async def test_bill_insufficient_balance_raises_exception(self, billing_service, funded_account):
        """Test that billing more than balance raises exception"""
        user_id = funded_account

        with pytest.raises(InsufficientBalanceException):
            await billing_service.bill(user_id, Decimal("150.00"))

    async def test_bill_zero_raises_exception(self, billing_service, funded_account):
        """Test that billing zero amount raises exception"""
        user_id = funded_account

        with pytest.raises(InvalidAmountException) as exc_info:
            await billing_service.bill(user_id, Decimal("0.00"))
        assert "positive" in str(exc_info.value).lower()

    async def test_bill_negative_raises_exception(self, billing_service, funded_account):
        """Test that billing negative amount raises exception"""
        user_id = funded_account

        with pytest.raises(InvalidAmountException) as exc_info:
            await billing_service.bill(user_id, Decimal("-10.00"))
        assert "positive" in str(exc_info.value).lower()

    async def test_bill_nonexistent_account_raises_exception(self, billing_service, user_id):
        """Test that billing non-existent account raises exception"""
        with pytest.raises(AccountNotFoundException):
            await billing_service.bill(user_id, Decimal("10.00"))


class TestSystemAccountInitialization(TestBillingService):
    """Tests for system account initialization behavior"""

    async def test_system_account_created_only_once(self, billing_service, user_account, mock_client):
        """Test that system account is only created once across multiple operations"""
        user_id = user_account

        # Multiple top-ups should not recreate system account
        await billing_service.top_up(user_id, Decimal("10.00"))
        await billing_service.top_up(user_id, Decimal("10.00"))
        await billing_service.top_up(user_id, Decimal("10.00"))

        # Verify system account exists and was only created once
        # (if created multiple times, AccountAlreadyExistsException would be raised)
        assert SYSTEM_ACCOUNT_ID in mock_client._accounts
        assert billing_service._system_account_initialized is True

    async def test_system_account_allows_overdraft(self, billing_service, user_account, mock_client):
        """Test that system account can go negative (for minting credits)"""
        user_id = user_account

        # Top-up should work even though system account starts at 0
        await billing_service.top_up(user_id, Decimal("1000.00"))

        # System account should be negative
        system_balance = await mock_client.get_account_balance(SYSTEM_ACCOUNT_ID)
        assert system_balance == -100000  # -$1000.00 in cents
