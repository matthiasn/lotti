"""Billing service for tracking AI usage costs"""

import logging

from ..core.constants import (
    GEMINI_PRO_INPUT_PRICE_PER_1K,
    GEMINI_PRO_OUTPUT_PRICE_PER_1K,
)
from ..core.interfaces import IBillingService
from ..core.models import BillingMetadata

logger = logging.getLogger(__name__)


class BillingService(IBillingService):
    """Service for billing operations (Phase 1: logging only)"""

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
        Log billing information to console (Phase 1)

        In Phase 2, this will call the credits service to actually bill the user.

        Args:
            metadata: Billing metadata to log
        """
        logger.info(
            f"💰 BILLING | "
            f"User: {metadata.user_id} | "
            f"Model: {metadata.model} | "
            f"Tokens: {metadata.prompt_tokens} input + "
            f"{metadata.completion_tokens} output = {metadata.total_tokens} total | "
            f"Cost: ${metadata.estimated_cost_usd:.6f} USD | "
            f"Request ID: {metadata.request_id}"
        )

        # TODO (Phase 2): Call credits service to bill the user
        # Example:
        # async with httpx.AsyncClient() as client:
        #     response = await client.post(
        #         f"{CREDITS_SERVICE_URL}/api/v1/bill",
        #         json={
        #             "user_id": metadata.user_id,
        #             "amount": float(metadata.estimated_cost_usd),
        #             "description": f"{metadata.model} - {metadata.total_tokens} tokens",
        #         },
        #     )
        #     if response.status_code != 200:
        #         raise BillingException(f"Failed to bill user: {response.text}")
