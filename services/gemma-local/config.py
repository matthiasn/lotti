"""Configuration settings for Gemma Local Service."""

import os
from pathlib import Path
import torch


class ServiceConfig:
    """Service configuration settings."""
    
    # Model settings
    MODEL_ID = os.getenv("GEMMA_MODEL_ID", "google/gemma-3n-E4B-it")  # Use Gemma 3n with audio support
    DEFAULT_DEVICE = "mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu"
    TORCH_DTYPE = torch.bfloat16 if DEFAULT_DEVICE != "cpu" else torch.float32
    
    # Audio settings
    MAX_AUDIO_SIZE_MB = int(os.getenv("MAX_AUDIO_SIZE_MB", "100"))
    AUDIO_SAMPLE_RATE = 16000
    SUPPORTED_AUDIO_FORMATS = ["wav", "mp3", "m4a", "flac", "ogg", "webm"]
    
    # API settings
    MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "4"))
    REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "300"))
    DEFAULT_PORT = int(os.getenv("PORT", "8000"))
    DEFAULT_HOST = os.getenv("HOST", "0.0.0.0")
    
    # Generation settings
    DEFAULT_MAX_TOKENS = 1000
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_TOP_P = 0.95
    DEFAULT_TOP_K = 40
    
    # Paths
    HOME_DIR = Path.home()
    CACHE_DIR = HOME_DIR / ".cache" / "gemma-local"
    LOG_DIR = HOME_DIR / ".logs" / "gemma-local"
    
    # Ensure directories exist
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Logging
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    
    @classmethod
    def get_model_path(cls) -> Path:
        """Get the local path for the model."""
        return cls.CACHE_DIR / "models" / cls.MODEL_ID.replace("/", "--")
    
    @classmethod
    def is_model_cached(cls) -> bool:
        """Check if model is already downloaded."""
        model_path = cls.get_model_path()
        return model_path.exists() and any(model_path.glob("*.safetensors"))