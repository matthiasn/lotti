"""Unit tests for pricing service"""

import pytest

from src.services.pricing_service import PricingService


class TestPricingService:

    @pytest.fixture
    def db_path(self, tmp_path):
        return str(tmp_path / "test_pricing.db")

    @pytest.fixture
    def service(self, db_path):
        return PricingService(db_path=db_path)

    @pytest.mark.asyncio
    async def test_seed_data_loaded(self, service):
        models = await service.get_all_pricing()
        model_ids = [m["model_id"] for m in models]
        assert "gemini-2.5-pro" in model_ids
        assert "gemini-2.5-flash" in model_ids

    @pytest.mark.asyncio
    async def test_get_pricing(self, service):
        pricing = await service.get_pricing("gemini-2.5-pro")
        assert pricing is not None
        assert pricing["input_price_per_1k"] == 0.00125

    @pytest.mark.asyncio
    async def test_update_pricing(self, service):
        result = await service.update_pricing("gemini-2.5-pro", "Pro Updated", 0.002, 0.02)
        assert result["display_name"] == "Pro Updated"
        assert result["input_price_per_1k"] == 0.002
        # Verify sync cache is updated
        cached = service.get_pricing_for_model_sync("gemini-2.5-pro")
        assert cached["input_price_per_1k"] == 0.002

    @pytest.mark.asyncio
    async def test_create_pricing(self, service):
        result = await service.create_pricing("new-model", "New Model", 0.001, 0.005)
        assert result["model_id"] == "new-model"
        pricing = await service.get_pricing("new-model")
        assert pricing is not None

    @pytest.mark.asyncio
    async def test_get_nonexistent_pricing(self, service):
        pricing = await service.get_pricing("nonexistent")
        assert pricing is None

    def test_sync_pricing_fallback(self, service):
        # Unknown model should return default pricing
        pricing = service.get_pricing_for_model_sync("unknown-model")
        assert "input_price_per_1k" in pricing
        assert "output_price_per_1k" in pricing

    def test_sync_pricing_with_model_mapping(self, service):
        # gpt-4 should map to gemini-2.5-pro pricing
        pricing = service.get_pricing_for_model_sync("gpt-4")
        assert pricing["input_price_per_1k"] == 0.00125
