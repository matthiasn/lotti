"""Configuration settings for Gemma Local Service."""

import os
from pathlib import Path
import torch
import platform
from typing import Dict, Any


# Helper function for device detection
def _get_device():
    """Get the best available device with memory considerations."""
    device = os.getenv("GEMMA_DEVICE", "auto")
    
    if device == "auto":
        # Check for CUDA availability
        if torch.cuda.is_available():
            # Check CUDA memory
            try:
                mem_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                if mem_gb >= 12:  # Need at least 12GB for Gemma 3n
                    return "cuda"
            except:
                pass
        
        # Check for MPS (Apple Silicon) - enable by default for better performance
        if torch.backends.mps.is_available() and platform.system() == "Darwin":
            # Use MPS by default on Apple Silicon for better performance
            # Can be disabled with DISABLE_MPS=true if needed
            if os.getenv("DISABLE_MPS", "false").lower() != "true":
                return "mps"
        
        # Default to CPU for reliability
        return "cpu"
    
    return device


class ServiceConfig:
    """Service configuration settings."""
    
    # Model settings with variant support
    MODEL_VARIANT = os.getenv("GEMMA_MODEL_VARIANT", "E2B").upper()
    MODEL_ID = os.getenv("GEMMA_MODEL_ID", f"google/gemma-3n-{MODEL_VARIANT}-it")
    DEFAULT_DEVICE = _get_device()
    TORCH_DTYPE = torch.float16 if DEFAULT_DEVICE in ["cuda", "mps"] else torch.float32
    
    ENABLE_TORCH_COMPILE = os.getenv("ENABLE_TORCH_COMPILE", "false").lower() == "true"
    ENABLE_CPU_QUANTIZATION = os.getenv("ENABLE_CPU_QUANTIZATION", "false").lower() == "true"
    
    # Memory management settings
    LOW_MEMORY_MODE = os.getenv("LOW_MEMORY_MODE", "true").lower() == "true"
    MAX_MEMORY_GB = float(os.getenv("MAX_MEMORY_GB", "8"))
    
    # Audio settings - optimized for performance
    MAX_AUDIO_SIZE_MB = int(os.getenv("MAX_AUDIO_SIZE_MB", "50"))
    AUDIO_SAMPLE_RATE = 16000
    SUPPORTED_AUDIO_FORMATS = ["wav", "mp3", "m4a", "flac", "ogg", "webm"]
    AUDIO_CHUNK_SIZE_SECONDS = int(os.getenv("AUDIO_CHUNK_SIZE_SECONDS", "30"))  # Model limit is 30s
    # Reduce overlap to trim redundant decoding work per chunk
    AUDIO_OVERLAP_SECONDS = float(os.getenv("AUDIO_OVERLAP_SECONDS", "0.5"))
    MAX_AUDIO_DURATION_SECONDS = 300
    
    # API settings - conservative for CPU
    MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "2"))
    REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "600"))
    DEFAULT_PORT = int(os.getenv("PORT", "11343"))
    DEFAULT_HOST = os.getenv("HOST", "127.0.0.1")
    
    # Generation settings - optimized for audio transcription
    DEFAULT_MAX_TOKENS = int(os.getenv("MAX_TOKENS", "2000"))  # Increased for longer transcriptions
    MAX_TOKENS_TRANSCRIPTION = int(os.getenv("MAX_TOKENS_TRANSCRIPTION", "2000"))  # Support full transcriptions
    DEFAULT_TEMPERATURE = 0.1
    DEFAULT_TOP_P = 0.8
    DEFAULT_TOP_K = 20
    
    # CPU-specific generation settings
    CPU_MAX_NEW_TOKENS = int(os.getenv("CPU_MAX_NEW_TOKENS", "2000"))  # Support full audio transcriptions
    CPU_BATCH_SIZE = 1
    USE_CACHE = True
    
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
    def get_device(cls):
        """Get the best available device with memory considerations."""
        return cls.DEFAULT_DEVICE
    
    @classmethod
    def get_model_path(cls) -> Path:
        """Get the local path for the model."""
        return cls.CACHE_DIR / "models" / cls.MODEL_ID.replace("/", "--")
    
    @classmethod
    def is_model_cached(cls) -> bool:
        """Check if model is already downloaded."""
        model_path = cls.get_model_path()
        return model_path.exists() and any(model_path.glob("*.safetensors"))
    
    @classmethod
    def get_generation_config(cls, task_type: str = "general") -> dict:
        """Get optimized generation config for different task types."""
        base_config = {
            "do_sample": False,  # Deterministic for transcription
            "use_cache": cls.USE_CACHE,
            "pad_token_id": None,  # Will be set from tokenizer
            "eos_token_id": None,  # Will be set from tokenizer
        }
        
        if task_type == "transcription":
            base_config.update({
                "max_new_tokens": 2000,     # Increased for full 1-minute+ audio content
                "temperature": 0.0,         # Completely deterministic like Whisper
                "do_sample": False,         # No sampling - greedy decoding like Whisper
                "num_beams": 1,            # Greedy decoding like Whisper
                "repetition_penalty": 1.0,  # No repetition penalty conflicts
                "early_stopping": True,
                "use_cache": True,
            })
        elif task_type == "cpu_optimized":
            base_config.update({
                "max_new_tokens": cls.CPU_MAX_NEW_TOKENS,
                "temperature": cls.DEFAULT_TEMPERATURE,
                "top_p": cls.DEFAULT_TOP_P,
                "top_k": cls.DEFAULT_TOP_K,
            })
        else:  # general
            base_config.update({
                "max_new_tokens": cls.DEFAULT_MAX_TOKENS,
                "temperature": cls.DEFAULT_TEMPERATURE,
                "top_p": cls.DEFAULT_TOP_P,
                "top_k": cls.DEFAULT_TOP_K,
            })
            
        return base_config
