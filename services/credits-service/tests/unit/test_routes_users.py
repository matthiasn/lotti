"""Unit tests for user and transaction routes"""

import os
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock, Mock, patch

from httpx import ASGITransport, AsyncClient


@pytest.fixture(autouse=True)
def set_api_keys():
    """Ensure admin API key env var is set for route auth."""
    original = os.environ.get("ADMIN_API_KEYS")
    os.environ["ADMIN_API_KEYS"] = "admin-test-key"
    yield
    if original is None:
        os.environ.pop("ADMIN_API_KEYS", None)
    else:
        os.environ["ADMIN_API_KEYS"] = original


@pytest.fixture
def mock_user_registry():
    registry = Mock()
    registry.list_users = AsyncMock(return_value=([], 0))
    registry.get_user = AsyncMock(return_value=None)
    registry.user_exists = AsyncMock(return_value=False)
    return registry


@pytest.fixture
def mock_balance_service():
    service = Mock()
    service.get_balance = AsyncMock(return_value=Decimal("100.00"))
    return service


@pytest.fixture
def mock_transaction_log():
    log = Mock()
    log.get_transactions = AsyncMock(return_value=([], 0))
    return log


@pytest.fixture
def mock_container(mock_user_registry, mock_balance_service, mock_transaction_log):
    with patch("src.api.routes.container") as mc:
        mc.get_user_registry.return_value = mock_user_registry
        mc.get_balance_service.return_value = mock_balance_service
        mc.get_transaction_log.return_value = mock_transaction_log
        mc.get_account_service.return_value = Mock()
        mc.get_billing_service.return_value = Mock()
        yield mc


@pytest.fixture
async def client(mock_container):
    # Import app after patching — need to reimport to pick up patched container
    from src.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        headers={"Authorization": "Bearer admin-test-key"},
    ) as ac:
        yield ac


class TestUserListRoute:

    @pytest.mark.asyncio
    async def test_list_users_empty(self, client, mock_user_registry):
        mock_user_registry.list_users.return_value = ([], 0)
        response = await client.get("/api/v1/users")
        assert response.status_code == 200
        data = response.json()
        assert data["users"] == []
        assert data["total"] == 0

    @pytest.mark.asyncio
    async def test_list_users_with_data(self, client, mock_user_registry, mock_balance_service):
        mock_user_registry.list_users.return_value = (
            [
                {
                    "user_id": "u1",
                    "display_name": "User 1",
                    "created_at": "2026-01-01T00:00:00Z",
                }
            ],
            1,
        )
        response = await client.get("/api/v1/users")
        assert response.status_code == 200
        data = response.json()
        assert len(data["users"]) == 1
        assert data["users"][0]["user_id"] == "u1"

    @pytest.mark.asyncio
    async def test_list_users_pagination_params(self, client, mock_user_registry):
        mock_user_registry.list_users.return_value = ([], 0)
        response = await client.get("/api/v1/users?page=2&page_size=10")
        assert response.status_code == 200
        mock_user_registry.list_users.assert_called_once_with(page=2, page_size=10)


class TestUserDetailRoute:

    @pytest.mark.asyncio
    async def test_get_user_not_found(self, client, mock_user_registry):
        mock_user_registry.get_user.return_value = None
        response = await client.get("/api/v1/users/unknown-user")
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_user_success(self, client, mock_user_registry, mock_balance_service):
        mock_user_registry.get_user.return_value = {
            "user_id": "u1",
            "display_name": "Test",
            "created_at": "2026-01-01T00:00:00Z",
        }
        mock_balance_service.get_balance.return_value = Decimal("50.00")
        response = await client.get("/api/v1/users/u1")
        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == "u1"
        assert data["balance"] is not None


class TestTransactionRoute:

    @pytest.mark.asyncio
    async def test_get_transactions_user_not_found(self, client, mock_user_registry):
        mock_user_registry.user_exists.return_value = False
        response = await client.get("/api/v1/users/unknown/transactions")
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_transactions_success(
        self, client, mock_user_registry, mock_transaction_log
    ):
        mock_user_registry.user_exists.return_value = True
        mock_transaction_log.get_transactions.return_value = (
            [
                {
                    "id": 1,
                    "user_id": "u1",
                    "type": "topup",
                    "amount": Decimal("100.00"),
                    "description": None,
                    "balance_after": Decimal("100.00"),
                    "created_at": "2026-01-01T00:00:00Z",
                }
            ],
            1,
        )
        response = await client.get("/api/v1/users/u1/transactions")
        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["transactions"][0]["type"] == "topup"
