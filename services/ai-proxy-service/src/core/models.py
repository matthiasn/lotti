"""Core domain models for AI proxy service"""

from __future__ import annotations

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field


# OpenAI-compatible request/response models
class ChatMessage(BaseModel):
    """Single chat message"""

    role: Literal["system", "user", "assistant"] = Field(..., description="Role of the message sender")
    content: str = Field(..., description="Message content")


class ChatCompletionRequest(BaseModel):
    """OpenAI-compatible chat completion request"""

    model: str = Field(..., description="Model to use (e.g., 'gemini-pro', 'gpt-4')")
    messages: list[ChatMessage] = Field(..., description="List of messages in the conversation")
    temperature: float | None = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    max_tokens: int | None = Field(default=None, description="Maximum tokens to generate")
    stream: bool | None = Field(default=False, description="Whether to stream the response")
    user_id: str | None = Field(default=None, description="User identifier for billing")


class Usage(BaseModel):
    """Token usage information"""

    prompt_tokens: int = Field(..., description="Number of tokens in the prompt")
    completion_tokens: int = Field(..., description="Number of tokens in the completion")
    total_tokens: int = Field(..., description="Total tokens used")


class ChatChoice(BaseModel):
    """Single chat completion choice"""

    index: int = Field(default=0, description="Choice index")
    message: ChatMessage = Field(..., description="Generated message")
    finish_reason: str = Field(default="stop", description="Reason for completion finish")


class ChatCompletionResponse(BaseModel):
    """OpenAI-compatible chat completion response"""

    id: str = Field(..., description="Unique completion ID")
    object: str = Field(default="chat.completion", description="Object type")
    created: int = Field(..., description="Unix timestamp of creation")
    model: str = Field(..., description="Model used")
    choices: list[ChatChoice] = Field(..., description="List of completion choices")
    usage: Usage = Field(..., description="Token usage statistics")


# Billing models
class BillingMetadata(BaseModel):
    """Billing information for an AI request"""

    user_id: str = Field(..., description="User identifier")
    model: str = Field(..., description="Model used")
    prompt_tokens: int = Field(..., description="Number of prompt tokens")
    completion_tokens: int = Field(..., description="Number of completion tokens")
    total_tokens: int = Field(..., description="Total tokens")
    estimated_cost_usd: Decimal = Field(..., description="Estimated cost in USD")
    request_id: str = Field(..., description="Unique request ID")


# Error models
class ErrorResponse(BaseModel):
    """Standard error response"""

    error: str = Field(..., description="Error message")
    detail: str | None = Field(None, description="Additional error details")


# Usage logging models
class UsageLogEntry(BaseModel):
    """A single usage log entry"""

    id: int = Field(..., description="Log entry ID")
    user_id: str = Field(..., description="User identifier")
    model: str = Field(..., description="Model used")
    prompt_tokens: int = Field(..., description="Number of prompt tokens")
    completion_tokens: int = Field(..., description="Number of completion tokens")
    total_tokens: int = Field(..., description="Total tokens used")
    cost_usd: Decimal = Field(..., description="Cost in USD")
    request_id: str = Field(..., description="Request ID for tracing")
    created_at: str = Field(..., description="ISO 8601 timestamp")


class UsageQueryResponse(BaseModel):
    """Paginated usage log response"""

    entries: list[UsageLogEntry] = Field(..., description="Usage log entries")
    total: int = Field(..., description="Total number of entries")
    page: int = Field(..., description="Current page")
    page_size: int = Field(..., description="Entries per page")


class UserUsageSummary(BaseModel):
    """Summary of token usage for a user or system-wide"""

    total_requests: int = Field(..., description="Total number of requests")
    total_prompt_tokens: int = Field(..., description="Total prompt tokens")
    total_completion_tokens: int = Field(..., description="Total completion tokens")
    total_tokens: int = Field(..., description="Total tokens")
    total_cost_usd: Decimal = Field(..., description="Total cost in USD")
    by_model: dict[str, dict] = Field(default_factory=dict, description="Breakdown by model")


# Model pricing models
class ModelPricing(BaseModel):
    """Model pricing information"""

    model_id: str = Field(..., description="Model identifier")
    display_name: str | None = Field(None, description="Human-readable model name")
    input_price_per_1k: Decimal = Field(..., description="Input price per 1K tokens in USD")
    output_price_per_1k: Decimal = Field(..., description="Output price per 1K tokens in USD")
    updated_at: str = Field(..., description="ISO 8601 last update timestamp")


class ModelPricingListResponse(BaseModel):
    """List of model pricing"""

    models: list[ModelPricing] = Field(..., description="Model pricing entries")


class ModelPricingUpdateRequest(BaseModel):
    """Request to update model pricing"""

    display_name: str | None = Field(None, description="Human-readable name")
    input_price_per_1k: Decimal = Field(..., description="Input price per 1K tokens", ge=0)
    output_price_per_1k: Decimal = Field(..., description="Output price per 1K tokens", ge=0)


class ModelPricingCreateRequest(BaseModel):
    """Request to create new model pricing"""

    model_id: str = Field(..., description="Model identifier")
    display_name: str | None = Field(None, description="Human-readable name")
    input_price_per_1k: Decimal = Field(..., description="Input price per 1K tokens", ge=0)
    output_price_per_1k: Decimal = Field(..., description="Output price per 1K tokens", ge=0)
