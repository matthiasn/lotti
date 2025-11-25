"""End-to-end test scenario for credits service

This test verifies the complete flow:
1. Create account for user
2. Top-up balance
3. Get balance (verify top-up)
4. Bill against account
5. Get balance (verify bill was deducted)
"""

import pytest
from decimal import Decimal
from httpx import AsyncClient, ASGITransport
import uuid


@pytest.mark.integration
class TestEndToEndFlow:
    """End-to-end test for the complete user flow"""

    @pytest.fixture
    def user_id(self):
        """Test user ID - unique per test run"""
        return f"test_user_{uuid.uuid4().hex[:16]}"

    @pytest.fixture
    async def client(self, app):
        """HTTP client for testing"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac

    async def test_complete_flow(self, client: AsyncClient, user_id: str):
        """
        Test the complete flow:
        1. Create account
        2. Top-up $100
        3. Verify balance is $100
        4. Bill $0.25
        5. Verify balance is $99.75
        """

        # Step 1: Create account
        response = await client.post("/api/v1/accounts", json={"user_id": user_id, "initial_balance": 0.0})
        assert response.status_code == 201, f"Failed to create account: {response.text}"
        data = response.json()
        assert data["user_id"] == user_id
        assert Decimal(str(data["balance"])) == Decimal("0.00")
        print(f"✓ Step 1: Created account for {user_id}")

        # Step 2: Top-up $100
        response = await client.post("/api/v1/topup", json={"user_id": user_id, "amount": 100.0})
        assert response.status_code == 200, f"Failed to top-up: {response.text}"
        data = response.json()
        assert data["user_id"] == user_id
        assert Decimal(str(data["amount_added"])) == Decimal("100.00")
        assert Decimal(str(data["new_balance"])) == Decimal("100.00")
        print(f"✓ Step 2: Topped up $100, balance: ${data['new_balance']}")

        # Step 3: Get balance (verify top-up)
        response = await client.post("/api/v1/balance", json={"user_id": user_id})
        assert response.status_code == 200, f"Failed to get balance: {response.text}"
        data = response.json()
        assert data["user_id"] == user_id
        assert Decimal(str(data["balance"])) == Decimal("100.00")
        print(f"✓ Step 3: Verified balance: ${data['balance']}")

        # Step 4: Bill $0.25 (simulating an API call charge)
        response = await client.post(
            "/api/v1/bill",
            json={"user_id": user_id, "amount": 0.25, "description": "Gemini API call"},
        )
        assert response.status_code == 200, f"Failed to bill: {response.text}"
        data = response.json()
        assert data["user_id"] == user_id
        assert Decimal(str(data["amount_billed"])) == Decimal("0.25")
        assert Decimal(str(data["new_balance"])) == Decimal("99.75")
        print(f"✓ Step 4: Billed $0.25, new balance: ${data['new_balance']}")

        # Step 5: Get balance again (verify bill was deducted)
        response = await client.post("/api/v1/balance", json={"user_id": user_id})
        assert response.status_code == 200, f"Failed to get balance: {response.text}"
        data = response.json()
        assert data["user_id"] == user_id
        assert Decimal(str(data["balance"])) == Decimal("99.75")
        print(f"✓ Step 5: Final balance verified: ${data['balance']}")

        print("\n✅ All steps completed successfully!")
        print("   Account created → Topped up $100 → Billed $0.25 → Final balance: $99.75")

    async def test_insufficient_balance(self, client: AsyncClient):
        """Test that billing fails when balance is insufficient"""
        user_id = f"test_user_{uuid.uuid4().hex[:16]}"

        # Create account with $10
        response = await client.post("/api/v1/accounts", json={"user_id": user_id, "initial_balance": 10.0})
        assert response.status_code == 201

        # Try to bill $20 (should fail)
        response = await client.post("/api/v1/bill", json={"user_id": user_id, "amount": 20.0})
        assert response.status_code == 402  # Payment Required
        print("✓ Insufficient balance correctly rejected")

    async def test_duplicate_account_creation(self, client: AsyncClient):
        """Test that creating duplicate account fails"""
        user_id = f"test_user_{uuid.uuid4().hex[:16]}"

        # Create account first time
        response = await client.post("/api/v1/accounts", json={"user_id": user_id, "initial_balance": 0.0})
        assert response.status_code == 201

        # Try to create again (should fail)
        response = await client.post("/api/v1/accounts", json={"user_id": user_id, "initial_balance": 0.0})
        assert response.status_code == 409  # Conflict
        print("✓ Duplicate account creation correctly rejected")

    async def test_nonexistent_account(self, client: AsyncClient):
        """Test operations on non-existent account fail"""
        user_id = f"test_user_{uuid.uuid4().hex[:16]}"

        # Try to get balance (should fail)
        response = await client.post("/api/v1/balance", json={"user_id": user_id})
        assert response.status_code == 404  # Not Found

        # Try to top-up (should fail)
        response = await client.post("/api/v1/topup", json={"user_id": user_id, "amount": 10.0})
        assert response.status_code == 404

        # Try to bill (should fail)
        response = await client.post("/api/v1/bill", json={"user_id": user_id, "amount": 5.0})
        assert response.status_code == 404

        print("✓ Operations on non-existent account correctly rejected")
