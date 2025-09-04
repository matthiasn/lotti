"""Configuration settings for Gemma Local Service."""

import os
from pathlib import Path
import torch
from typing import Dict, Any


class ServiceConfig:
    """Service configuration settings."""
    
    # Model settings
    MODEL_ID = os.getenv("GEMMA_MODEL_ID", "google/gemma-3n-E2B-it")  # Use smaller Gemma 3n E2B for faster CPU inference
    DEFAULT_DEVICE = "cpu"  # Force CPU for compatibility
    TORCH_DTYPE = torch.float32  # Always use float32 for CPU inference
    ENABLE_TORCH_COMPILE = os.getenv("ENABLE_TORCH_COMPILE", "true").lower() == "true"
    ENABLE_CPU_QUANTIZATION = os.getenv("ENABLE_CPU_QUANTIZATION", "true").lower() == "true"
    
    # Audio settings - optimized for performance
    MAX_AUDIO_SIZE_MB = int(os.getenv("MAX_AUDIO_SIZE_MB", "50"))  # Reduced for CPU processing
    AUDIO_SAMPLE_RATE = 16000
    SUPPORTED_AUDIO_FORMATS = ["wav", "mp3", "m4a", "flac", "ogg", "webm"]
    AUDIO_CHUNK_SIZE_SECONDS = 30  # Process audio in 30-second chunks
    AUDIO_OVERLAP_SECONDS = 2  # Overlap between chunks for continuity
    MAX_AUDIO_DURATION_SECONDS = 300  # 5 minutes max for CPU processing
    
    # API settings - conservative for CPU
    MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "2"))  # Reduced for CPU
    REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "600"))  # Longer timeout for CPU inference
    DEFAULT_PORT = int(os.getenv("PORT", "11343"))
    DEFAULT_HOST = os.getenv("HOST", "0.0.0.0")
    
    # Generation settings - optimized for audio transcription
    DEFAULT_MAX_TOKENS = 1000  # General purpose
    MAX_TOKENS_TRANSCRIPTION = 500   # Increased for proper audio transcription
    DEFAULT_TEMPERATURE = 0.1  # Lower temperature for more focused transcription
    DEFAULT_TOP_P = 0.8  # Reduced for more deterministic output
    DEFAULT_TOP_K = 20  # Smaller for faster generation
    
    # CPU-specific generation settings
    CPU_MAX_NEW_TOKENS = 300  # Increased for audio transcription
    CPU_BATCH_SIZE = 1  # Single batch for CPU
    USE_CACHE = True  # Enable KV caching for faster generation
    
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
    
    @classmethod
    def get_generation_config(cls, task_type: str = "general") -> dict:
        """Get optimized generation config for different task types."""
        base_config = {
            "use_cache": cls.USE_CACHE,
            "pad_token_id": None,  # Will be set from tokenizer
            "eos_token_id": None,  # Will be set from tokenizer
            "no_repeat_ngram_size": 3,  # Prevent repetition but allow longer text
        }
        
        if task_type == "transcription":
            base_config.update({
                "max_new_tokens": cls.MAX_TOKENS_TRANSCRIPTION,
                "temperature": 0.0,  # Deterministic like Whisper
                "do_sample": False,  # Greedy decoding for consistency
                "num_beams": 1,  # Single beam like Whisper
                "repetition_penalty": 1.1,  # Stronger repetition penalty
            })
        elif task_type == "cpu_optimized":
            base_config.update({
                "max_new_tokens": cls.CPU_MAX_NEW_TOKENS,
                "temperature": 0.0,  # Deterministic for transcription
                "do_sample": False,  # Greedy decoding
                "num_beams": 1,  # Single beam
                "repetition_penalty": 1.1,  # Prevent repetition
            })
        else:  # general
            base_config.update({
                "max_new_tokens": cls.DEFAULT_MAX_TOKENS,
                "temperature": cls.DEFAULT_TEMPERATURE,
                "top_p": cls.DEFAULT_TOP_P,
                "top_k": cls.DEFAULT_TOP_K,
            })
            
        return base_config