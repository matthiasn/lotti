"""Adapter for existing model_manager.py"""

import sys
from pathlib import Path
from typing import Any

# Add parent directory to path to import legacy modules
sys.path.append(str(Path(__file__).parent.parent.parent))

from model_manager import model_manager as legacy_model_manager
from ..core.interfaces import IModelManager, IConfigManager
from ..core.models import ModelInfo


class ModelManagerAdapter(IModelManager):
    """Adapts the legacy model_manager to the new interface"""

    def __init__(self, config_manager: IConfigManager):
        self.config_manager = config_manager
        self.legacy_manager = legacy_model_manager

    async def load_model(self) -> bool:
        """Load model into memory"""
        return await self.legacy_manager.load_model()

    async def unload_model(self) -> None:
        """Unload model from memory"""
        await self.legacy_manager.unload_model()

    def is_model_available(self) -> bool:
        """Check if model files exist locally"""
        return self.legacy_manager.is_model_available()

    def is_model_loaded(self) -> bool:
        """Check if model is loaded in memory"""
        return self.legacy_manager.is_model_loaded()

    def get_model_info(self) -> ModelInfo:
        """Get current model information"""
        return ModelInfo(
            id=self.legacy_manager.model_id,
            name=f"Gemma 3n {self.config_manager.get_model_variant()}",
            variant=self.config_manager.get_model_variant(),
            is_available=self.is_model_available(),
            is_loaded=self.is_model_loaded(),
            device=self.legacy_manager.device,
            path=Path(self.legacy_manager.model_id) if self.is_model_available() else None,
        )

    def refresh_config(self) -> None:
        """Refresh configuration after model change"""
        self.legacy_manager.refresh_config()

    @property
    def model(self) -> Any:
        """Get the underlying model for legacy compatibility"""
        return self.legacy_manager.model

    @property
    def tokenizer(self) -> Any:
        """Get the tokenizer for legacy compatibility"""
        return self.legacy_manager.tokenizer

    @property
    def processor(self) -> Any:
        """Get the processor for legacy compatibility"""
        return self.legacy_manager.processor

    @property
    def device(self) -> str:
        """Get the device for legacy compatibility"""
        return self.legacy_manager.device
