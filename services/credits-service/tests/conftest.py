"""Pytest configuration and fixtures"""

import os
import pytest


@pytest.fixture(scope="session", autouse=True)
def test_env_vars():
    """Set test environment variables and clean up after tests"""
    # Save original values
    original_values = {
        "TIGERBEETLE_HOST": os.environ.get("TIGERBEETLE_HOST"),
        "TIGERBEETLE_PORT": os.environ.get("TIGERBEETLE_PORT"),
        "API_KEYS": os.environ.get("API_KEYS"),
        "ADMIN_API_KEYS": os.environ.get("ADMIN_API_KEYS"),
    }

    # Set test values
    os.environ["TIGERBEETLE_HOST"] = "localhost"
    os.environ["TIGERBEETLE_PORT"] = "3000"
    os.environ["API_KEYS"] = "test-key"
    os.environ["ADMIN_API_KEYS"] = "test-key"

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


@pytest.fixture
async def app():
    """Get the FastAPI app with lifespan"""
    from src.main import app

    # Trigger lifespan startup
    async with app.router.lifespan_context(app):
        yield app
