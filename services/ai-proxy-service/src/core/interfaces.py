"""Service interfaces for dependency injection"""

from abc import ABC, abstractmethod
from typing import List

from .models import ChatMessage, ChatCompletionResponse, BillingMetadata


class IGeminiClient(ABC):
    """Interface for Gemini AI client operations"""

    @abstractmethod
    async def generate_completion(
        self,
        messages: List[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ) -> ChatCompletionResponse:
        """
        Generate a chat completion using Gemini

        Args:
            messages: List of chat messages
            model: Gemini model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate

        Returns:
            ChatCompletionResponse with the completion and usage data
        """
        pass


class IBillingService(ABC):
    """Interface for billing operations"""

    @abstractmethod
    async def log_billing(self, metadata: BillingMetadata) -> None:
        """
        Log billing information (Phase 1: just logging)

        Args:
            metadata: Billing metadata to log
        """
        pass

    @abstractmethod
    def calculate_cost(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
    ) -> float:
        """
        Calculate the cost of an AI request

        Args:
            model: Model used
            prompt_tokens: Number of prompt tokens
            completion_tokens: Number of completion tokens

        Returns:
            Cost in USD
        """
        pass
