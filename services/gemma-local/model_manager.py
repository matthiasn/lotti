"""Model management for Gemma Local Service."""

import asyncio
import logging
from pathlib import Path
from typing import Optional, AsyncGenerator, Dict, Any
import json

import torch
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    AutoProcessor,
    BitsAndBytesConfig,
)
from huggingface_hub import snapshot_download, HfFileSystem
from accelerate import init_empty_weights, load_checkpoint_and_dispatch

from config import ServiceConfig

logger = logging.getLogger(__name__)


class ModelStatus:
    """Model download/installation status."""
    
    def __init__(self):
        self.status: str = "idle"
        self.progress: float = 0.0
        self.total_size: int = 0
        self.downloaded_size: int = 0
        self.message: str = ""
        self.error: Optional[str] = None


class GemmaModelManager:
    """Manages Gemma model downloading, loading, and inference."""
    
    def __init__(self):
        self.model: Optional[AutoModelForCausalLM] = None
        self.processor: Optional[AutoProcessor] = None
        self.tokenizer: Optional[AutoTokenizer] = None
        self.device = ServiceConfig.DEFAULT_DEVICE
        self.model_id = ServiceConfig.MODEL_ID
        self.cache_dir = ServiceConfig.CACHE_DIR
        self.download_status = ModelStatus()
        self._lock = asyncio.Lock()
        
        logger.info(f"Initialized GemmaModelManager with device: {self.device}")
        logger.info(f"Model ID: {self.model_id}")
        logger.info(f"Cache directory: {self.cache_dir}")
    
    async def download_model(self, progress_callback=None) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Download model from Hugging Face with progress tracking.
        
        Yields progress updates as dictionaries with keys:
        - status: Current status message
        - progress: Progress percentage (0-100)
        - total: Total size in bytes
        - completed: Downloaded size in bytes
        """
        async with self._lock:
            try:
                self.download_status.status = "checking"
                self.download_status.message = "Checking if model exists locally..."
                
                yield {
                    "status": self.download_status.message,
                    "progress": 0,
                    "total": 0,
                    "completed": 0
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
                        "completed": 100
                    }
                    return
                
                # Get model info from HuggingFace
                self.download_status.status = "preparing"
                self.download_status.message = "Preparing to download model..."
                
                yield {
                    "status": self.download_status.message,
                    "progress": 0,
                    "total": 0,
                    "completed": 0
                }
                
                # Start download with progress tracking
                self.download_status.status = "downloading"
                self.download_status.message = f"Downloading {self.model_id}..."
                
                def progress_hook(progress):
                    """Hook to track download progress."""
                    if progress.get("total"):
                        self.download_status.total_size = progress["total"]
                        self.download_status.downloaded_size = progress.get("downloaded", 0)
                        self.download_status.progress = (
                            self.download_status.downloaded_size / self.download_status.total_size * 100
                        )
                
                # Download in a thread to avoid blocking
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(
                    None,
                    lambda: snapshot_download(
                        repo_id=self.model_id,
                        cache_dir=self.cache_dir / "models",
                        local_dir=ServiceConfig.get_model_path(),
                        local_dir_use_symlinks=False,
                        resume_download=True,
                    )
                )
                
                self.download_status.status = "complete"
                self.download_status.message = "Model downloaded successfully"
                self.download_status.progress = 100.0
                
                yield {
                    "status": "Download complete",
                    "progress": 100,
                    "total": self.download_status.total_size,
                    "completed": self.download_status.total_size
                }
                
            except Exception as e:
                self.download_status.status = "error"
                self.download_status.error = str(e)
                self.download_status.message = f"Download failed: {e}"
                logger.error(f"Model download failed: {e}")
                
                yield {
                    "status": f"Error: {e}",
                    "progress": 0,
                    "total": 0,
                    "completed": 0,
                    "error": str(e)
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
                
                # Ensure model is downloaded
                if not ServiceConfig.is_model_cached():
                    logger.error("Model not downloaded. Please download first.")
                    return False
                
                model_path = ServiceConfig.get_model_path()
                
                # Configure quantization for memory efficiency (optional)
                quantization_config = None
                if self.device != "cpu" and ServiceConfig.DEFAULT_DEVICE in ["cuda", "mps"]:
                    # Only quantize on GPU/MPS
                    try:
                        quantization_config = BitsAndBytesConfig(
                            load_in_8bit=True,
                            bnb_8bit_compute_dtype=ServiceConfig.TORCH_DTYPE,
                        )
                    except Exception as e:
                        logger.warning(f"Quantization not available: {e}")
                
                # Load in thread to avoid blocking
                loop = asyncio.get_event_loop()
                
                def load_model_sync():
                    # Load tokenizer and processor
                    self.tokenizer = AutoTokenizer.from_pretrained(
                        model_path,
                        local_files_only=True,
                        trust_remote_code=True,
                    )
                    
                    # Try to load processor for multimodal support
                    try:
                        self.processor = AutoProcessor.from_pretrained(
                            model_path,
                            local_files_only=True,
                            trust_remote_code=True,
                        )
                        logger.info("Loaded processor for multimodal support")
                    except Exception as e:
                        logger.info(f"No processor found (text-only model): {e}")
                        self.processor = None
                    
                    # Load model
                    self.model = AutoModelForCausalLM.from_pretrained(
                        model_path,
                        local_files_only=True,
                        torch_dtype=ServiceConfig.TORCH_DTYPE,
                        device_map="auto" if self.device != "cpu" else None,
                        quantization_config=quantization_config,
                        trust_remote_code=True,
                        low_cpu_mem_usage=True,
                    )
                    
                    if self.device == "cpu":
                        self.model = self.model.to(self.device)
                    
                    # Set to evaluation mode
                    self.model.eval()
                    
                    logger.info(f"Model loaded successfully on {self.device}")
                
                await loop.run_in_executor(None, load_model_sync)
                
                return True
                
            except Exception as e:
                logger.error(f"Failed to load model: {e}")
                self.model = None
                self.tokenizer = None
                self.processor = None
                return False
    
    async def unload_model(self):
        """Free memory by unloading model."""
        async with self._lock:
            if self.model is not None:
                del self.model
                self.model = None
            if self.tokenizer is not None:
                del self.tokenizer
                self.tokenizer = None
            if self.processor is not None:
                del self.processor
                self.processor = None
            
            # Force garbage collection
            import gc
            gc.collect()
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            
            logger.info("Model unloaded from memory")
    
    def is_model_available(self) -> bool:
        """Check if model files exist locally."""
        return ServiceConfig.is_model_cached()
    
    def is_model_loaded(self) -> bool:
        """Check if model is loaded in memory."""
        return self.model is not None
    
    async def warm_up(self):
        """Warm up the model with a simple request."""
        if not self.is_model_loaded():
            success = await self.load_model()
            if not success:
                raise Exception("Failed to load model for warm-up")
        
        try:
            # Simple warm-up prompt
            inputs = self.tokenizer("Hello", return_tensors="pt").to(self.device)
            with torch.no_grad():
                _ = self.model.generate(
                    **inputs,
                    max_new_tokens=5,
                    do_sample=False,
                )
            logger.info("Model warmed up successfully")
        except Exception as e:
            logger.error(f"Warm-up failed: {e}")
            raise
    
    async def get_model_info(self) -> Dict[str, Any]:
        """Get information about the current model."""
        info = {
            "model_id": self.model_id,
            "device": self.device,
            "is_available": self.is_model_available(),
            "is_loaded": self.is_model_loaded(),
            "cache_dir": str(self.cache_dir),
            "supports_multimodal": self.processor is not None,
        }
        
        if self.is_model_available():
            model_path = ServiceConfig.get_model_path()
            # Get size of model files
            total_size = sum(f.stat().st_size for f in model_path.rglob("*") if f.is_file())
            info["size_bytes"] = total_size
            info["size_gb"] = round(total_size / (1024**3), 2)
        
        return info


# Global instance
model_manager = GemmaModelManager()