"""Request ID middleware for tracing requests across services"""

import uuid
from typing import Callable

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Middleware to add unique request ID to each request for tracing"""

    async def dispatch(self, request: Request, call_next: Callable):
        """
        Add request ID to request state and response headers

        Args:
            request: Incoming HTTP request
            call_next: Next middleware in chain

        Returns:
            Response with X-Request-ID header
        """
        # Check if request already has an ID (from upstream proxy/load balancer)
        request_id = request.headers.get("X-Request-ID")

        # Generate new ID if not present
        if not request_id:
            request_id = f"req-{uuid.uuid4().hex[:12]}"

        # Store in request state for access by route handlers
        request.state.request_id = request_id

        # Process request
        response = await call_next(request)

        # Add request ID to response headers for tracing
        response.headers["X-Request-ID"] = request_id

        return response
