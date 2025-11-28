"""Authentication middleware for API key validation"""

import logging
import os
from typing import Callable

from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)


class APIKeyAuthMiddleware(BaseHTTPMiddleware):
    """Middleware to validate API keys for protected endpoints"""

    def __init__(self, app, exempt_paths: list[str] = None):
        """
        Initialize authentication middleware

        Args:
            app: FastAPI application
            exempt_paths: List of paths that don't require authentication (e.g., /health)
        """
        super().__init__(app)
        self.exempt_paths = exempt_paths or ["/health", "/docs", "/openapi.json", "/redoc"]

        # Load API keys from environment variable
        # Format: API_KEYS=key1,key2,key3
        api_keys_str = os.getenv("API_KEYS", "")
        self.valid_api_keys = {key.strip() for key in api_keys_str.split(",") if key.strip()}

        if not self.valid_api_keys:
            logger.warning(
                "⚠️  No API keys configured! Set API_KEYS environment variable to enable authentication. "
                "All requests will be rejected until API keys are configured."
            )
        else:
            logger.info(f"✓ API key authentication enabled with {len(self.valid_api_keys)} key(s)")

    async def dispatch(self, request: Request, call_next: Callable):
        """
        Validate API key for each request

        Args:
            request: Incoming HTTP request
            call_next: Next middleware in chain

        Returns:
            Response from next middleware or error response
        """
        # Skip authentication for exempt paths
        if request.url.path in self.exempt_paths:
            return await call_next(request)

        # Check if API keys are configured
        if not self.valid_api_keys:
            logger.error(f"Authentication failed: No API keys configured (path: {request.url.path})")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service not configured - no API keys available",
            )

        # Extract API key from Authorization header
        auth_header = request.headers.get("Authorization", "")

        if not auth_header:
            logger.warning(f"Authentication failed: Missing Authorization header (path: {request.url.path})")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Authorization header",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Parse Bearer token
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            logger.warning(f"Authentication failed: Invalid Authorization header format (path: {request.url.path})")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Authorization header format. Use: Bearer <api_key>",
                headers={"WWW-Authenticate": "Bearer"},
            )

        api_key = parts[1]

        # Validate API key
        if api_key not in self.valid_api_keys:
            logger.warning(f"Authentication failed: Invalid API key (path: {request.url.path})")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid API key",
            )

        # API key is valid, proceed with request
        logger.debug(f"Authentication successful for {request.url.path}")
        return await call_next(request)
