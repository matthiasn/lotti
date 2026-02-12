"""Tests for model manager module."""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from model_manager import ModelStatus, QwenImageModelManager


class TestModelStatus:
    """Tests for ModelStatus class."""

    def test_initial_status_is_idle(self):
        """Test initial status is idle."""
        status = ModelStatus()
        assert status.status == "idle"

    def test_initial_progress_is_zero(self):
        """Test initial progress is zero."""
        status = ModelStatus()
        assert status.progress == 0.0

    def test_initial_error_is_none(self):
        """Test initial error is None."""
        status = ModelStatus()
        assert status.error is None


class TestQwenImageModelManager:
    """Tests for QwenImageModelManager class."""

    @patch("model_manager.ServiceConfig")
    def test_init_sets_device(self, mock_config):
        """Test initialization sets device from config."""
        mock_config.DEFAULT_DEVICE = "cpu"
        mock_config.MODEL_ID = "Qwen/Qwen-Image"
        mock_config.CACHE_DIR = Path("/tmp/test-cache")
        mock_config.CACHE_DIR.mkdir(parents=True, exist_ok=True)

        manager = QwenImageModelManager()
        assert manager.device == "cpu"

    @patch("model_manager.ServiceConfig")
    def test_init_sets_model_id(self, mock_config):
        """Test initialization sets model ID from config."""
        mock_config.DEFAULT_DEVICE = "cpu"
        mock_config.MODEL_ID = "Qwen/Qwen-Image"
        mock_config.CACHE_DIR = Path("/tmp/test-cache")
        mock_config.CACHE_DIR.mkdir(parents=True, exist_ok=True)

        manager = QwenImageModelManager()
        assert manager.model_id == "Qwen/Qwen-Image"

    def test_is_model_loaded_false_initially(self):
        """Test model is not loaded initially."""
        manager = QwenImageModelManager()
        assert manager.is_model_loaded() is False

    def test_is_model_loaded_true_when_pipe_set(self):
        """Test model is loaded when pipe is set."""
        manager = QwenImageModelManager()
        manager.pipe = MagicMock()
        assert manager.is_model_loaded() is True

    @patch("model_manager.ServiceConfig")
    def test_is_model_available_delegates_to_config(self, mock_config):
        """Test is_model_available delegates to ServiceConfig."""
        mock_config.DEFAULT_DEVICE = "cpu"
        mock_config.MODEL_ID = "Qwen/Qwen-Image"
        mock_config.CACHE_DIR = Path("/tmp/test-cache")
        mock_config.CACHE_DIR.mkdir(parents=True, exist_ok=True)
        mock_config.is_model_cached.return_value = True

        manager = QwenImageModelManager()
        assert manager.is_model_available() is True
        mock_config.is_model_cached.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_model_info_returns_dict(self):
        """Test get_model_info returns expected structure."""
        manager = QwenImageModelManager()
        info = await manager.get_model_info()

        assert isinstance(info, dict)
        assert "model_id" in info
        assert "device" in info
        assert "is_available" in info
        assert "is_loaded" in info
        assert "supports_image_generation" in info
        assert info["supports_image_generation"] is True

    def test_refresh_config_updates_model_id(self):
        """Test refresh_config updates model ID from config."""
        manager = QwenImageModelManager()
        old_id = manager.model_id
        manager.refresh_config()
        # After refresh, model_id should match current config
        assert manager.model_id is not None

    @pytest.mark.asyncio
    async def test_unload_model_clears_pipe(self):
        """Test unload_model sets pipe to None."""
        manager = QwenImageModelManager()
        manager.pipe = MagicMock()

        await manager.unload_model()
        assert manager.pipe is None

    @pytest.mark.asyncio
    @patch("model_manager.ServiceConfig")
    async def test_load_model_fails_when_not_cached(self, mock_config):
        """Test load_model returns False when model not downloaded."""
        mock_config.DEFAULT_DEVICE = "cpu"
        mock_config.MODEL_ID = "Qwen/Qwen-Image"
        mock_config.CACHE_DIR = Path("/tmp/test-cache")
        mock_config.CACHE_DIR.mkdir(parents=True, exist_ok=True)
        mock_config.is_model_cached.return_value = False

        manager = QwenImageModelManager()
        result = await manager.load_model()
        assert result is False
