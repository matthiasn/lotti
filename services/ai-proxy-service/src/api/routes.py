"""API routes for AI proxy service"""

import json
import logging
import time
import uuid
from decimal import Decimal
from typing import Dict

from fastapi import APIRouter, HTTPException, status, Request
from fastapi.responses import StreamingResponse

from ..container import container
from ..middleware.rate_limit import limiter
from ..core.exceptions import (
    AIProviderException,
    InvalidModelException,
    InvalidRequestException,
)
from ..core.models import (
    ChatCompletionRequest,
    ErrorResponse,
    BillingMetadata,
)
from ..core.metrics import metrics_collector

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health", response_model=Dict[str, str])
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@router.get("/metrics")
async def get_metrics():
    """
    Get service metrics for observability

    Returns current metrics including:
    - Request counts and success rates
    - Token usage statistics
    - Billing information
    - Performance metrics

    Note: This endpoint should be secured or restricted to internal networks in production
    """
    return metrics_collector.get_metrics()


@router.post(
    "/v1/chat/completions",
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        429: {"description": "Too many requests - rate limit exceeded"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
@limiter.limit("30/minute")  # More restrictive limit for AI completions (expensive)
async def chat_completions(request: Request, body: ChatCompletionRequest):
    """
    OpenAI-compatible chat completions endpoint

    This endpoint accepts OpenAI-format requests and proxies them to Gemini,
    returning responses in OpenAI format (streaming or non-streaming).

    Args:
        request: HTTP request (for rate limiting)
        body: Chat completion request body

    Returns:
        Chat completion response with usage data (streaming or JSON)

    Raises:
        400: Invalid request
        429: Rate limit exceeded
        500: Internal server error
    """
    start_time = time.time()
    request_id = f"req-{uuid.uuid4().hex[:12]}"

    try:
        logger.info(
            f"[{request_id}] Chat completion request: model={body.model}, "
            f"messages={len(body.messages)}, stream={body.stream}, user_id={body.user_id}"
        )

        # Validate request
        if not body.messages:
            raise InvalidRequestException("At least one message is required")

        # Get services from container
        gemini_client = container.get_gemini_client()
        billing_service = container.get_billing_service()

        # Return streaming or non-streaming response based on request
        if body.stream:
            # Use real streaming for streaming requests
            return StreamingResponse(
                _stream_real_response(
                    gemini_client=gemini_client,
                    billing_service=billing_service,
                    messages=body.messages,
                    model=body.model,
                    temperature=body.temperature if body.temperature is not None else 0.7,
                    max_tokens=body.max_tokens,
                    user_id=body.user_id or "anonymous",
                    request_id=request_id,
                ),
                media_type="text/event-stream",
            )
        else:
            # Generate completion using Gemini (non-streaming)
            response = await gemini_client.generate_completion(
                messages=body.messages,
                model=body.model,
                temperature=body.temperature if body.temperature is not None else 0.7,
                max_tokens=body.max_tokens,
            )

            # Calculate cost
            cost = billing_service.calculate_cost(
                model=body.model,
                prompt_tokens=response.usage.prompt_tokens,
                completion_tokens=response.usage.completion_tokens,
            )

            # Create billing metadata
            billing_metadata = BillingMetadata(
                user_id=body.user_id or "anonymous",
                model=body.model,
                prompt_tokens=response.usage.prompt_tokens,
                completion_tokens=response.usage.completion_tokens,
                total_tokens=response.usage.total_tokens,
                estimated_cost_usd=Decimal(str(cost)),
                request_id=request_id,
            )

            # Log billing (Phase 1: just logging)
            await billing_service.log_billing(billing_metadata)

            logger.info(f"[{request_id}] Chat completion successful")

            # Record metrics
            response_time = time.time() - start_time
            metrics_collector.record_request(
                model=body.model,
                success=True,
                prompt_tokens=response.usage.prompt_tokens,
                completion_tokens=response.usage.completion_tokens,
                cost_usd=float(cost),
                response_time=response_time,
            )

            return response

    except InvalidRequestException as e:
        logger.warning(f"[{request_id}] Invalid request: {e}")
        metrics_collector.record_request(model=body.model, success=False)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except InvalidModelException as e:
        logger.warning(f"[{request_id}] Invalid model: {e}")
        metrics_collector.record_request(model=body.model, success=False)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except AIProviderException:
        # Log full error details internally
        logger.exception(f"[{request_id}] AI provider error")
        metrics_collector.record_request(model=body.model, success=False)
        # Return generic error to client (no internal details)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="AI provider error - please try again later",
        )
    except Exception:
        # Log full error details internally
        logger.exception(f"[{request_id}] Unexpected error processing chat completion")
        metrics_collector.record_request(model=body.model, success=False)
        # Return generic error to client (no internal details)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error - please try again later",
        )


async def _stream_real_response(
    gemini_client,
    billing_service,
    messages,
    model,
    temperature,
    max_tokens,
    user_id,
    request_id,
):
    """
    Stream responses from Gemini in real-time with OpenAI-compatible format

    This function streams tokens as they arrive from Gemini, providing
    true streaming behavior for better UX on long responses.
    """
    prompt_tokens = 0
    completion_tokens = 0
    total_tokens = 0

    try:
        # Stream chunks from Gemini
        async for chunk in gemini_client.generate_completion_stream(
            messages=messages,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
        ):
            # Extract usage data from final chunk for billing
            if "usage" in chunk:
                prompt_tokens = chunk["usage"]["prompt_tokens"]
                completion_tokens = chunk["usage"]["completion_tokens"]
                total_tokens = chunk["usage"]["total_tokens"]

            # Send chunk in SSE format
            yield f"data: {json.dumps(chunk)}\n\n"

        # Send the done signal
        yield "data: [DONE]\n\n"

        # Calculate cost and log billing after stream completes
        if total_tokens > 0:
            cost = billing_service.calculate_cost(
                model=model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
            )

            billing_metadata = BillingMetadata(
                user_id=user_id,
                model=model,
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=total_tokens,
                estimated_cost_usd=Decimal(str(cost)),
                request_id=request_id,
            )

            await billing_service.log_billing(billing_metadata)
            logger.info(f"[{request_id}] Streaming completion successful")

    except Exception as e:
        logger.error(f"[{request_id}] Error during streaming: {e}")
        # Send error in SSE format
        error_chunk = {
            "error": {
                "message": "Internal server error during streaming",
                "type": "server_error",
            }
        }
        yield f"data: {json.dumps(error_chunk)}\n\n"
