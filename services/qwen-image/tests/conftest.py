"""Pytest configuration and shared fixtures."""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Configure pytest-asyncio
pytest_plugins = ["pytest_asyncio"]


@pytest.fixture
def mock_model_manager():
    """Create a mock model manager for testing."""
    manager = MagicMock()
    manager.is_model_available.return_value = False
    manager.is_model_loaded.return_value = False
    manager.device = "cpu"
    manager.model_id = "Qwen/Qwen-Image"
    return manager


@pytest.fixture
def mock_image_generator():
    """Create a mock image generator for testing."""
    generator = MagicMock()
    return generator
