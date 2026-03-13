"""Service interfaces for dependency injection"""

from __future__ import annotations

from abc import ABC, abstractmethod

from .models import ChatMessage, ChatCompletionResponse, BillingMetadata


class IGeminiClient(ABC):
    """Interface for Gemini AI client operations"""

    @abstractmethod
    async def generate_completion(
        self,
        messages: list[ChatMessage],
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

    @abstractmethod
    async def generate_completion_stream(
        self,
        messages: list[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ):
        """
        Generate a streaming chat completion using Gemini

        Args:
            messages: List of chat messages
            model: Gemini model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate

        Yields:
            Streaming response chunks in OpenAI format
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


class IUsageLogService(ABC):
    """Interface for persistent usage logging"""

    @abstractmethod
    async def log_usage(
        self,
        user_id: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        total_tokens: int,
        cost_usd: float,
        request_id: str,
    ) -> None:
        """Log a usage entry"""
        pass

    @abstractmethod
    async def get_user_usage(
        self, user_id: str, page: int = 1, page_size: int = 20
    ) -> tuple[list[dict], int]:
        """Get usage entries for a user. Returns (entries, total_count)."""
        pass

    @abstractmethod
    async def get_user_summary(self, user_id: str) -> dict:
        """Get usage summary for a user."""
        pass

    @abstractmethod
    async def get_system_summary(self) -> dict:
        """Get system-wide usage summary."""
        pass


class IPricingService(ABC):
    """Interface for model pricing management"""

    @abstractmethod
    async def get_all_pricing(self) -> list[dict]:
        """Get all model pricing entries"""
        pass

    @abstractmethod
    async def get_pricing(self, model_id: str) -> dict | None:
        """Get pricing for a specific model"""
        pass

    @abstractmethod
    async def update_pricing(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Update pricing for a model"""
        pass

    @abstractmethod
    async def create_pricing(
        self,
        model_id: str,
        display_name: str | None,
        input_price: float,
        output_price: float,
    ) -> dict:
        """Create new model pricing"""
        pass

    @abstractmethod
    def get_pricing_for_model_sync(self, model: str) -> dict:
        """Get pricing dict for billing (synchronous, cached).

        Returns dict with input_price_per_1k, output_price_per_1k.
        """
        pass
