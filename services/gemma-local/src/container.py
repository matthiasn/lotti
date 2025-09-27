"""Dependency injection container"""

from typing import Dict, Any

from .core.interfaces import (
    IConfigManager, IModelManager, IModelDownloader, IModelValidator,
    ITranscriptionService, IChatService, IAudioProcessor
)
from .services.config_manager import ConfigManager
from .services.model_validator import ModelValidator
from .services.model_downloader import ModelDownloader
from .services.transcription_service import TranscriptionService
from .services.chat_service import ChatService

# Import legacy adapters
from .adapters.model_manager_adapter import ModelManagerAdapter
from .adapters.audio_processor_adapter import AudioProcessorAdapter


class Container:
    """Simple dependency injection container"""

    def __init__(self):
        self._services: Dict[str, Any] = {}
        self._configure_services()

    def _configure_services(self):
        """Configure all service dependencies"""
        # Core services - initialize first
        config_manager = ConfigManager()
        self._services['config_manager'] = config_manager

        # Adapters for legacy code
        model_manager = ModelManagerAdapter(config_manager)
        self._services['model_manager'] = model_manager

        audio_processor = AudioProcessorAdapter()
        self._services['audio_processor'] = audio_processor

        # Business logic services
        model_validator = ModelValidator(config_manager, model_manager)
        self._services['model_validator'] = model_validator

        model_downloader = ModelDownloader(config_manager)
        self._services['model_downloader'] = model_downloader

        transcription_service = TranscriptionService(
            model_manager, audio_processor, model_validator
        )
        self._services['transcription_service'] = transcription_service

        chat_service = ChatService(
            model_manager, model_validator, transcription_service
        )
        self._services['chat_service'] = chat_service

    def get(self, service_name: str) -> Any:
        """Get a service by name"""
        if service_name not in self._services:
            raise ValueError(f"Service '{service_name}' not found")
        return self._services[service_name]

    def get_config_manager(self) -> IConfigManager:
        """Get config manager service"""
        return self.get('config_manager')

    def get_model_manager(self) -> IModelManager:
        """Get model manager service"""
        return self.get('model_manager')

    def get_model_downloader(self) -> IModelDownloader:
        """Get model downloader service"""
        return self.get('model_downloader')

    def get_model_validator(self) -> IModelValidator:
        """Get model validator service"""
        return self.get('model_validator')

    def get_transcription_service(self) -> ITranscriptionService:
        """Get transcription service"""
        return self.get('transcription_service')

    def get_chat_service(self) -> IChatService:
        """Get chat service"""
        return self.get('chat_service')

    def get_audio_processor(self) -> IAudioProcessor:
        """Get audio processor service"""
        return self.get('audio_processor')


# Global container instance
container = Container()