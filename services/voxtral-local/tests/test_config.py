"""Tests for configuration module."""

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ServiceConfig


class TestServiceConfig:
    """Tests for ServiceConfig class."""

    def test_default_port(self):
        """Test default port is set correctly."""
        assert ServiceConfig.DEFAULT_PORT == 11344

    def test_model_id(self):
        """Test default model ID contains Voxtral."""
        assert "Voxtral" in ServiceConfig.MODEL_ID
        assert "mistralai" in ServiceConfig.MODEL_ID

    def test_max_audio_duration_30_minutes(self):
        """Test max audio duration is 30 minutes (1800 seconds)."""
        assert ServiceConfig.MAX_AUDIO_DURATION_SECONDS == 1800

    def test_audio_sample_rate_16khz(self):
        """Test audio sample rate is 16kHz."""
        assert ServiceConfig.AUDIO_SAMPLE_RATE == 16000

    def test_cache_dir_exists(self):
        """Test cache directory is configured."""
        assert ServiceConfig.CACHE_DIR is not None
        assert "voxtral-local" in str(ServiceConfig.CACHE_DIR)

    def test_log_dir_exists(self):
        """Test log directory is configured."""
        assert ServiceConfig.LOG_DIR is not None
        assert "voxtral-local" in str(ServiceConfig.LOG_DIR)

    def test_supported_audio_formats(self):
        """Test supported audio formats include common formats."""
        formats = ServiceConfig.SUPPORTED_AUDIO_FORMATS
        assert "wav" in formats
        assert "mp3" in formats
        assert "m4a" in formats
        assert "flac" in formats

    def test_generation_config_transcription(self):
        """Test transcription generation config is deterministic."""
        config = ServiceConfig.get_generation_config("transcription")
        # Note: temperature removed - Voxtral doesn't accept it
        assert config["do_sample"] is False
        assert config["num_beams"] == 1
        assert "max_new_tokens" in config

    def test_generation_config_general(self):
        """Test general generation config has expected keys."""
        config = ServiceConfig.get_generation_config("general")
        assert "max_new_tokens" in config
        assert "top_p" in config
        assert "temperature" in config

    def test_get_device_returns_valid_device(self):
        """Test get_device returns a valid device string."""
        device = ServiceConfig.get_device()
        assert device in ["cuda", "mps", "cpu"]

    def test_get_model_path_returns_path(self):
        """Test get_model_path returns a Path object."""
        path = ServiceConfig.get_model_path()
        assert isinstance(path, Path)
        assert "mistralai" in str(path) or "Voxtral" in str(path)

    def test_chunk_size_seconds(self):
        """Test audio chunk size is reasonable (30-600 seconds for Voxtral's long audio support)."""
        assert 30 <= ServiceConfig.AUDIO_CHUNK_SIZE_SECONDS <= 600

    def test_max_audio_size_mb(self):
        """Test max audio size is set."""
        assert ServiceConfig.MAX_AUDIO_SIZE_MB > 0
        assert ServiceConfig.MAX_AUDIO_SIZE_MB <= 500  # Reasonable limit
