"""Configuration management service"""

import os
from pathlib import Path
from typing import Optional, Dict, Any

from ..core.interfaces import IConfigManager
from ..core.exceptions import ConfigurationError
from ..core.constants import (
    DEFAULT_MODEL_ID, DEFAULT_MODEL_VARIANT, DEFAULT_MODEL_REVISION,
    DEFAULT_CACHE_DIR_NAME, DEFAULT_DEVICE, DEFAULT_LOG_LEVEL,
    DEFAULT_HOST, DEFAULT_PORT, ALLOWED_MODEL_VARIANTS, ALLOWED_MODEL_PREFIXES,
    ENV_GEMMA_MODEL_ID, ENV_GEMMA_MODEL_VARIANT, ENV_GEMMA_MODEL_REVISION,
    ENV_GEMMA_CACHE_DIR, ENV_GEMMA_DEVICE, ENV_HOST, ENV_PORT, ENV_LOG_LEVEL,
    ENV_HUGGINGFACE_TOKEN, ENV_HF_TOKEN, ENV_HUGGING_FACE_HUB_TOKEN,
    ERROR_EMPTY_MODEL_ID, ERROR_INVALID_PORT, ERROR_INVALID_MODEL_FORMAT,
    ERROR_INVALID_VARIANT
)


class ConfigManager(IConfigManager):
    """Manages application configuration with environment variable support"""

    def __init__(self) -> None:
        self._cache: Dict[str, Any] = {}

    def get_model_id(self) -> str:
        """Get current model ID"""
        return os.environ.get(ENV_GEMMA_MODEL_ID, DEFAULT_MODEL_ID)

    def set_model_id(self, model_id: str) -> None:
        """Set model ID"""
        if not model_id:
            raise ConfigurationError(ERROR_EMPTY_MODEL_ID)
        os.environ[ENV_GEMMA_MODEL_ID] = model_id

    def get_model_variant(self) -> str:
        """Get current model variant"""
        return os.environ.get(ENV_GEMMA_MODEL_VARIANT, DEFAULT_MODEL_VARIANT)

    def set_model_variant(self, variant: str) -> None:
        """Set model variant"""
        if variant not in ALLOWED_MODEL_VARIANTS:
            raise ConfigurationError(f"{ERROR_INVALID_VARIANT}: {variant}")
        os.environ[ENV_GEMMA_MODEL_VARIANT] = variant

    def get_cache_dir(self) -> Path:
        """Get cache directory"""
        cache_dir = os.environ.get(ENV_GEMMA_CACHE_DIR, str(Path.home() / ".cache" / DEFAULT_CACHE_DIR_NAME))
        return Path(cache_dir)

    def get_huggingface_token(self) -> Optional[str]:
        """Get HuggingFace token from various environment variables"""
        return os.environ.get(ENV_HUGGINGFACE_TOKEN) or os.environ.get(ENV_HF_TOKEN) or os.environ.get(ENV_HUGGING_FACE_HUB_TOKEN)

    def get_model_revision(self, model_id: str) -> str:
        """Get model revision for secure downloads

        Uses environment variable or defaults to 'main' for security.
        This prevents model substitution attacks.
        """
        # Allow override via environment variable for specific model
        model_key = model_id.replace("/", "_").replace("-", "_").upper()
        env_key = f"{model_key}_REVISION"

        # Check for model-specific revision first, then general revision
        revision = os.environ.get(env_key) or os.environ.get(ENV_GEMMA_MODEL_REVISION, DEFAULT_MODEL_REVISION)
        return revision

    def get_device(self) -> str:
        """Get compute device"""
        return os.environ.get(ENV_GEMMA_DEVICE, DEFAULT_DEVICE)

    def get_log_level(self) -> str:
        """Get log level"""
        return os.environ.get(ENV_LOG_LEVEL, DEFAULT_LOG_LEVEL)

    def get_host(self) -> str:
        """Get server host

        Defaults to 127.0.0.1 (localhost only) for security.

        Security Policy:
        - Default: 127.0.0.1 (localhost only)
        - For production: Use reverse proxy (nginx, Apache, etc.)
        - If direct external access needed: Set HOST to specific interface IP
        - Binding to 0.0.0.0 is strongly discouraged for security reasons
        """
        host = os.environ.get(ENV_HOST, DEFAULT_HOST)

        # Security check: Reject binding to all interfaces
        if host == "0.0.0.0":  # nosec B104 - Security check to prevent binding to all interfaces
            import logging
            logger = logging.getLogger(__name__)
            logger.error(
                "SECURITY WARNING: Attempting to bind to all interfaces (0.0.0.0) is not allowed. "
                "Use 127.0.0.1 for localhost or a specific IP address for external access."
            )
            # Override with safe default
            logger.info("Overriding to safe default: 127.0.0.1")
            return DEFAULT_HOST

        return host

    def get_port(self) -> int:
        """Get server port"""
        try:
            return int(os.environ.get(ENV_PORT, str(DEFAULT_PORT)))
        except ValueError:
            raise ConfigurationError(ERROR_INVALID_PORT)

    def validate_config(self) -> None:
        """Validate configuration"""
        # Check required directories exist
        cache_dir = self.get_cache_dir()
        cache_dir.mkdir(parents=True, exist_ok=True)

        # Validate model settings
        model_id = self.get_model_id()
        if not any(model_id.startswith(prefix) for prefix in ALLOWED_MODEL_PREFIXES):
            raise ConfigurationError(f"{ERROR_INVALID_MODEL_FORMAT}: {model_id}")

        variant = self.get_model_variant()
        if variant not in ALLOWED_MODEL_VARIANTS:
            raise ConfigurationError(f"{ERROR_INVALID_VARIANT}: {variant}")
