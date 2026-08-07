"""Authentication middleware for API key validation"""

from __future__ import annotations

import logging
import os
from typing import Callable

from fastapi import Request, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger(__name__)


def _deny(status_code: int, detail: str, *, challenge: bool = False) -> JSONResponse:
    """Build an auth failure response.

    Middleware must *return* this rather than raise ``HTTPException``: a
    ``BaseHTTPMiddleware`` runs above Starlette's ``ExceptionMiddleware``, so a
    raised ``HTTPException`` is never translated into its status code and
    surfaces as a 500 instead.
    """
    headers = {"WWW-Authenticate": "Bearer"} if challenge else None
    return JSONResponse(status_code=status_code, content={"detail": detail}, headers=headers)


class APIKeyAuthMiddleware(BaseHTTPMiddleware):
    """Middleware to validate API keys for protected endpoints"""

    def __init__(
        self,
        app,
        exempt_paths: list[str] | None = None,
        admin_path_prefixes: list[str] | None = None,
        client_path_prefixes: list[str] | None = None,
    ):
        """
        Initialize authentication middleware

        Args:
            app: FastAPI application
            exempt_paths: List of paths that don't require authentication (e.g., /health)
            admin_path_prefixes: List of path prefixes that require an admin API key
            client_path_prefixes: List of path prefixes reachable with a regular
                API key. Passing this flips the default for everything else to
                *admin*, so a route added later is protected unless it is
                deliberately listed. Prefer it to ``admin_path_prefixes`` on any
                service whose endpoints are mostly privileged.

        Raises:
            ValueError: If both prefix lists are given. They express opposite
                defaults, so a service that sets both has no answer for a path
                matching neither.
        """
        super().__init__(app)
        if admin_path_prefixes and client_path_prefixes:
            raise ValueError(
                "Pass admin_path_prefixes or client_path_prefixes, not both: they "
                "set opposite defaults for paths matching neither list"
            )
        self.exempt_paths = exempt_paths or ["/health", "/docs", "/openapi.json", "/redoc"]
        self.admin_path_prefixes = admin_path_prefixes or []
        self.client_path_prefixes = client_path_prefixes or []
        #: When true, a path matching no prefix requires an admin key.
        self.admin_by_default = bool(client_path_prefixes)

        # Load API keys from environment variable
        # Format: API_KEYS=key1,key2,key3
        api_keys_str = os.getenv("API_KEYS", "")
        self.valid_api_keys = {key.strip() for key in api_keys_str.split(",") if key.strip()}

        # Load admin API keys from environment variable
        # Format: ADMIN_API_KEYS=admin-key1,admin-key2
        admin_keys_str = os.getenv("ADMIN_API_KEYS", "")
        self.valid_admin_keys = {key.strip() for key in admin_keys_str.split(",") if key.strip()}

        if not self.valid_api_keys:
            logger.warning(
                "No API keys configured! Set API_KEYS environment variable to enable authentication. "
                "All requests will be rejected until API keys are configured."
            )
        else:
            logger.info(f"API key authentication enabled with {len(self.valid_api_keys)} key(s)")

        if self.valid_admin_keys:
            scope = (
                "every path except " f"{len(self.client_path_prefixes)} client prefix(es)"
                if self.admin_by_default
                else f"{len(self.admin_path_prefixes)} path prefix(es)"
            )
            logger.info(
                f"Admin API key authentication enabled with "
                f"{len(self.valid_admin_keys)} key(s) for {scope}"
            )

    @staticmethod
    def _matches_prefix(path: str, prefix: str) -> bool:
        """Whether ``path`` is ``prefix`` or sits beneath it.

        A bare ``startswith`` would treat ``/api/v1/client-admin`` as being under
        ``/api/v1/client``, which in admin-by-default mode is a privilege
        downgrade: a future admin route whose name merely begins with a client
        prefix would accept a plain API key. Matching on the segment boundary
        makes the prefix mean a path segment rather than a string.
        """
        normalised = prefix.rstrip("/")
        return path == normalised or path.startswith(f"{normalised}/")

    def _is_admin_path(self, path: str) -> bool:
        """Check if the path requires admin authentication.

        In admin-by-default mode the question is inverted: only paths explicitly
        listed as client paths escape the admin requirement. That way a route
        added later is privileged until someone says otherwise, rather than
        silently reachable with a plain client key.
        """
        if self.admin_by_default:
            return not any(
                self._matches_prefix(path, prefix) for prefix in self.client_path_prefixes
            )
        return any(self._matches_prefix(path, prefix) for prefix in self.admin_path_prefixes)

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

        # Extract API key from Authorization header
        auth_header = request.headers.get("Authorization", "")

        if not auth_header:
            logger.warning(
                f"Authentication failed: Missing Authorization header (path: {request.url.path})"
            )
            return _deny(
                status.HTTP_401_UNAUTHORIZED,
                "Missing Authorization header",
                challenge=True,
            )

        # Parse Bearer token
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            logger.warning(
                f"Authentication failed: Invalid Authorization header format (path: {request.url.path})"
            )
            return _deny(
                status.HTTP_401_UNAUTHORIZED,
                "Invalid Authorization header format. Use: Bearer <api_key>",
                challenge=True,
            )

        api_key = parts[1]

        # Check admin paths first — require admin key
        if self._is_admin_path(request.url.path):
            if not self.valid_admin_keys:
                logger.error(
                    f"Authentication failed: Admin API keys not configured for admin path (path: {request.url.path})"
                )
                return _deny(
                    status.HTTP_503_SERVICE_UNAVAILABLE,
                    "Admin API keys not configured for this endpoint",
                )
            elif api_key not in self.valid_admin_keys:
                logger.warning(
                    f"Authentication failed: Admin API key required (path: {request.url.path})"
                )
                return _deny(
                    status.HTTP_403_FORBIDDEN,
                    "Admin API key required for this endpoint",
                )

            logger.debug(f"Admin authentication successful for {request.url.path}")
            return await call_next(request)

        # Check if regular API keys are configured
        if not self.valid_api_keys:
            logger.error(
                f"Authentication failed: No API keys configured (path: {request.url.path})"
            )
            return _deny(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "Service not configured - no API keys available",
            )

        # Validate regular API key (admin keys are not accepted for non-admin paths)
        if api_key not in self.valid_api_keys:
            logger.warning(f"Authentication failed: Invalid API key (path: {request.url.path})")
            return _deny(status.HTTP_403_FORBIDDEN, "Invalid API key")

        # API key is valid, proceed with request
        logger.debug(f"Authentication successful for {request.url.path}")
        return await call_next(request)
