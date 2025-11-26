"""API routes for AI proxy service"""

import logging
import uuid
from decimal import Decimal
from typing import Dict

from fastapi import APIRouter, HTTPException, status

from ..container import container
from ..core.exceptions import (
    AIProviderException,
    InvalidModelException,
    InvalidRequestException,
)
from ..core.models import (
    ChatCompletionRequest,
    ChatCompletionResponse,
    ErrorResponse,
    BillingMetadata,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health", response_model=Dict[str, str])
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@router.post(
    "/v1/chat/completions",
    response_model=ChatCompletionResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def chat_completions(request: ChatCompletionRequest):
    """
    OpenAI-compatible chat completions endpoint

    This endpoint accepts OpenAI-format requests and proxies them to Gemini,
    returning responses in OpenAI format.

    Args:
        request: Chat completion request

    Returns:
        Chat completion response with usage data

    Raises:
        400: Invalid request
        500: Internal server error
    """
    try:
        # Generate a unique request ID for tracking
        request_id = f"req-{uuid.uuid4().hex[:12]}"

        logger.info(
            f"[{request_id}] Chat completion request: model={request.model}, "
            f"messages={len(request.messages)}, user_id={request.user_id}"
        )

        # Validate request
        if not request.messages:
            raise InvalidRequestException("At least one message is required")

        # Get services from container
        gemini_client = container.get_gemini_client()
        billing_service = container.get_billing_service()

        # Generate completion using Gemini
        response = await gemini_client.generate_completion(
            messages=request.messages,
            model=request.model,
            temperature=request.temperature or 0.7,
            max_tokens=request.max_tokens,
        )

        # Calculate cost
        cost = billing_service.calculate_cost(
            model=request.model,
            prompt_tokens=response.usage.prompt_tokens,
            completion_tokens=response.usage.completion_tokens,
        )

        # Create billing metadata
        billing_metadata = BillingMetadata(
            user_id=request.user_id or "anonymous",
            model=request.model,
            prompt_tokens=response.usage.prompt_tokens,
            completion_tokens=response.usage.completion_tokens,
            total_tokens=response.usage.total_tokens,
            estimated_cost_usd=Decimal(str(cost)),
            request_id=request_id,
        )

        # Log billing (Phase 1: just logging)
        await billing_service.log_billing(billing_metadata)

        logger.info(f"[{request_id}] Chat completion successful")

        return response

    except InvalidRequestException as e:
        logger.warning(f"Invalid request: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except InvalidModelException as e:
        logger.warning(f"Invalid model: {e}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except AIProviderException as e:
        logger.error(f"AI provider error: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="AI provider error") from e
    except Exception as e:
        logger.exception(f"Unexpected error processing chat completion: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Internal server error") from e
