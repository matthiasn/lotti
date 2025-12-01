"""Unit tests for billing service"""

import pytest
from decimal import Decimal

from src.services.billing_service import BillingService
from src.core.models import BillingMetadata


class TestBillingService:
    """Test cases for BillingService"""

    @pytest.fixture
    def billing_service(self):
        """Create a billing service instance"""
        return BillingService()

    def test_calculate_cost_basic(self, billing_service):
        """Test basic cost calculation"""
        # 1000 input tokens + 1000 output tokens
        cost = billing_service.calculate_cost(
            model="gemini-pro",
            prompt_tokens=1000,
            completion_tokens=1000,
        )

        # Expected: (1000/1000 * 0.00025) + (1000/1000 * 0.0005)
        # = 0.00025 + 0.0005 = 0.00075
        assert cost == pytest.approx(0.00075, rel=1e-6)

    def test_calculate_cost_small_request(self, billing_service):
        """Test cost calculation for small request"""
        # 100 input tokens + 50 output tokens
        cost = billing_service.calculate_cost(
            model="gemini-pro",
            prompt_tokens=100,
            completion_tokens=50,
        )

        # Expected: (100/1000 * 0.00025) + (50/1000 * 0.0005)
        # = 0.000025 + 0.000025 = 0.00005
        assert cost == pytest.approx(0.00005, rel=1e-6)

    def test_calculate_cost_large_request(self, billing_service):
        """Test cost calculation for large request"""
        # 5000 input tokens + 2000 output tokens
        cost = billing_service.calculate_cost(
            model="gemini-pro",
            prompt_tokens=5000,
            completion_tokens=2000,
        )

        # Expected: (5000/1000 * 0.00025) + (2000/1000 * 0.0005)
        # = 0.00125 + 0.001 = 0.00225
        assert cost == pytest.approx(0.00225, rel=1e-6)

    def test_calculate_cost_zero_tokens(self, billing_service):
        """Test cost calculation with zero tokens"""
        cost = billing_service.calculate_cost(
            model="gemini-pro",
            prompt_tokens=0,
            completion_tokens=0,
        )

        assert cost == 0.0

    def test_calculate_cost_flash_model(self, billing_service):
        """Test cost calculation for flash model (cheaper pricing)"""
        # 1000 input tokens + 1000 output tokens with flash model
        cost = billing_service.calculate_cost(
            model="gemini-2.5-flash",
            prompt_tokens=1000,
            completion_tokens=1000,
        )

        # Expected: (1000/1000 * 0.000075) + (1000/1000 * 0.0003)
        # = 0.000075 + 0.0003 = 0.000375
        assert cost == pytest.approx(0.000375, rel=1e-6)

    def test_calculate_cost_openai_model_mapping(self, billing_service):
        """Test cost calculation with OpenAI model name (maps to Gemini)"""
        # gpt-4 maps to gemini-2.5-pro (Pro pricing)
        cost = billing_service.calculate_cost(
            model="gpt-4",
            prompt_tokens=1000,
            completion_tokens=1000,
        )

        # Should use Pro pricing: (1000/1000 * 0.00025) + (1000/1000 * 0.0005)
        # = 0.00025 + 0.0005 = 0.00075
        assert cost == pytest.approx(0.00075, rel=1e-6)

    def test_calculate_cost_gpt35_mapping(self, billing_service):
        """Test cost calculation with gpt-3.5-turbo (maps to flash)"""
        # gpt-3.5-turbo maps to gemini-2.5-flash (Flash pricing)
        cost = billing_service.calculate_cost(
            model="gpt-3.5-turbo",
            prompt_tokens=1000,
            completion_tokens=1000,
        )

        # Should use Flash pricing: (1000/1000 * 0.000075) + (1000/1000 * 0.0003)
        # = 0.000075 + 0.0003 = 0.000375
        assert cost == pytest.approx(0.000375, rel=1e-6)

    def test_calculate_cost_unknown_model_uses_default(self, billing_service):
        """Test cost calculation for unknown model (uses default Pro pricing)"""
        cost = billing_service.calculate_cost(
            model="unknown-model-xyz",
            prompt_tokens=1000,
            completion_tokens=1000,
        )

        # Should use default (Pro) pricing: 0.00025 + 0.0005 = 0.00075
        assert cost == pytest.approx(0.00075, rel=1e-6)

    @pytest.mark.asyncio
    async def test_log_billing(self, billing_service, caplog):
        """Test billing logging"""
        import logging

        # Set caplog to capture INFO level logs
        caplog.set_level(logging.INFO)

        metadata = BillingMetadata(
            user_id="test@example.com",
            model="gemini-pro",
            prompt_tokens=100,
            completion_tokens=50,
            total_tokens=150,
            estimated_cost_usd=Decimal("0.00005"),
            request_id="req-test123",
        )

        await billing_service.log_billing(metadata)

        # Check that billing was logged
        assert "BILLING" in caplog.text
        assert "test@example.com" in caplog.text
        assert "gemini-pro" in caplog.text
        assert "req-test123" in caplog.text
