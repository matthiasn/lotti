"""Core domain models for AI proxy service"""

from decimal import Decimal
from typing import List, Optional, Literal
from pydantic import BaseModel, Field


# OpenAI-compatible request/response models
class ChatMessage(BaseModel):
    """Single chat message"""

    role: Literal["system", "user", "assistant"] = Field(..., description="Role of the message sender")
    content: str = Field(..., description="Message content")


class ChatCompletionRequest(BaseModel):
    """OpenAI-compatible chat completion request"""

    model: str = Field(..., description="Model to use (e.g., 'gemini-pro', 'gpt-4')")
    messages: List[ChatMessage] = Field(..., description="List of messages in the conversation")
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    max_tokens: Optional[int] = Field(default=None, description="Maximum tokens to generate")
    stream: Optional[bool] = Field(default=False, description="Whether to stream the response")
    user_id: Optional[str] = Field(default=None, description="User identifier for billing")


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
    choices: List[ChatChoice] = Field(..., description="List of completion choices")
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
    detail: Optional[str] = Field(None, description="Additional error details")
