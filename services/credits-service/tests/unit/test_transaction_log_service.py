"""Unit tests for transaction log service"""

import pytest
from decimal import Decimal

from src.services.transaction_log_service import TransactionLogService


class TestTransactionLogService:

    @pytest.fixture
    def db_path(self, tmp_path):
        return str(tmp_path / "test_transactions.db")

    @pytest.fixture
    def service(self, db_path):
        return TransactionLogService(db_path=db_path)

    @pytest.mark.asyncio
    async def test_log_and_get_transaction(self, service):
        await service.log_transaction("user-1", "topup", Decimal("100.00"), Decimal("100.00"))
        txns, total = await service.get_transactions("user-1")
        assert total == 1
        assert txns[0]["user_id"] == "user-1"
        assert txns[0]["type"] == "topup"
        assert txns[0]["amount"] == Decimal("100.00")
        assert txns[0]["balance_after"] == Decimal("100.00")

    @pytest.mark.asyncio
    async def test_transaction_with_description(self, service):
        await service.log_transaction(
            "user-1", "bill", Decimal("0.25"), Decimal("99.75"), "Gemini API call"
        )
        txns, total = await service.get_transactions("user-1")
        assert txns[0]["description"] == "Gemini API call"

    @pytest.mark.asyncio
    async def test_transaction_with_sub_cent_precision(self, service):
        await service.log_transaction(
            "user-1",
            "bill",
            Decimal("0.000625"),
            Decimal("0.999375"),
        )
        txns, total = await service.get_transactions("user-1")
        assert total == 1
        assert txns[0]["amount"] == Decimal("0.000625")
        assert txns[0]["balance_after"] == Decimal("0.999375")

    @pytest.mark.asyncio
    async def test_transactions_ordered_newest_first(self, service):
        await service.log_transaction("user-1", "topup", Decimal("100.00"), Decimal("100.00"))
        await service.log_transaction("user-1", "bill", Decimal("10.00"), Decimal("90.00"))
        await service.log_transaction("user-1", "bill", Decimal("5.00"), Decimal("85.00"))
        txns, total = await service.get_transactions("user-1")
        assert total == 3
        assert txns[0]["amount"] == Decimal("5.00")  # newest first
        assert txns[2]["amount"] == Decimal("100.00")  # oldest last

    @pytest.mark.asyncio
    async def test_pagination(self, service):
        for i in range(5):
            await service.log_transaction(
                "user-1", "bill", Decimal("1.00"), Decimal(str(99 - i))
            )

        txns, total = await service.get_transactions("user-1", page=1, page_size=2)
        assert len(txns) == 2
        assert total == 5

        txns, total = await service.get_transactions("user-1", page=3, page_size=2)
        assert len(txns) == 1

    @pytest.mark.asyncio
    async def test_get_transactions_empty(self, service):
        txns, total = await service.get_transactions("no-user")
        assert txns == []
        assert total == 0

    @pytest.mark.asyncio
    async def test_transactions_isolated_by_user(self, service):
        await service.log_transaction("user-1", "topup", Decimal("100.00"), Decimal("100.00"))
        await service.log_transaction("user-2", "topup", Decimal("50.00"), Decimal("50.00"))
        txns, total = await service.get_transactions("user-1")
        assert total == 1
        assert txns[0]["user_id"] == "user-1"
