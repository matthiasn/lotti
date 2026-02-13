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
        assert ServiceConfig.DEFAULT_PORT == 11345

    def test_model_id(self):
        """Test default model ID is Qwen-Image."""
        assert ServiceConfig.MODEL_ID == "Qwen/Qwen-Image"

    def test_default_width(self):
        """Test default image width is 1664 (16:9)."""
        assert ServiceConfig.DEFAULT_WIDTH == 1664

    def test_default_height(self):
        """Test default image height is 928 (16:9)."""
        assert ServiceConfig.DEFAULT_HEIGHT == 928

    def test_default_inference_steps(self):
        """Test default inference steps is 50."""
        assert ServiceConfig.DEFAULT_INFERENCE_STEPS == 50

    def test_default_cfg_scale(self):
        """Test default CFG scale is 4.0."""
        assert ServiceConfig.DEFAULT_CFG_SCALE == 4.0

    def test_generation_timeout(self):
        """Test generation timeout is 300 seconds."""
        assert ServiceConfig.GENERATION_TIMEOUT == 300

    def test_cache_dir_exists(self):
        """Test cache directory is configured."""
        assert ServiceConfig.CACHE_DIR is not None
        assert "qwen-image" in str(ServiceConfig.CACHE_DIR)

    def test_log_dir_exists(self):
        """Test log directory is configured."""
        assert ServiceConfig.LOG_DIR is not None
        assert "qwen-image" in str(ServiceConfig.LOG_DIR)

    def test_get_device_returns_valid_device(self):
        """Test get_device returns a valid device string."""
        device = ServiceConfig.get_device()
        assert device in ["cuda", "mps", "cpu"]

    def test_get_model_path_returns_path(self):
        """Test get_model_path returns a Path object."""
        path = ServiceConfig.get_model_path()
        assert isinstance(path, Path)
        assert "Qwen--Qwen-Image" in str(path)

    def test_get_generation_config_has_required_keys(self):
        """Test generation config contains all required parameters."""
        config = ServiceConfig.get_generation_config()
        assert "width" in config
        assert "height" in config
        assert "num_inference_steps" in config
        assert "true_cfg_scale" in config

    def test_get_generation_config_values(self):
        """Test generation config uses configured defaults."""
        config = ServiceConfig.get_generation_config()
        assert config["width"] == 1664
        assert config["height"] == 928
        assert config["num_inference_steps"] == 50
        assert config["true_cfg_scale"] == 4.0

    def test_validate_dimensions_valid(self):
        """Test valid dimensions are accepted."""
        assert ServiceConfig.validate_dimensions(1664, 928) is True
        assert ServiceConfig.validate_dimensions(1024, 1024) is True
        assert ServiceConfig.validate_dimensions(512, 512) is True

    def test_validate_dimensions_too_small(self):
        """Test dimensions below minimum are rejected."""
        assert ServiceConfig.validate_dimensions(256, 256) is False
        assert ServiceConfig.validate_dimensions(511, 1024) is False

    def test_validate_dimensions_too_large(self):
        """Test dimensions above maximum are rejected."""
        assert ServiceConfig.validate_dimensions(4096, 4096) is False
        assert ServiceConfig.validate_dimensions(1024, 2049) is False

    def test_supported_dimensions_contains_16_9(self):
        """Test 16:9 aspect ratio is supported."""
        assert "16:9" in ServiceConfig.SUPPORTED_DIMENSIONS
        assert ServiceConfig.SUPPORTED_DIMENSIONS["16:9"] == (1664, 928)

    def test_supported_dimensions_contains_1_1(self):
        """Test 1:1 aspect ratio is supported."""
        assert "1:1" in ServiceConfig.SUPPORTED_DIMENSIONS
        assert ServiceConfig.SUPPORTED_DIMENSIONS["1:1"] == (1024, 1024)

    def test_max_concurrent_requests(self):
        """Test max concurrent requests is set (image gen is resource-heavy)."""
        assert ServiceConfig.MAX_CONCURRENT_REQUESTS >= 1
