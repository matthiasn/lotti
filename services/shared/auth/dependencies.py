"""Shared auth dependencies for public, internal, and admin routes."""

from __future__ import annotations

from dataclasses import dataclass
import os
from typing import Literal

from fastapi import HTTPException, Request, status


AUTH_SUBJECT_HEADER = "X-Authenticated-Subject"


@dataclass(frozen=True)
class AuthContext:
    """Authenticated request context."""

    subject: str | None
    auth_type: Literal["user_token", "internal_api_key", "admin_api_key"]


def _load_keys(env_name: str) -> set[str]:
    return {key.strip() for key in os.getenv(env_name, "").split(",") if key.strip()}


def _internal_api_keys() -> set[str]:
    internal_keys = _load_keys("INTERNAL_API_KEYS")
    if internal_keys:
        return internal_keys
    # Backward-compatible fallback for existing deployments.
    return _load_keys("API_KEYS")


def _admin_api_keys() -> set[str]:
    return _load_keys("ADMIN_API_KEYS")


def _parse_bearer_token(request: Request) -> str:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    parts = auth_header.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Authorization header format. Use: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return parts[1]


def _service_context_for_token(token: str) -> AuthContext | None:
    if token in _admin_api_keys():
        return AuthContext(subject=None, auth_type="admin_api_key")
    if token in _internal_api_keys():
        return AuthContext(subject=None, auth_type="internal_api_key")
    return None


def _trusted_subject_from_header(request: Request) -> str:
    subject = request.headers.get(AUTH_SUBJECT_HEADER, "").strip()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Missing {AUTH_SUBJECT_HEADER} header for trusted internal caller",
        )
    return subject


def _decode_user_token(token: str) -> dict:
    secret = os.getenv("USER_JWT_SECRET", "")
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User token authentication is not configured",
        )

    try:
        import jwt
    except ImportError as exc:  # pragma: no cover - exercised via runtime environment
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User token authentication dependency is not installed",
        ) from exc

    algorithms = [
        algorithm.strip()
        for algorithm in os.getenv("USER_JWT_ALGORITHMS", "HS256").split(",")
        if algorithm.strip()
    ]
    kwargs: dict[str, str] = {}

    issuer = os.getenv("USER_JWT_ISSUER", "").strip()
    if issuer:
        kwargs["issuer"] = issuer

    audience = os.getenv("USER_JWT_AUDIENCE", "").strip()
    if audience:
        kwargs["audience"] = audience

    try:
        return jwt.decode(token, secret, algorithms=algorithms, **kwargs)
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


async def require_authenticated_subject(request: Request) -> AuthContext:
    """Authenticate either a user token or a trusted internal caller with subject context."""

    token = _parse_bearer_token(request)

    service_context = _service_context_for_token(token)
    if service_context is not None:
        subject = _trusted_subject_from_header(request)
        return AuthContext(subject=subject, auth_type=service_context.auth_type)

    claims = _decode_user_token(token)
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User token does not contain a valid subject",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return AuthContext(subject=subject.strip(), auth_type="user_token")


async def require_internal_or_admin_api_key(request: Request) -> AuthContext:
    """Require an internal or admin service API key."""

    token = _parse_bearer_token(request)
    service_context = _service_context_for_token(token)
    if service_context is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Internal service authentication required",
        )
    return service_context


async def require_admin_api_key(request: Request) -> AuthContext:
    """Require an admin API key."""

    token = _parse_bearer_token(request)
    if token not in _admin_api_keys():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin authentication required",
        )
    return AuthContext(subject=None, auth_type="admin_api_key")
