"""Billing service for tracking AI usage costs"""

import logging
import os

import httpx

from ..core.constants import (
    GEMINI_PRO_INPUT_PRICE_PER_1K,
    GEMINI_PRO_OUTPUT_PRICE_PER_1K,
)
from ..core.exceptions import AIProviderException
from ..core.interfaces import IBillingService
from ..core.models import BillingMetadata

logger = logging.getLogger(__name__)


class BillingService(IBillingService):
    """Service for billing operations with credits service integration"""

    def __init__(self):
        """Initialize billing service with credits service configuration"""
        self.credits_service_url = os.getenv("CREDITS_SERVICE_URL", "")
        self.credits_service_api_key = os.getenv("CREDITS_SERVICE_API_KEY", "")
        self.phase2_enabled = bool(self.credits_service_url and self.credits_service_api_key)

        if self.phase2_enabled:
            logger.info(f"✓ Phase 2 billing enabled - Credits service: {self.credits_service_url}")
        else:
            logger.info("ℹ️  Phase 2 billing disabled - Using Phase 1 (logging only)")

    def calculate_cost(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
    ) -> float:
        """
        Calculate the cost of an AI request

        Args:
            model: Model used (currently using Gemini Pro pricing for all)
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens

        Returns:
            Cost in USD
        """
        # Calculate cost based on Gemini Pro pricing
        # (In future, we could have different pricing for different models)
        input_cost = (prompt_tokens / 1000) * GEMINI_PRO_INPUT_PRICE_PER_1K
        output_cost = (completion_tokens / 1000) * GEMINI_PRO_OUTPUT_PRICE_PER_1K
        total_cost = input_cost + output_cost

        logger.debug(
            f"Cost calculation: {prompt_tokens} input tokens (${input_cost:.6f}) + "
            f"{completion_tokens} output tokens (${output_cost:.6f}) = ${total_cost:.6f}"
        )

        return total_cost

    async def log_billing(self, metadata: BillingMetadata) -> None:
        """
        Log billing information and optionally bill user via credits service

        Args:
            metadata: Billing metadata to log and process

        Raises:
            AIProviderException: If billing via credits service fails
        """
        # Always log billing info
        logger.info(
            f"💰 BILLING | "
            f"User: {metadata.user_id} | "
            f"Model: {metadata.model} | "
            f"Tokens: {metadata.prompt_tokens} input + "
            f"{metadata.completion_tokens} output = {metadata.total_tokens} total | "
            f"Cost: ${metadata.estimated_cost_usd:.6f} USD | "
            f"Request ID: {metadata.request_id}"
        )

        # Phase 2: Call credits service to bill the user
        if self.phase2_enabled:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.post(
                        f"{self.credits_service_url}/api/v1/bill",
                        json={
                            "user_id": metadata.user_id,
                            "amount": float(metadata.estimated_cost_usd),
                            "description": (
                                f"{metadata.model} - {metadata.total_tokens} tokens " f"(req: {metadata.request_id})"
                            ),
                        },
                        headers={"Authorization": f"Bearer {self.credits_service_api_key}"},
                    )

                    if response.status_code == 402:
                        # Insufficient balance - this is a client error
                        logger.warning(
                            f"Billing failed for {metadata.user_id}: Insufficient balance "
                            f"(cost: ${metadata.estimated_cost_usd:.6f})"
                        )
                        raise AIProviderException(
                            "Insufficient balance. Please top up your account to continue using AI services."
                        )
                    elif response.status_code != 200:
                        # Other billing errors
                        logger.error(
                            f"Billing failed for {metadata.user_id}: "
                            f"Status {response.status_code}, Response: {response.text}"
                        )
                        raise AIProviderException("Billing service error - please contact support")

                    # Billing successful
                    logger.info(f"✓ Billed ${metadata.estimated_cost_usd:.6f} to {metadata.user_id}")

            except httpx.TimeoutException:
                logger.error(f"Timeout calling credits service for {metadata.user_id}")
                raise AIProviderException("Billing service timeout - please try again later")
            except httpx.RequestError as e:
                logger.error(f"Request error calling credits service for {metadata.user_id}: {e}")
                raise AIProviderException("Billing service unavailable - please try again later")
            except AIProviderException:
                # Re-raise our custom exceptions
                raise
            except Exception:
                logger.exception(f"Unexpected error billing {metadata.user_id}")
                raise AIProviderException("Billing error - please contact support")
