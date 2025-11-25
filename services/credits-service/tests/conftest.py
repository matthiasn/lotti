"""Pytest configuration and fixtures"""

import os
import pytest

# Set test environment variables
os.environ["TIGERBEETLE_HOST"] = "localhost"
os.environ["TIGERBEETLE_PORT"] = "3000"


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
