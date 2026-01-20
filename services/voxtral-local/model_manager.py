"""Model management for Voxtral Local Service."""

import asyncio
import gc
import logging
import os
from typing import Any, AsyncGenerator, Dict, Optional

import psutil
import torch
from huggingface_hub import snapshot_download
from transformers import AutoProcessor, VoxtralForConditionalGeneration

from config import ServiceConfig

logger = logging.getLogger(__name__)


class ModelStatus:
    """Model download/installation status."""

    def __init__(self) -> None:
        self.status: str = "idle"
        self.progress: float = 0.0
        self.total_size: int = 0
        self.downloaded_size: int = 0
        self.message: str = ""
        self.error: Optional[str] = None


class VoxtralModelManager:
    """Manages Voxtral model downloading, loading, and inference."""

    def __init__(self) -> None:
        self.model: Optional[VoxtralForConditionalGeneration] = None
        self.processor: Optional[AutoProcessor] = None
        self.device = ServiceConfig.DEFAULT_DEVICE
        self.model_id = ServiceConfig.MODEL_ID
        self.cache_dir = ServiceConfig.CACHE_DIR
        self.download_status = ModelStatus()
        self._lock = asyncio.Lock()

        logger.info(f"Initialized VoxtralModelManager with device: {self.device}")
        logger.info(f"Model ID: {self.model_id}")
        logger.info(f"Cache directory: {self.cache_dir}")

        self._log_memory_usage("startup")

    async def download_model(self) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Download model from Hugging Face with progress tracking.

        Yields progress updates as dictionaries with keys:
        - status: Current status message
        - progress: Percentage (0-100)
        - total: Total size in bytes
        - completed: Completed size in bytes
        """
        async with self._lock:
            try:
                self.download_status.status = "checking"
                self.download_status.message = "Checking if model exists locally..."

                yield {
                    "status": self.download_status.message,
                    "progress": 0,
                    "total": 0,
                    "completed": 0,
                }

                # Check if model already exists
                if ServiceConfig.is_model_cached():
                    self.download_status.status = "cached"
                    self.download_status.message = "Model already downloaded"
                    self.download_status.progress = 100.0

                    yield {
                        "status": "Model already downloaded",
                        "progress": 100,
                        "total": 100,
                        "completed": 100,
                    }
                    return

                self.download_status.status = "downloading"
                self.download_status.message = f"Downloading {self.model_id}..."

                yield {
                    "status": self.download_status.message,
                    "progress": 0,
                    "total": 0,
                    "completed": 0,
                }

                # Download in a thread to avoid blocking
                loop = asyncio.get_event_loop()

                # Voxtral is Apache 2.0, no token required
                # But we still support it if provided for faster downloads
                hf_token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")

                await loop.run_in_executor(
                    None,
                    lambda: snapshot_download(  # nosec B615 - pinned via MODEL_REVISION
                        repo_id=self.model_id,
                        revision=ServiceConfig.MODEL_REVISION,
                        cache_dir=self.cache_dir / "models",
                        local_dir=ServiceConfig.get_model_path(),
                        local_dir_use_symlinks=False,
                        resume_download=True,
                        token=hf_token,
                    ),
                )

                self.download_status.status = "complete"
                self.download_status.message = "Model downloaded successfully"
                self.download_status.progress = 100.0

                yield {
                    "status": "Download complete",
                    "progress": 100,
                    "total": self.download_status.total_size,
                    "completed": self.download_status.total_size,
                }

            except Exception as e:
                self.download_status.status = "error"
                self.download_status.error = str(e)
                self.download_status.message = f"Download failed: {e}"
                logger.error(f"Model download failed: {e}")
                logger.error("Full traceback:", exc_info=True)

                yield {
                    "status": "Error: Model download failed.",
                    "progress": 0,
                    "total": 0,
                    "completed": 0,
                    "error": "Model download failed.",
                }
                raise

    async def load_model(self) -> bool:
        """
        Load model into memory with optimizations.

        Returns True if successful, False otherwise.
        """
        if self.model is not None:
            logger.info("Model already loaded")
            return True

        async with self._lock:
            try:
                logger.info(f"Loading model {self.model_id}...")
                self._log_memory_usage("pre-load")

                if self._check_memory_pressure():
                    logger.warning("System under memory pressure - attempting cleanup")
                    self._force_cleanup()

                if not ServiceConfig.is_model_cached():
                    logger.error("Model not downloaded. Please download first.")
                    return False

                model_path = ServiceConfig.get_model_path()

                loop = asyncio.get_event_loop()

                def load_model_sync() -> None:
                    # Load processor from local cache (no download)
                    self.processor = AutoProcessor.from_pretrained(  # nosec B615
                        model_path,
                        local_files_only=True,
                        trust_remote_code=True,
                        revision=ServiceConfig.MODEL_REVISION,
                    )
                    logger.info("Loaded processor for Voxtral")

                    # Load model with appropriate settings based on device
                    # (local_files_only=True loads from local cache)
                    model_kwargs: Dict[str, Any] = {
                        "local_files_only": True,
                        "trust_remote_code": True,
                        "torch_dtype": ServiceConfig.TORCH_DTYPE,
                        "low_cpu_mem_usage": True,
                        "attn_implementation": "sdpa",  # Use scaled dot-product attention
                    }

                    if self.device in ["cuda", "mps"]:
                        model_kwargs["device_map"] = "auto"
                    else:
                        model_kwargs["device_map"] = None

                    try:
                        self.model = VoxtralForConditionalGeneration.from_pretrained(  # nosec B615
                            model_path,
                            revision=ServiceConfig.MODEL_REVISION,
                            **model_kwargs,
                        )
                    except Exception as e:
                        logger.warning(f"First load attempt failed: {e}")
                        # Fallback: try without device_map
                        model_kwargs.pop("device_map", None)
                        self.model = VoxtralForConditionalGeneration.from_pretrained(  # nosec B615
                            model_path,
                            revision=ServiceConfig.MODEL_REVISION,
                            **model_kwargs,
                        )
                        # Move to device manually
                        if self.device != "cpu":
                            try:
                                self.model = self.model.to(self.device)
                            except RuntimeError as move_error:
                                logger.warning(
                                    f"Could not move model to {self.device}: {move_error}"
                                )
                                self.device = "cpu"

                    # Set to evaluation mode
                    self.model.eval()

                    # Log model details
                    try:
                        param_dtype = next(self.model.parameters()).dtype
                        n_params = sum(p.numel() for p in self.model.parameters())
                        logger.info(
                            f"Model loaded successfully on {self.device}; "
                            f"params={n_params / 1e9:.2f}B; dtype={param_dtype}"
                        )
                    except Exception as e:
                        logger.info(
                            f"Model loaded successfully on {self.device} "
                            f"(details unavailable: {e})"
                        )

                await loop.run_in_executor(None, load_model_sync)

                self._log_memory_usage("post-load")
                return True

            except Exception as e:
                logger.error(f"Failed to load model: {e}")
                self.model = None
                self.processor = None
                return False

    async def unload_model(self) -> None:
        """Free memory by unloading model."""
        async with self._lock:
            self._unload_model_unsafe()

    def _unload_model_unsafe(self) -> None:
        """Free memory by unloading model without acquiring lock."""
        self._log_memory_usage("pre-unload")

        if self.model is not None:
            del self.model
            self.model = None
        if self.processor is not None:
            del self.processor
            self.processor = None

        self._force_cleanup()

        logger.info("Model unloaded from memory")
        self._log_memory_usage("post-unload")

    def refresh_config(self) -> None:
        """Refresh configuration after model download/change."""
        old_model_id = self.model_id
        self.model_id = ServiceConfig.MODEL_ID
        self.device = ServiceConfig.DEFAULT_DEVICE
        logger.info(
            f"Configuration refreshed: {old_model_id} -> {self.model_id}, " f"device: {self.device}"
        )

    def is_model_available(self) -> bool:
        """Check if model files exist locally."""
        return ServiceConfig.is_model_cached()

    def is_model_loaded(self) -> bool:
        """Check if model is loaded in memory."""
        return self.model is not None

    async def get_model_info(self) -> Dict[str, Any]:
        """Get information about the current model."""
        info = {
            "model_id": self.model_id,
            "device": self.device,
            "is_available": self.is_model_available(),
            "is_loaded": self.is_model_loaded(),
            "cache_dir": str(self.cache_dir),
            "supports_audio": True,
            "max_audio_duration_seconds": ServiceConfig.MAX_AUDIO_DURATION_SECONDS,
        }

        if self.is_model_available():
            model_path = ServiceConfig.get_model_path()
            total_size = sum(f.stat().st_size for f in model_path.rglob("*") if f.is_file())
            info["size_bytes"] = total_size
            info["size_gb"] = round(total_size / (1024**3), 2)

        return info

    def _log_memory_usage(self, context: str = "") -> None:
        """Log current memory usage for debugging."""
        try:
            process = psutil.Process()
            mem_info = process.memory_info()
            mem_percent = process.memory_percent()
            system_mem = psutil.virtual_memory()

            # GPU memory if available
            gpu_allocated = 0.0
            gpu_reserved = 0.0
            if self.device == "mps":
                try:
                    gpu_allocated = torch.mps.current_allocated_memory() / (1024**3)
                    gpu_reserved = torch.mps.driver_allocated_memory() / (1024**3)
                except (RuntimeError, AttributeError):
                    pass
            elif self.device == "cuda":
                try:
                    gpu_allocated = torch.cuda.memory_allocated() / (1024**3)
                    gpu_reserved = torch.cuda.memory_reserved() / (1024**3)
                except (RuntimeError, AttributeError):
                    pass

            logger.info(
                f"Memory usage [{context}]: "
                f"Process={mem_info.rss / (1024**3):.2f}GB ({mem_percent:.1f}%), "
                f"System={system_mem.used / (1024**3):.1f}GB/"
                f"{system_mem.total / (1024**3):.1f}GB ({system_mem.percent:.1f}%), "
                f"GPU={gpu_allocated:.2f}GB allocated, {gpu_reserved:.2f}GB reserved"
            )

            if system_mem.percent > 85:
                logger.warning(f"High system memory usage: {system_mem.percent:.1f}%")

        except Exception as e:
            logger.debug(f"Failed to log memory usage: {e}")

    def _check_memory_pressure(self) -> bool:
        """Check if system is under memory pressure."""
        try:
            system_mem = psutil.virtual_memory()
            return system_mem.percent > 80
        except (OSError, AttributeError):
            return False

    def _force_cleanup(self) -> None:
        """Force aggressive memory cleanup."""
        try:
            if self.device == "mps":
                torch.mps.empty_cache()
                torch.mps.synchronize()
            elif self.device == "cuda":
                torch.cuda.empty_cache()
                torch.cuda.synchronize()

            for _ in range(3):
                gc.collect()

            logger.info("Aggressive memory cleanup completed")
            self._log_memory_usage("post-cleanup")

        except Exception as e:
            logger.warning(f"Memory cleanup failed: {e}")


# Global instance
model_manager = VoxtralModelManager()
