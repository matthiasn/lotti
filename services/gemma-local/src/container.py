"""Dependency injection container"""

from typing import Dict, Any, cast, Callable, TypeVar

from .core.interfaces import (
    IConfigManager,
    IModelManager,
    IModelDownloader,
    IModelValidator,
    ITranscriptionService,
    IChatService,
    IAudioProcessor,
)
from .core.constants import (
    SERVICE_CONFIG_MANAGER, SERVICE_MODEL_MANAGER, SERVICE_AUDIO_PROCESSOR,
    SERVICE_MODEL_VALIDATOR, SERVICE_MODEL_DOWNLOADER, SERVICE_TRANSCRIPTION_SERVICE,
    SERVICE_CHAT_SERVICE
)

T = TypeVar('T')


class Container:
    """Simple dependency injection container"""

    def __init__(self) -> None:
        self._services: Dict[str, Any] = {}
        self._factories: Dict[str, Callable[[], Any]] = {}
        self._configure_factories()

    def _configure_factories(self) -> None:
        """Configure service factory functions for lazy initialization"""
        # Lazy import to avoid circular dependencies and startup overhead
        self._factories[SERVICE_CONFIG_MANAGER] = lambda: self._create_config_manager()
        self._factories[SERVICE_MODEL_MANAGER] = lambda: self._create_model_manager()
        self._factories[SERVICE_AUDIO_PROCESSOR] = lambda: self._create_audio_processor()
        self._factories[SERVICE_MODEL_VALIDATOR] = lambda: self._create_model_validator()
        self._factories[SERVICE_MODEL_DOWNLOADER] = lambda: self._create_model_downloader()
        self._factories[SERVICE_TRANSCRIPTION_SERVICE] = lambda: self._create_transcription_service()
        self._factories[SERVICE_CHAT_SERVICE] = lambda: self._create_chat_service()

    def _create_config_manager(self) -> Any:
        """Create config manager service"""
        from .services.config_manager import ConfigManager
        return ConfigManager()

    def _create_model_manager(self) -> Any:
        """Create model manager service"""
        from .adapters.model_manager_adapter import ModelManagerAdapter
        return ModelManagerAdapter(self.get_config_manager())

    def _create_audio_processor(self) -> Any:
        """Create audio processor service"""
        from .adapters.audio_processor_adapter import AudioProcessorAdapter
        return AudioProcessorAdapter()

    def _create_model_validator(self) -> Any:
        """Create model validator service"""
        from .services.model_validator import ModelValidator
        return ModelValidator(self.get_config_manager(), self.get_model_manager())

    def _create_model_downloader(self) -> Any:
        """Create model downloader service"""
        from .services.model_downloader import ModelDownloader
        return ModelDownloader(self.get_config_manager())

    def _create_transcription_service(self) -> Any:
        """Create transcription service"""
        from .services.transcription_service import TranscriptionService
        return TranscriptionService(
            self.get_model_manager(),
            self.get_audio_processor(),
            self.get_model_validator()
        )

    def _create_chat_service(self) -> Any:
        """Create chat service"""
        from .services.chat_service import ChatService
        return ChatService(
            self.get_model_manager(),
            self.get_model_validator(),
            self.get_transcription_service()
        )

    def get(self, service_name: str) -> Any:
        """Get a service by name (lazy initialization)"""
        if service_name not in self._services:
            if service_name not in self._factories:
                raise ValueError(f"Service '{service_name}' not found")
            # Lazy initialization - create service when first requested
            self._services[service_name] = self._factories[service_name]()
        return self._services[service_name]

    def get_config_manager(self) -> IConfigManager:
        """Get config manager service"""
        return cast(IConfigManager, self.get(SERVICE_CONFIG_MANAGER))

    def get_model_manager(self) -> IModelManager:
        """Get model manager service"""
        return cast(IModelManager, self.get(SERVICE_MODEL_MANAGER))

    def get_model_downloader(self) -> IModelDownloader:
        """Get model downloader service"""
        return cast(IModelDownloader, self.get(SERVICE_MODEL_DOWNLOADER))

    def get_model_validator(self) -> IModelValidator:
        """Get model validator service"""
        return cast(IModelValidator, self.get(SERVICE_MODEL_VALIDATOR))

    def get_transcription_service(self) -> ITranscriptionService:
        """Get transcription service"""
        return cast(ITranscriptionService, self.get(SERVICE_TRANSCRIPTION_SERVICE))

    def get_chat_service(self) -> IChatService:
        """Get chat service"""
        return cast(IChatService, self.get(SERVICE_CHAT_SERVICE))

    def get_audio_processor(self) -> IAudioProcessor:
        """Get audio processor service"""
        return cast(IAudioProcessor, self.get(SERVICE_AUDIO_PROCESSOR))


# Global container instance
container = Container()
