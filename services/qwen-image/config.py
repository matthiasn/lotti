"""Configuration settings for Qwen Image Service."""

import os
import platform
from pathlib import Path
from typing import Any, Dict

import torch


def _get_device() -> str:
    """Get the best available device with memory considerations."""
    device = os.getenv("QWEN_IMAGE_DEVICE", "auto")

    if device == "auto":
        # Check for CUDA availability
        if torch.cuda.is_available():
            try:
                mem_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)
                # Need at least 8GB for Qwen-Image in bfloat16
                if mem_gb >= 8:
                    return "cuda"
            except (RuntimeError, AssertionError):
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
    MODEL_ID = os.getenv("QWEN_IMAGE_MODEL_ID", "Qwen/Qwen-Image")
    DEFAULT_DEVICE = _get_device()
    TORCH_DTYPE = torch.bfloat16 if DEFAULT_DEVICE in ["cuda", "mps"] else torch.float32

    # Image generation settings
    DEFAULT_WIDTH = int(os.getenv("QWEN_IMAGE_WIDTH", "1664"))
    DEFAULT_HEIGHT = int(os.getenv("QWEN_IMAGE_HEIGHT", "928"))
    DEFAULT_INFERENCE_STEPS = int(os.getenv("QWEN_IMAGE_STEPS", "50"))
    DEFAULT_CFG_SCALE = float(os.getenv("QWEN_IMAGE_CFG_SCALE", "4.0"))
    GENERATION_TIMEOUT = int(os.getenv("QWEN_IMAGE_TIMEOUT", "300"))

    # Supported aspect ratios: width x height
    SUPPORTED_DIMENSIONS = {
        "1:1": (1024, 1024),
        "16:9": (1664, 928),
        "9:16": (928, 1664),
        "4:3": (1216, 912),
        "3:4": (912, 1216),
        "3:2": (1280, 864),
        "2:3": (864, 1280),
    }
    MAX_DIMENSION = 2048
    MIN_DIMENSION = 512

    # API settings
    MAX_CONCURRENT_REQUESTS = int(os.getenv("MAX_CONCURRENT_REQUESTS", "1"))
    DEFAULT_PORT = int(os.getenv("PORT", "11345"))
    DEFAULT_HOST = os.getenv("HOST", "127.0.0.1")

    # Paths
    HOME_DIR = Path.home()
    CACHE_DIR = HOME_DIR / ".cache" / "qwen-image"
    LOG_DIR = HOME_DIR / ".logs" / "qwen-image"

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
    def get_generation_config(cls) -> Dict[str, Any]:
        """Get default image generation parameters."""
        return {
            "width": cls.DEFAULT_WIDTH,
            "height": cls.DEFAULT_HEIGHT,
            "num_inference_steps": cls.DEFAULT_INFERENCE_STEPS,
            "true_cfg_scale": cls.DEFAULT_CFG_SCALE,
        }

    @classmethod
    def validate_dimensions(cls, width: int, height: int) -> bool:
        """Validate that requested image dimensions are within bounds."""
        return (
            cls.MIN_DIMENSION <= width <= cls.MAX_DIMENSION
            and cls.MIN_DIMENSION <= height <= cls.MAX_DIMENSION
        )
