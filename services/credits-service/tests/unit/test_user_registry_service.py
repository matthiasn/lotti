"""Unit tests for user registry service"""

import pytest

from src.services.user_registry_service import UserRegistryService


class TestUserRegistryService:

    @pytest.fixture
    def db_path(self, tmp_path):
        return str(tmp_path / "test_registry.db")

    @pytest.fixture
    def service(self, db_path):
        return UserRegistryService(db_path=db_path)

    @pytest.mark.asyncio
    async def test_register_and_get_user(self, service):
        await service.register_user("user-123", "Test User")
        user = await service.get_user("user-123")
        assert user is not None
        assert user["user_id"] == "user-123"
        assert user["display_name"] == "Test User"
        assert user["created_at"] is not None

    @pytest.mark.asyncio
    async def test_get_nonexistent_user(self, service):
        user = await service.get_user("nonexistent")
        assert user is None

    @pytest.mark.asyncio
    async def test_duplicate_registration_ignored(self, service):
        await service.register_user("user-123", "First")
        await service.register_user("user-123", "Second")  # Should not raise
        user = await service.get_user("user-123")
        assert user["display_name"] == "First"  # INSERT OR IGNORE keeps first

    @pytest.mark.asyncio
    async def test_list_users_empty(self, service):
        users, total = await service.list_users()
        assert users == []
        assert total == 0

    @pytest.mark.asyncio
    async def test_list_users_pagination(self, service):
        for i in range(5):
            await service.register_user(f"user-{i}", f"User {i}")

        users, total = await service.list_users(page=1, page_size=2)
        assert len(users) == 2
        assert total == 5

        users, total = await service.list_users(page=3, page_size=2)
        assert len(users) == 1
        assert total == 5

    @pytest.mark.asyncio
    async def test_user_exists(self, service):
        assert not await service.user_exists("user-123")
        await service.register_user("user-123")
        assert await service.user_exists("user-123")
