"""Model validation service"""

import logging
from pathlib import Path
from typing import Optional

from ..core.interfaces import IModelValidator, IConfigManager, IModelManager
from ..core.exceptions import ModelNotFoundError, ValidationError


logger = logging.getLogger(__name__)


class ModelValidator(IModelValidator):
    """Validates model requests and manages model switching"""

    def __init__(
        self,
        config_manager: IConfigManager,
        model_manager: IModelManager
    ):
        self.config_manager = config_manager
        self.model_manager = model_manager

    def validate_model_request(self, requested_model: str) -> bool:
        """Validate if requested model can be served"""
        if not requested_model:
            raise ValidationError("Model name cannot be empty")

        # Check if model files exist on disk
        model_path = self._get_model_path(requested_model)
        return model_path.exists() and any(model_path.glob("*.safetensors"))

    async def ensure_model_available(self, requested_model: str) -> None:
        """Ensure requested model is available, switching config if needed"""
        if not self.validate_model_request(requested_model):
            logger.warning(f"Requested model '{requested_model}' not found on disk")
            raise ModelNotFoundError(
                requested_model,
                f"Model '{requested_model}' not downloaded. Use /v1/models/pull to download."
            )

        # Check if we need to switch model configuration
        current_model = self.config_manager.get_model_id().replace('google/', '')
        if requested_model != current_model:
            logger.info(f"Switching server configuration from '{current_model}' to '{requested_model}'")
            await self._switch_model_config(requested_model)

    async def _switch_model_config(self, requested_model: str) -> None:
        """Switch server configuration to use the requested model"""
        # Build full model ID
        if 'google/' not in requested_model:
            model_id = f'google/{requested_model}'
        else:
            model_id = requested_model

        # Update configuration
        self.config_manager.set_model_id(model_id)

        # Update variant
        if 'E4B' in requested_model.upper():
            self.config_manager.set_model_variant('E4B')
        elif 'E2B' in requested_model.upper():
            self.config_manager.set_model_variant('E2B')

        # Unload current model so it reloads with new config
        if self.model_manager.is_model_loaded():
            await self.model_manager.unload_model()

        # Refresh model manager config
        self.model_manager.refresh_config()

    def _get_model_path(self, model_name: str) -> Path:
        """Get the filesystem path for a model"""
        if 'google/' not in model_name:
            model_id = f'google/{model_name}'
        else:
            model_id = model_name

        cache_dir = self.config_manager.get_cache_dir()
        return cache_dir / "models" / model_id.replace("/", "--")

    def get_available_models(self) -> list[str]:
        """Get list of available models on disk"""
        cache_dir = self.config_manager.get_cache_dir()
        models_dir = cache_dir / "models"

        if not models_dir.exists():
            return []

        available_models = []
        for model_dir in models_dir.iterdir():
            if model_dir.is_dir() and any(model_dir.glob("*.safetensors")):
                # Convert directory name back to model ID
                model_id = model_dir.name.replace("--", "/")
                available_models.append(model_id)

        return available_models