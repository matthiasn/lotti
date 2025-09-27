"""Core interfaces for dependency injection"""

from abc import ABC, abstractmethod
from typing import AsyncGenerator, Optional, List, Dict, Any, Tuple
from pathlib import Path
import numpy as np

from .models import ModelInfo, DownloadProgress, AudioRequest, TranscriptionResult, ChatRequest, ChatResponse


class IModelManager(ABC):
    """Interface for model management operations"""

    @abstractmethod
    async def load_model(self) -> bool:
        """Load model into memory"""
        pass

    @abstractmethod
    async def unload_model(self) -> None:
        """Unload model from memory"""
        pass

    @abstractmethod
    def is_model_available(self) -> bool:
        """Check if model files exist locally"""
        pass

    @abstractmethod
    def is_model_loaded(self) -> bool:
        """Check if model is loaded in memory"""
        pass

    @abstractmethod
    def get_model_info(self) -> ModelInfo:
        """Get current model information"""
        pass

    @abstractmethod
    def refresh_config(self) -> None:
        """Refresh configuration after model change"""
        pass


class IModelDownloader(ABC):
    """Interface for model downloading operations"""

    @abstractmethod
    async def download_model(self, model_name: str, stream: bool = True) -> AsyncGenerator[DownloadProgress, None]:
        """Download model with progress tracking"""
        pass

    @abstractmethod
    def is_model_downloaded(self, model_name: str) -> bool:
        """Check if model is already downloaded"""
        pass


class IAudioProcessor(ABC):
    """Interface for audio processing operations"""

    @abstractmethod
    async def process_audio_base64(
        self,
        audio_base64: str,
        context_prompt: Optional[str] = None,
        use_chunking: bool = False,
        request_id: Optional[str] = None,
    ) -> tuple[Any, ...]:
        """Process base64 audio data"""
        pass


class ITranscriptionService(ABC):
    """Interface for transcription operations"""

    @abstractmethod
    async def transcribe_audio(self, request: AudioRequest) -> TranscriptionResult:
        """Transcribe audio to text"""
        pass


class IChatService(ABC):
    """Interface for chat completion operations"""

    @abstractmethod
    async def complete_chat(self, request: ChatRequest) -> ChatResponse:
        """Generate chat completion"""
        pass

    @abstractmethod
    async def complete_chat_stream(self, request: ChatRequest) -> AsyncGenerator[str, None]:
        """Generate streaming chat completion"""
        pass


class IModelValidator(ABC):
    """Interface for model validation operations"""

    @abstractmethod
    def validate_model_request(self, requested_model: str) -> bool:
        """Validate if requested model can be served"""
        pass

    @abstractmethod
    async def ensure_model_available(self, requested_model: str) -> None:
        """Ensure requested model is available, switching config if needed"""
        pass

    @abstractmethod
    def get_available_models(self) -> List[str]:
        """Get list of available models on disk"""
        pass


class IConfigManager(ABC):
    """Interface for configuration management"""

    @abstractmethod
    def get_model_id(self) -> str:
        """Get current model ID"""
        pass

    @abstractmethod
    def set_model_id(self, model_id: str) -> None:
        """Set model ID"""
        pass

    @abstractmethod
    def get_model_variant(self) -> str:
        """Get current model variant"""
        pass

    @abstractmethod
    def set_model_variant(self, variant: str) -> None:
        """Set model variant"""
        pass

    @abstractmethod
    def get_cache_dir(self) -> Path:
        """Get cache directory"""
        pass

    @abstractmethod
    def get_huggingface_token(self) -> Optional[str]:
        """Get HuggingFace token"""
        pass

    @abstractmethod
    def get_model_revision(self, model_id: str) -> str:
        """Get model revision for secure downloads"""
        pass

    @abstractmethod
    def get_device(self) -> str:
        """Get compute device"""
        pass

    @abstractmethod
    def get_log_level(self) -> str:
        """Get log level"""
        pass

    @abstractmethod
    def get_host(self) -> str:
        """Get server host"""
        pass

    @abstractmethod
    def get_port(self) -> int:
        """Get server port"""
        pass

    @abstractmethod
    def validate_config(self) -> None:
        """Validate configuration"""
        pass
