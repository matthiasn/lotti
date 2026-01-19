"""Configuration settings for Voxtral Local Service."""

import os
from pathlib import Path
from typing import Any, Dict

import platform
import torch


def _get_device() -> str:
    """Get the best available device with memory considerations."""
    device = os.getenv("VOXTRAL_DEVICE", "auto")

    if device == "auto":
        # Check for CUDA availability
        if torch.cuda.is_available():
            try:
                mem_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                # Need at least 10GB for Voxtral Mini 3B
                if mem_gb >= 10:
                    return "cuda"
            except (RuntimeError, AssertionError):
                # CUDA device query failed, fall through to MPS/CPU
                pass

        # Check for MPS (Apple Silicon)
        if torch.backends.mps.is_available() and platform.system() == "Darwin":
            if os.getenv("DISABLE_MPS", "false").lower() != "true":
                return "mps"

        # Default to CPU for reliability
        return "cpu"

    return device


class ServiceConfig:
    """Service configuration settings."""

    # Model settings
    MODEL_ID = os.getenv("VOXTRAL_MODEL_ID", "mistralai/Voxtral-Mini-3B-2507")
    # Pin to specific revision for reproducibility (override with VOXTRAL_MODEL_REVISION)
    # Known revisions:
    #   Mini 3B:  3060fe34b35ba5d44202ce9ff3c097642914f8f3
    #   Small 24B: da5b42409f279fdd92febee0511a6c32828569c1
    MODEL_REVISION = os.getenv(
        "VOXTRAL_MODEL_REVISION", "3060fe34b35ba5d44202ce9ff3c097642914f8f3"
    )
    DEFAULT_DEVICE = _get_device()
    TORCH_DTYPE = torch.bfloat16 if DEFAULT_DEVICE in ["cuda", "mps"] else torch.float32

    ENABLE_TORCH_COMPILE = os.getenv("ENABLE_TORCH_COMPILE", "false").lower() == "true"

    # Memory management settings
    LOW_MEMORY_MODE = os.getenv("LOW_MEMORY_MODE", "true").lower() == "true"
    MAX_MEMORY_GB = float(os.getenv("MAX_MEMORY_GB", "12"))

    # Audio settings - Voxtral supports longer audio than Gemma 3N
    MAX_AUDIO_SIZE_MB = int(os.getenv("MAX_AUDIO_SIZE_MB", "100"))
    AUDIO_SAMPLE_RATE = 16000
    SUPPORTED_AUDIO_FORMATS = ["wav", "mp3", "m4a", "flac", "ogg", "webm"]
    AUDIO_CHUNK_SIZE_SECONDS = int(os.getenv("AUDIO_CHUNK_SIZE_SECONDS", "300"))  # 5 min chunks
    AUDIO_OVERLAP_SECONDS = float(os.getenv("AUDIO_OVERLAP_SECONDS", "1.0"))
    MAX_AUDIO_DURATION_SECONDS = 1800  # 30 minutes - Voxtral's limit

    # Transcription decode capping
    TOKENS_PER_SEC = float(os.getenv("TOKENS_PER_SEC", "4.0"))
    TOKEN_BUFFER = int(os.getenv("TOKEN_BUFFER", "64"))

    # Generation timeout (prevents hangs on problematic audio)
    # Total timeout = base + (audio_duration * multiplier)
    GENERATION_TIMEOUT_BASE = float(os.getenv("GENERATION_TIMEOUT_BASE", "60"))  # 60s base
    GENERATION_TIMEOUT_MULTIPLIER = float(os.getenv("GENERATION_TIMEOUT_MULTIPLIER", "0.5"))  # 0.5x audio duration

    # API settings
    MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "2"))
    REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "900"))  # 15 min for long audio
    DEFAULT_PORT = int(os.getenv("PORT", "11344"))
    DEFAULT_HOST = os.getenv("HOST", "127.0.0.1")

    # Generation settings - optimized for audio transcription
    DEFAULT_MAX_TOKENS = int(os.getenv("MAX_TOKENS", "4096"))
    MAX_TOKENS_TRANSCRIPTION = int(os.getenv("MAX_TOKENS_TRANSCRIPTION", "4096"))
    DEFAULT_TEMPERATURE = 0.0  # Deterministic for transcription
    DEFAULT_TOP_P = 0.95

    # Paths
    HOME_DIR = Path.home()
    CACHE_DIR = HOME_DIR / ".cache" / "voxtral-local"
    LOG_DIR = HOME_DIR / ".logs" / "voxtral-local"

    # Ensure directories exist
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    # Logging
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    @classmethod
    def get_device(cls) -> str:
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
    def get_generation_config(cls, task_type: str = "general") -> Dict[str, Any]:
        """Get optimized generation config for different task types."""
        base_config: Dict[str, Any] = {
            "do_sample": False,  # Deterministic for transcription
            "use_cache": True,
        }

        if task_type == "transcription":
            base_config.update(
                {
                    "max_new_tokens": cls.MAX_TOKENS_TRANSCRIPTION,
                    "do_sample": False,  # No sampling - greedy decoding
                    "num_beams": 1,  # Greedy decoding
                    # No repetition penalty - causes garbage output
                }
            )
        else:  # general
            base_config.update(
                {
                    "max_new_tokens": cls.DEFAULT_MAX_TOKENS,
                    "temperature": cls.DEFAULT_TEMPERATURE,
                    "top_p": cls.DEFAULT_TOP_P,
                }
            )

        return base_config
