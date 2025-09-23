"""Model management for Gemma Local Service."""

import asyncio
import logging
import os
from pathlib import Path
from typing import Optional, AsyncGenerator, Dict, Any
import json

import torch
from transformers import (
    AutoModelForImageTextToText,
    AutoTokenizer,
    AutoProcessor,
    BitsAndBytesConfig,
)
from torch.quantization import quantize_dynamic, QConfig, default_qconfig
from torch.quantization.qconfig import get_default_qconfig
import torch.nn as nn
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
        self.model: Optional[AutoModelForImageTextToText] = None
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

                # Get HuggingFace token from environment
                hf_token = os.environ.get('HF_TOKEN') or os.environ.get('HUGGING_FACE_HUB_TOKEN')
                if not hf_token:
                    logger.warning("No HuggingFace token found. Set HF_TOKEN environment variable.")
                    logger.warning("Gemma models require authentication. Please:")
                    logger.warning("1. Create a HuggingFace account at https://huggingface.co")
                    logger.warning("2. Accept the license at https://huggingface.co/google/gemma-3n-E2B-it")
                    logger.warning("3. Create an access token at https://huggingface.co/settings/tokens")
                    logger.warning("4. Set: export HF_TOKEN=your_token_here")

                await loop.run_in_executor(
                    None,
                    lambda: snapshot_download(
                        repo_id=self.model_id,
                        cache_dir=self.cache_dir / "models",
                        local_dir=ServiceConfig.get_model_path(),
                        local_dir_use_symlinks=False,
                        resume_download=True,
                        token=hf_token,
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
                logger.error(f"Full traceback:", exc_info=True)
                
                yield {
                    "status": "Error: Model download failed.",
                    "progress": 0,
                    "total": 0,
                    "completed": 0,
                    "error": "Model download failed."
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
                
                # Configure quantization for memory efficiency
                quantization_config = None
                use_cpu_quantization = self.device == "cpu"
                
                # Only attempt GPU quantization if we're actually using GPU
                if self.device in ["cuda", "mps"]:
                    # GPU quantization with BitsAndBytesConfig (only works with CUDA)
                    if self.device == "cuda":
                        try:
                            quantization_config = BitsAndBytesConfig(
                                load_in_8bit=True,
                                bnb_8bit_compute_dtype=ServiceConfig.TORCH_DTYPE,
                            )
                            logger.info("8-bit GPU quantization enabled")
                        except Exception as e:
                            logger.warning(f"GPU quantization not available: {e}")
                            quantization_config = None
                    else:
                        logger.info(f"Quantization not available for {self.device}, will use native precision")
                elif self.device == "cpu":
                    logger.info("CPU mode selected - will optimize after loading")
                    use_cpu_quantization = True
                
                # Load in thread to avoid blocking
                loop = asyncio.get_event_loop()
                
                def load_model_sync():
                    # Determine if we should use CPU quantization
                    nonlocal use_cpu_quantization
                    
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
                    
                    # Load model with multiple fallback strategies
                    model_loaded = False
                    load_attempts = [
                        # First attempt: with all optimizations
                        {
                            "device_map": "auto" if self.device != "cpu" else None,
                            "quantization_config": quantization_config,
                            "dtype": ServiceConfig.TORCH_DTYPE,
                            "low_cpu_mem_usage": True,
                        },
                        # Second attempt: without quantization
                        {
                            "device_map": "auto" if self.device != "cpu" else None,
                            "quantization_config": None,
                            "dtype": ServiceConfig.TORCH_DTYPE,
                            "low_cpu_mem_usage": True,
                        },
                        # Third attempt: force CPU with float32
                        {
                            "device_map": None,
                            "quantization_config": None,
                            "dtype": torch.float32,
                            "low_cpu_mem_usage": True,
                        },
                        # Final attempt: minimal config
                        {
                            "device_map": None,
                            "quantization_config": None,
                            "dtype": torch.float32,
                            "low_cpu_mem_usage": False,
                        },
                    ]
                    
                    last_error = None
                    for attempt_num, config in enumerate(load_attempts, 1):
                        try:
                            logger.info(f"Model load attempt {attempt_num}/{len(load_attempts)}...")
                            self.model = AutoModelForImageTextToText.from_pretrained(
                                model_path,
                                local_files_only=True,
                                trust_remote_code=True,
                                **config
                            )
                            model_loaded = True
                            
                            # Update device if we fell back to CPU
                            if config["device_map"] is None and self.device != "cpu":
                                logger.warning(f"Fell back to CPU from {self.device}")
                                self.device = "cpu"
                                use_cpu_quantization = True
                            
                            break
                        except Exception as e:
                            last_error = e
                            logger.warning(f"Attempt {attempt_num} failed: {e}")
                            
                            # Clear cache between attempts
                            import gc
                            gc.collect()
                            if torch.cuda.is_available():
                                torch.cuda.empty_cache()
                    
                    if not model_loaded:
                        raise Exception(f"Failed to load model after {len(load_attempts)} attempts. Last error: {last_error}")
                    
                    # Optional: override attention implementation if requested
                    try:
                        if ServiceConfig.ATTN_IMPL:
                            applied = False
                            # Try config field first
                            if hasattr(self.model, 'config') and hasattr(self.model.config, 'attn_implementation'):
                                self.model.config.attn_implementation = ServiceConfig.ATTN_IMPL
                                applied = True
                            # Some models expose a setter
                            if hasattr(self.model, 'set_attn_implementation'):
                                try:
                                    self.model.set_attn_implementation(ServiceConfig.ATTN_IMPL)
                                    applied = True
                                except Exception:
                                    pass
                            eff = getattr(getattr(self.model, 'config', object()), 'attn_implementation', 'unknown')
                            logger.info(f"Attention override requested: {ServiceConfig.ATTN_IMPL}; effective attn={eff}; applied={applied}")
                    except Exception as e:
                        logger.warning(f"Failed to apply attention implementation override '{ServiceConfig.ATTN_IMPL}': {e}")

                    # Move model to device if needed
                    if self.device == "cpu" and not hasattr(self.model, 'device'):
                        try:
                            self.model = self.model.to(self.device)
                        except RuntimeError as e:
                            logger.warning(f"Could not move model to {self.device}: {e}")
                        
                    # Apply CPU-specific optimizations
                    if self.device == "cpu":
                        if use_cpu_quantization and ServiceConfig.ENABLE_CPU_QUANTIZATION:
                            logger.info("Applying CPU optimizations...")
                            try:
                                # Skip quantization for Gemma 3n models due to compatibility issues
                                if "gemma-3n" in self.model_id.lower():
                                    logger.info("Using native precision for Gemma 3n model")
                                else:
                                    # Apply dynamic quantization for CPU inference
                                    self.model = torch.quantization.quantize_dynamic(
                                        self.model, 
                                        {nn.Linear, nn.MultiheadAttention, nn.LSTM, nn.GRU}, 
                                        dtype=torch.qint8
                                    )
                                    logger.info("CPU int8 quantization applied successfully")
                            except Exception as e:
                                logger.warning(f"CPU quantization failed, continuing without: {e}")
                        
                        # Enable CPU-specific optimizations
                        torch.set_num_threads(min(8, torch.get_num_threads()))
                        logger.info(f"Set torch threads to {torch.get_num_threads()}")
                        
                        # Try to compile model for faster inference
                        if hasattr(torch, 'compile') and ServiceConfig.ENABLE_TORCH_COMPILE:
                            try:
                                # Skip torch.compile for Gemma 3n models due to compatibility issues
                                if "gemma-3n" in self.model_id.lower():
                                    logger.info("Skipping torch.compile for Gemma 3n model")
                                else:
                                    self.model = torch.compile(self.model, mode="reduce-overhead")
                                    logger.info("Model compiled with torch.compile for optimization")
                            except Exception as e:
                                logger.warning(f"Failed to compile model: {e}")
                    
                    # Set to evaluation mode
                    self.model.eval()
                    # Log model details
                    try:
                        try:
                            param_dtype = next(self.model.parameters()).dtype
                        except Exception:
                            param_dtype = 'unknown'
                        try:
                            n_params = sum(p.numel() for p in self.model.parameters())
                        except Exception:
                            n_params = -1
                        cfg = getattr(self.model, 'config', None)
                        attn_impl = getattr(cfg, 'attn_implementation', 'default') if cfg else 'default'
                        logger.info(
                            f"Model loaded successfully on {self.device}; params={n_params/1e6:.1f}M; dtype={param_dtype}; attn={attn_impl}"
                        )
                        if cfg is not None:
                            try:
                                text_cfg = getattr(cfg, 'text_config', None)
                                def pick(*vals):
                                    for v in vals:
                                        if v is not None and v != '?':
                                            return v
                                    return '?'
                                hidden = pick(
                                    getattr(cfg, 'hidden_size', None),
                                    getattr(text_cfg, 'hidden_size', None),
                                )
                                layers = pick(
                                    getattr(cfg, 'num_hidden_layers', None),
                                    getattr(text_cfg, 'num_hidden_layers', None),
                                )
                                ff = pick(
                                    getattr(cfg, 'intermediate_size', None),
                                    getattr(text_cfg, 'intermediate_size', None),
                                    getattr(cfg, 'ffn_dim', None),
                                    getattr(text_cfg, 'ffn_dim', None),
                                )
                                logger.info(
                                    f"cfg: hidden={hidden}, layers={layers}, ff={ff}"
                                )
                            except Exception:
                                pass
                    except Exception as _e:
                        logger.info(f"Model loaded successfully on {self.device} (details unavailable: {_e})")
                
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
            # Simple warm-up prompt optimized for CPU
            inputs = self.tokenizer("Hello", return_tensors="pt").to(self.device)
            with torch.no_grad():
                if self.device == "cpu":
                    # Use inference mode for better CPU performance
                    with torch.inference_mode():
                        _ = self.model.generate(
                            **inputs,
                            max_new_tokens=3,  # Minimal tokens for warm-up
                            do_sample=False,
                            use_cache=True,
                            pad_token_id=self.tokenizer.eos_token_id,
                        )
                else:
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
            "torch_threads": torch.get_num_threads() if self.device == "cpu" else None,
            "quantized": hasattr(self.model, "_modules") and any(
                "quantized" in str(type(m)).lower() for m in self.model.modules()
            ) if self.is_model_loaded() else False,
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
