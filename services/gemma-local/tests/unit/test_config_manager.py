"""Unit tests for ConfigManager"""

import pytest
import os
from pathlib import Path
from unittest.mock import patch

from src.services.config_manager import ConfigManager
from src.core.exceptions import ConfigurationError


@pytest.mark.unit
class TestConfigManager:
    """Test ConfigManager functionality"""

    def test_get_model_id_default(self) -> None:
        """Test getting default model ID"""
        config = ConfigManager()
        # Clear any existing env var
        original = os.environ.pop("GEMMA_MODEL_ID", None)
        try:
            assert config.get_model_id() == "google/gemma-3n-E2B-it"
        finally:
            if original:
                os.environ["GEMMA_MODEL_ID"] = original

    def test_get_model_id_from_env(self) -> None:
        """Test getting model ID from environment"""
        config = ConfigManager()
        os.environ["GEMMA_MODEL_ID"] = "google/gemma-3n-E4B-it"
        try:
            assert config.get_model_id() == "google/gemma-3n-E4B-it"
        finally:
            os.environ.pop("GEMMA_MODEL_ID", None)

    def test_set_model_id(self) -> None:
        """Test setting model ID"""
        config = ConfigManager()
        config.set_model_id("google/gemma-3n-E4B-it")
        assert os.environ["GEMMA_MODEL_ID"] == "google/gemma-3n-E4B-it"

    def test_set_model_id_empty_raises_error(self) -> None:
        """Test that setting empty model ID raises error"""
        config = ConfigManager()
        with pytest.raises(ConfigurationError, match="Model ID cannot be empty"):
            config.set_model_id("")

    def test_get_model_variant_default(self) -> None:
        """Test getting default model variant"""
        config = ConfigManager()
        original = os.environ.pop("GEMMA_MODEL_VARIANT", None)
        try:
            assert config.get_model_variant() == "E2B"
        finally:
            if original:
                os.environ["GEMMA_MODEL_VARIANT"] = original

    def test_set_model_variant_valid(self) -> None:
        """Test setting valid model variant"""
        config = ConfigManager()
        config.set_model_variant("E4B")
        assert os.environ["GEMMA_MODEL_VARIANT"] == "E4B"

    def test_set_model_variant_invalid_raises_error(self) -> None:
        """Test that setting invalid model variant raises error"""
        config = ConfigManager()
        with pytest.raises(ConfigurationError, match="Invalid model variant"):
            config.set_model_variant("INVALID")

    def test_get_cache_dir_default(self) -> None:
        """Test getting default cache directory"""
        config = ConfigManager()
        original = os.environ.pop("GEMMA_CACHE_DIR", None)
        try:
            expected = Path.home() / ".cache" / "gemma-local"
            assert config.get_cache_dir() == expected
        finally:
            if original:
                os.environ["GEMMA_CACHE_DIR"] = original

    def test_get_huggingface_token_priority(self) -> None:
        """Test HuggingFace token retrieval priority"""
        config = ConfigManager()

        # Clear all possible tokens
        original_tokens = {}
        for key in ["HUGGINGFACE_TOKEN", "HF_TOKEN", "HUGGING_FACE_HUB_TOKEN"]:
            original_tokens[key] = os.environ.pop(key, None)

        try:
            # Test with no tokens
            assert config.get_huggingface_token() is None

            # Test priority order
            os.environ["HUGGING_FACE_HUB_TOKEN"] = "token3"
            os.environ["HF_TOKEN"] = "token2"
            os.environ["HUGGINGFACE_TOKEN"] = "token1"

            # Should return the first one (highest priority)
            assert config.get_huggingface_token() == "token1"

            # Remove highest priority, should get next
            os.environ.pop("HUGGINGFACE_TOKEN")
            assert config.get_huggingface_token() == "token2"

        finally:
            # Restore original values
            for key, value in original_tokens.items():
                if value:
                    os.environ[key] = value

    def test_get_port_default(self) -> None:
        """Test getting default port"""
        config = ConfigManager()
        original = os.environ.pop("PORT", None)
        try:
            assert config.get_port() == 11343  # Gemma service default port
        finally:
            if original:
                os.environ["PORT"] = original

    def test_get_port_invalid_raises_error(self) -> None:
        """Test that invalid port raises error"""
        config = ConfigManager()
        os.environ["PORT"] = "invalid"
        try:
            with pytest.raises(ConfigurationError, match="Invalid PORT value"):
                config.get_port()
        finally:
            os.environ.pop("PORT", None)

    def test_validate_config_creates_cache_dir(self, tmp_path) -> None:
        """Test that config validation creates cache directory"""
        config = ConfigManager()
        cache_dir = tmp_path / "test-cache"

        # Mock the cache dir
        original = os.environ.get("GEMMA_CACHE_DIR")
        os.environ["GEMMA_CACHE_DIR"] = str(cache_dir)

        try:
            assert not cache_dir.exists()
            config.validate_config()
            assert cache_dir.exists()
        finally:
            if original:
                os.environ["GEMMA_CACHE_DIR"] = original
            else:
                os.environ.pop("GEMMA_CACHE_DIR", None)

    def test_validate_config_invalid_model_id(self) -> None:
        """Test that config validation catches invalid model ID"""
        config = ConfigManager()
        os.environ["GEMMA_MODEL_ID"] = "invalid-model-id"

        try:
            with pytest.raises(ConfigurationError, match="Invalid model ID format"):
                config.validate_config()
        finally:
            os.environ.pop("GEMMA_MODEL_ID", None)

    def test_get_model_revision_default(self) -> None:
        """Test getting model revision defaults to main"""
        config = ConfigManager()
        revision = config.get_model_revision("google/gemma-3n-E2B-it")
        assert revision == "main"

    def test_get_model_revision_from_general_env(self) -> None:
        """Test getting model revision from general environment variable"""
        config = ConfigManager()
        with patch.dict(os.environ, {"GEMMA_MODEL_REVISION": "v1.2.3"}):
            revision = config.get_model_revision("google/gemma-3n-E2B-it")
            assert revision == "v1.2.3"

    def test_get_model_revision_from_specific_env(self) -> None:
        """Test getting model revision from model-specific environment variable"""
        config = ConfigManager()
        with patch.dict(
            os.environ,
            {
                "GOOGLE_GEMMA_3N_E2B_IT_REVISION": "specific-rev",
                "GEMMA_MODEL_REVISION": "general-rev",
            },
        ):
            revision = config.get_model_revision("google/gemma-3n-E2B-it")
            assert revision == "specific-rev"  # Specific should override general

    def test_get_host_default_secure(self) -> None:
        """Test that default host is localhost for security"""
        config = ConfigManager()
        with patch.dict(os.environ, {}, clear=True):
            # Clear HOST env var for this test
            os.environ.pop("HOST", None)
            host = config.get_host()
            assert host == "127.0.0.1"  # Should default to localhost, not 0.0.0.0

    def test_get_host_rejects_all_interfaces(self) -> None:
        """Test that binding to all interfaces is rejected for security"""
        config = ConfigManager()
        # Test that 0.0.0.0 is rejected and defaults to localhost
        with patch.dict(os.environ, {"HOST": "0.0.0.0"}):  # nosec B104 - Testing security rejection
            host = config.get_host()
            # Should override to safe default
            assert host == "127.0.0.1"

    def test_get_host_allows_specific_ip(self) -> None:
        """Test that specific IP addresses are allowed"""
        config = ConfigManager()
        # Test that specific IPs are allowed
        specific_ip = "192.168.1.100"
        with patch.dict(os.environ, {"HOST": specific_ip}):
            host = config.get_host()
            assert host == specific_ip
