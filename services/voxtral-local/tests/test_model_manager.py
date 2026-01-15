"""Tests for model manager module."""

import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from model_manager import ModelStatus, VoxtralModelManager


class TestModelStatus:
    """Tests for ModelStatus class."""

    def test_init_defaults(self):
        """Test ModelStatus initializes with correct defaults."""
        status = ModelStatus()
        assert status.status == "idle"
        assert status.progress == 0.0
        assert status.total_size == 0
        assert status.downloaded_size == 0
        assert status.message == ""
        assert status.error is None


class TestVoxtralModelManager:
    """Tests for VoxtralModelManager class."""

    @pytest.fixture
    def manager(self):
        """Create a VoxtralModelManager instance."""
        with patch("model_manager.ServiceConfig") as mock_config:
            mock_config.DEFAULT_DEVICE = "cpu"
            mock_config.MODEL_ID = "mistralai/Voxtral-Mini-3B-2507"
            mock_config.CACHE_DIR = Path("/tmp/voxtral-test")
            manager = VoxtralModelManager()
            return manager

    def test_init_sets_device(self, manager):
        """Test manager initializes with correct device."""
        assert manager.device in ["cuda", "mps", "cpu"]

    def test_init_sets_model_id(self, manager):
        """Test manager initializes with correct model ID."""
        assert "Voxtral" in manager.model_id

    def test_is_model_loaded_false_initially(self, manager):
        """Test model is not loaded initially."""
        assert manager.is_model_loaded() is False

    def test_is_model_available_checks_cache(self, manager):
        """Test is_model_available checks the cache."""
        with patch("model_manager.ServiceConfig.is_model_cached", return_value=False):
            assert manager.is_model_available() is False

    @pytest.mark.asyncio
    async def test_get_model_info_returns_dict(self, manager):
        """Test get_model_info returns expected structure."""
        with patch("model_manager.ServiceConfig.is_model_cached", return_value=False):
            info = await manager.get_model_info()

            assert "model_id" in info
            assert "device" in info
            assert "is_available" in info
            assert "is_loaded" in info
            assert "supports_audio" in info
            assert info["supports_audio"] is True

    @pytest.mark.asyncio
    async def test_get_model_info_includes_size_when_available(self, manager):
        """Test get_model_info includes size when model is available."""
        mock_path = MagicMock()
        mock_file = MagicMock()
        mock_file.stat.return_value.st_size = 1024 * 1024 * 1024  # 1GB
        mock_file.is_file.return_value = True
        mock_path.rglob.return_value = [mock_file]
        mock_path.exists.return_value = True

        with patch("model_manager.ServiceConfig.is_model_cached", return_value=True), \
             patch("model_manager.ServiceConfig.get_model_path", return_value=mock_path):
            info = await manager.get_model_info()

            assert "size_bytes" in info
            assert "size_gb" in info

    def test_refresh_config_updates_model_id(self, manager):
        """Test refresh_config updates configuration."""
        old_model_id = manager.model_id

        with patch("model_manager.ServiceConfig.MODEL_ID", "new-model-id"), \
             patch("model_manager.ServiceConfig.DEFAULT_DEVICE", "cpu"):
            manager.refresh_config()

        assert manager.model_id == "new-model-id"

    @pytest.mark.asyncio
    async def test_unload_model_clears_model(self, manager):
        """Test unload_model clears model from memory."""
        manager.model = MagicMock()
        manager.processor = MagicMock()

        await manager.unload_model()

        assert manager.model is None
        assert manager.processor is None

    @pytest.mark.asyncio
    async def test_download_model_yields_progress(self, manager):
        """Test download_model yields progress updates."""
        with patch("model_manager.ServiceConfig.is_model_cached", return_value=True):
            progress_updates = []
            async for progress in manager.download_model():
                progress_updates.append(progress)

            assert len(progress_updates) > 0
            # Should indicate already downloaded
            assert any("downloaded" in str(p).lower() for p in progress_updates)

    @pytest.mark.asyncio
    async def test_load_model_returns_false_if_not_available(self, manager):
        """Test load_model returns False if model not downloaded."""
        with patch("model_manager.ServiceConfig.is_model_cached", return_value=False):
            result = await manager.load_model()
            assert result is False

    def test_check_memory_pressure(self, manager):
        """Test memory pressure check returns boolean."""
        result = manager._check_memory_pressure()
        assert isinstance(result, bool)

    def test_force_cleanup_runs_without_error(self, manager):
        """Test force_cleanup runs without raising."""
        # Should not raise even with no model loaded
        manager._force_cleanup()

    def test_log_memory_usage_runs_without_error(self, manager):
        """Test log_memory_usage runs without raising."""
        # Should not raise
        manager._log_memory_usage("test")
