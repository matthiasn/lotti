"""Custom exceptions for the Gemma service"""

from typing import Optional


class GemmaServiceError(Exception):
    """Base exception for all Gemma service errors"""

    pass


class ModelNotFoundError(GemmaServiceError):
    """Raised when requested model is not found"""

    def __init__(self, model_name: str, message: Optional[str] = None):
        self.model_name = model_name
        super().__init__(message or f"Model '{model_name}' not found")


class ModelLoadError(GemmaServiceError):
    """Raised when model fails to load"""

    pass


class ModelDownloadError(GemmaServiceError):
    """Raised when model download fails"""

    def __init__(self, model_name: str, reason: str):
        self.model_name = model_name
        self.reason = reason
        super().__init__(f"Failed to download model '{model_name}': {reason}")


class AudioProcessingError(GemmaServiceError):
    """Raised when audio processing fails"""

    pass


class TranscriptionError(GemmaServiceError):
    """Raised when transcription fails"""

    pass


class ConfigurationError(GemmaServiceError):
    """Raised when configuration is invalid"""

    pass


class ValidationError(GemmaServiceError):
    """Raised when validation fails"""

    pass
