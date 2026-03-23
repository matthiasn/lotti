"""Unit tests for usage log service"""

import pytest

from src.services.usage_log_service import UsageLogService


class TestUsageLogService:

    @pytest.fixture
    def db_path(self, tmp_path):
        return str(tmp_path / "test_usage.db")

    @pytest.fixture
    def service(self, db_path):
        return UsageLogService(db_path=db_path)

    @pytest.mark.asyncio
    async def test_log_and_query(self, service):
        await service.log_usage("user-1", "gemini-2.5-pro", 100, 50, 150, 0.005, "req-1")
        entries, total = await service.get_user_usage("user-1")
        assert total == 1
        assert entries[0]["model"] == "gemini-2.5-pro"
        assert entries[0]["prompt_tokens"] == 100

    @pytest.mark.asyncio
    async def test_pagination(self, service):
        for i in range(5):
            await service.log_usage(
                "user-1", "gemini-2.5-flash", 10, 5, 15, 0.001, f"req-{i}"
            )
        entries, total = await service.get_user_usage("user-1", page=1, page_size=2)
        assert len(entries) == 2
        assert total == 5

    @pytest.mark.asyncio
    async def test_user_summary(self, service):
        await service.log_usage("user-1", "gemini-2.5-pro", 100, 50, 150, 0.005, "req-1")
        await service.log_usage(
            "user-1", "gemini-2.5-flash", 200, 100, 300, 0.001, "req-2"
        )
        summary = await service.get_user_summary("user-1")
        assert summary["total_requests"] == 2
        assert summary["total_prompt_tokens"] == 300
        assert summary["total_completion_tokens"] == 150
        assert len(summary["by_model"]) == 2

    @pytest.mark.asyncio
    async def test_system_summary(self, service):
        await service.log_usage("user-1", "gemini-2.5-pro", 100, 50, 150, 0.005, "req-1")
        await service.log_usage(
            "user-2", "gemini-2.5-flash", 200, 100, 300, 0.001, "req-2"
        )
        summary = await service.get_system_summary()
        assert summary["total_requests"] == 2
        assert summary["total_tokens"] == 450

    @pytest.mark.asyncio
    async def test_empty_user_usage(self, service):
        entries, total = await service.get_user_usage("nobody")
        assert entries == []
        assert total == 0
