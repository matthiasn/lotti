"""Pytest configuration and fixtures"""

import os
import socket

import pytest

from src.core.exceptions import DatabaseConnectionException


def is_tigerbeetle_available(host: str = "localhost", port: int = 3000) -> bool:
    """Check if TigerBeetle is reachable via TCP connection."""
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


@pytest.fixture(scope="session", autouse=True)
def test_env_vars():
    """Set test environment variables and clean up after tests"""
    # Save original values
    original_values = {
        "TIGERBEETLE_HOST": os.environ.get("TIGERBEETLE_HOST"),
        "TIGERBEETLE_PORT": os.environ.get("TIGERBEETLE_PORT"),
    }

    # Set test values
    os.environ["TIGERBEETLE_HOST"] = "localhost"
    os.environ["TIGERBEETLE_PORT"] = "3000"

    yield

    # Restore or remove environment variables
    for key, value in original_values.items():
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value


@pytest.fixture(scope="session")
def anyio_backend():
    """Use asyncio for async tests"""
    return "asyncio"


@pytest.fixture(scope="session")
def tigerbeetle_available():
    """Check if TigerBeetle is available for integration tests."""
    host = os.environ.get("TIGERBEETLE_HOST", "localhost")
    port = int(os.environ.get("TIGERBEETLE_PORT", "3000"))
    return is_tigerbeetle_available(host, port)


@pytest.fixture
async def app(tigerbeetle_available):
    """Get the FastAPI app with lifespan.

    Skips tests if TigerBeetle is not available.
    """
    if not tigerbeetle_available:
        pytest.skip("TigerBeetle is not available - skipping integration test")

    from src.main import app

    # Trigger lifespan startup
    try:
        async with app.router.lifespan_context(app):
            yield app
    except DatabaseConnectionException as e:
        pytest.skip(f"TigerBeetle connection failed: {e}")
