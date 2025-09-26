"""Configuration management service"""

import os
from pathlib import Path
from typing import Optional

from ..core.interfaces import IConfigManager
from ..core.exceptions import ConfigurationError


class ConfigManager(IConfigManager):
    """Manages application configuration with environment variable support"""

    def __init__(self):
        self._cache = {}

    def get_model_id(self) -> str:
        """Get current model ID"""
        return os.environ.get('GEMMA_MODEL_ID', 'google/gemma-3n-E2B-it')

    def set_model_id(self, model_id: str) -> None:
        """Set model ID"""
        if not model_id:
            raise ConfigurationError("Model ID cannot be empty")
        os.environ['GEMMA_MODEL_ID'] = model_id

    def get_model_variant(self) -> str:
        """Get current model variant"""
        return os.environ.get('GEMMA_MODEL_VARIANT', 'E2B')

    def set_model_variant(self, variant: str) -> None:
        """Set model variant"""
        if variant not in ['E2B', 'E4B']:
            raise ConfigurationError(f"Invalid model variant: {variant}")
        os.environ['GEMMA_MODEL_VARIANT'] = variant

    def get_cache_dir(self) -> Path:
        """Get cache directory"""
        cache_dir = os.environ.get('GEMMA_CACHE_DIR', str(Path.home() / '.cache' / 'gemma-local'))
        return Path(cache_dir)

    def get_huggingface_token(self) -> Optional[str]:
        """Get HuggingFace token from various environment variables"""
        return (
            os.environ.get('HUGGINGFACE_TOKEN') or
            os.environ.get('HF_TOKEN') or
            os.environ.get('HUGGING_FACE_HUB_TOKEN')
        )

    def get_device(self) -> str:
        """Get compute device"""
        return os.environ.get('GEMMA_DEVICE', 'auto')

    def get_log_level(self) -> str:
        """Get log level"""
        return os.environ.get('LOG_LEVEL', 'INFO')

    def get_host(self) -> str:
        """Get server host"""
        return os.environ.get('HOST', '0.0.0.0')

    def get_port(self) -> int:
        """Get server port"""
        try:
            return int(os.environ.get('PORT', '8000'))
        except ValueError:
            raise ConfigurationError("Invalid PORT value")

    def validate_config(self) -> None:
        """Validate configuration"""
        # Check required directories exist
        cache_dir = self.get_cache_dir()
        cache_dir.mkdir(parents=True, exist_ok=True)

        # Validate model settings
        model_id = self.get_model_id()
        if not model_id.startswith('google/'):
            raise ConfigurationError(f"Invalid model ID format: {model_id}")

        variant = self.get_model_variant()
        if variant not in ['E2B', 'E4B']:
            raise ConfigurationError(f"Invalid model variant: {variant}")