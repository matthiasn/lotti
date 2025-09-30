"""Main FastAPI application for Gemma Local Service."""

import json
import logging
import os
import sys
import time
import uuid
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Optional, List, Dict, Any, Union, TYPE_CHECKING

import numpy as np
import torch
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from numpy.typing import NDArray
from pydantic import BaseModel, Field

if TYPE_CHECKING:
    from transformers import AutoModelForImageTextToText, AutoTokenizer, AutoProcessor
else:
    AutoModelForImageTextToText = Any
    AutoTokenizer = Any
    AutoProcessor = Any

# Load environment variables from .env file if it exists
env_path = Path(__file__).parent / ".env"
if env_path.exists():
    load_dotenv(env_path)
    logging.info(f"Loaded environment from {env_path}")

from config import ServiceConfig
from model_manager import model_manager
from audio_processor import audio_processor
from streaming import StreamGenerator


# Configure logging
logging.basicConfig(
    level=getattr(logging, ServiceConfig.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
# File and optional stdout log handlers for diagnostics
try:
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))

    # Rotating file handler
    log_file = ServiceConfig.LOG_DIR / "service.log"
    file_handler = RotatingFileHandler(log_file, maxBytes=5 * 1024 * 1024, backupCount=3)
    file_handler.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))
    fmt = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    file_handler.setFormatter(fmt)
    if not any(isinstance(h, RotatingFileHandler) for h in root_logger.handlers):
        root_logger.addHandler(file_handler)

    # Optional stdout mirroring controlled by env LOG_TO_STDOUT
    if os.getenv("LOG_TO_STDOUT", "0").lower() in ("1", "true", "yes", "on"):
        if not any(
            isinstance(h, logging.StreamHandler) and getattr(h, "stream", None) is sys.stdout
            for h in root_logger.handlers
        ):
            sh = logging.StreamHandler(sys.stdout)
            sh.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))
            sh.setFormatter(fmt)
            root_logger.addHandler(sh)
except Exception as _e:
    logging.getLogger(__name__).warning(f"Failed to initialize log handlers: {_e}")
logger = logging.getLogger(__name__)


# Create FastAPI app
app = FastAPI(
    title="Gemma Local Service",
    description="Local Gemma model service with OpenAI-compatible API",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models


class ChatCompletionRequest(BaseModel):
    """Request model for chat completion (OpenAI-compatible) with audio support."""

    model: str
    messages: List[Dict[str, Any]]
    temperature: float = 0.7
    max_tokens: Optional[int] = 2000
    top_p: float = 0.95
    stream: bool = False
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0
    # Audio transcription support
    audio: Optional[str] = Field(None, description="Base64-encoded audio data for transcription")
    language: Optional[str] = Field(None, description="Language hint for audio transcription")


class ModelPullRequest(BaseModel):
    """Request model for model download."""

    model_name: str
    stream: bool = True


class ModelInfo(BaseModel):
    """Model information response."""

    id: str
    object: str = "model"
    created: int
    owned_by: str = "local"
    capabilities: Dict[str, bool]
    size_gb: Optional[float] = None


# Startup event
@app.on_event("startup")
async def startup_event() -> None:
    """Initialize service on startup."""
    logger.info(f"Starting Gemma Local Service with model: {ServiceConfig.MODEL_ID}")
    logger.info(f"Device: {ServiceConfig.DEFAULT_DEVICE}")
    logger.info(f"Model variant: {ServiceConfig.MODEL_VARIANT}")
    logger.info(f"Torch version: {torch.__version__}; " f"dtype default: {ServiceConfig.TORCH_DTYPE}")
    # Avoid adding extra stdout handlers here to prevent duplicate
    # console logs under Uvicorn.

    # Log threading/env hints for performance diagnostics
    try:
        omp = os.environ.get("OMP_NUM_THREADS")
        veclib = os.environ.get("VECLIB_MAXIMUM_THREADS")
        mkl = os.environ.get("MKL_NUM_THREADS")
        logger.info(f"Threads env: OMP_NUM_THREADS={omp}, " f"VECLIB_MAXIMUM_THREADS={veclib}, MKL_NUM_THREADS={mkl}")
    except Exception as e:
        logger.debug(f"Could not read thread env vars: {e}")

    # Check if model is available
    if model_manager.is_model_available():
        logger.info("Model files found. Ready to load on first request.")
    else:
        logger.info("Model not downloaded. Use /v1/models/pull to download.")


# Health check
@app.get("/health")
async def health_check() -> Dict[str, Any]:
    """Health check endpoint."""
    return {
        "status": "healthy",
        "model_available": model_manager.is_model_available(),
        "model_loaded": model_manager.is_model_loaded(),
        "device": model_manager.device,
    }


# OpenAI-compatible endpoints
def normalize_model_name(model_name: str) -> str:
    """Normalize model names to handle legacy naming conventions."""
    # Handle legacy model names
    model_mapping = {
        "gemma-2-2b-it": "google/gemma-2b-it",
        # Map to available model
        "gemma-2-9b-it": "google/gemma-2b-it",
        "gemma-3n-E2B-it": "google/gemma-3n-E2B-it",
        "gemma-3n-E4B-it": "google/gemma-3n-E4B-it",
    }
    return model_mapping.get(model_name, model_name)


@app.post("/v1/chat/completions", response_model=None)
async def chat_completion(
    request: ChatCompletionRequest,
) -> Union[Dict[str, Any], StreamingResponse]:
    """
    Unified OpenAI-compatible chat completion endpoint.

    Supports both text generation and audio transcription through
    chat interface. When audio data is provided, performs
    context-aware transcription.
    """
    try:
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(status_code=404, detail="Model not downloaded. Use /v1/models/pull to download.")

            logger.info("Loading model for chat completion...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(status_code=500, detail="Failed to load model")

        # Check if the requested model files exist on disk
        if request.model:
            # Build the full model ID for the requested model
            if "google/" not in request.model:
                requested_model_id = f"google/{request.model}"
            else:
                requested_model_id = request.model

            # Check if requested model files exist
            requested_model_path = ServiceConfig.CACHE_DIR / "models" / requested_model_id.replace("/", "--")
            model_files_exist = requested_model_path.exists() and any(requested_model_path.glob("*.safetensors"))

            if not model_files_exist:
                # Requested model not downloaded - return 404 to
                # trigger install dialog
                logger.warning(f"Requested model '{request.model}' not found on disk at " f"{requested_model_path}")
                raise HTTPException(
                    status_code=404,
                    detail=(f"Model '{request.model}' not downloaded. " "Use /v1/models/pull to download."),
                )
            else:
                # Model files exist but server might be configured
                # for a different model
                # Switch server configuration to use the requested model
                configured_model = ServiceConfig.MODEL_ID.replace("google/", "")
                if request.model != configured_model:
                    logger.info(f"Switching model from '{configured_model}' " f"to '{request.model}'")

                    # Determine variant from model name
                    variant = "E4B" if "E4B" in request.model.upper() else "E2B"

                    # Update model manager with new model configuration
                    # This is thread-safe as model_manager handles
                    # its own locking
                    await model_manager.switch_model(requested_model_id, variant)

                    logger.info(f"Model switched successfully to {request.model}")

        # Check if this is audio transcription or regular chat
        if request.audio:
            req_id = uuid.uuid4().hex[:8]
            logger.info(f"[REQ {req_id}] Audio transcription request received. Model={request.model}")

            # Log memory usage before processing
            model_manager._log_memory_usage(f"req-{req_id}-start")

            # Check memory pressure before processing
            if model_manager._check_memory_pressure():
                logger.warning(f"[REQ {req_id}] High memory usage detected, attempting cleanup")
                model_manager._force_cleanup()

            # Audio transcription through chat completions
            logger.info("Processing audio transcription via chat completions")

            # Extract context from messages
            context_prompt = None
            for message in request.messages:
                if message.get("role") == "user" and "Context:" in message.get("content", ""):
                    # Extract context from user message
                    content = message.get("content", "")
                    if "Context:" in content:
                        context_part = content.split("Context:")[1].split("\n\n")[0].strip()
                        if context_part:
                            context_prompt = context_part
                    break

            # Process audio - disable chunking to match working script behavior
            t_audio0 = time.perf_counter()
            result = await audio_processor.process_audio_base64(
                request.audio,
                context_prompt,
                use_chunking=True,
                request_id=req_id,  # Enable chunking for audio > 30s
            )
            t_audio1 = time.perf_counter()

            # Handle both single audio and chunked audio
            if isinstance(result[0], list):
                # Multiple chunks - shouldn't happen with use_chunking=False
                audio_chunks, combined_prompt = result
            else:
                # Single audio array - expected path
                audio_array, combined_prompt = result
                audio_chunks = [audio_array]

            # Add language hint if provided
            if request.language:
                combined_prompt = f"{combined_prompt}\n\nLanguage: {request.language}"

            # Build chat-style messages for context-aware transcription
            messages = [
                {
                    "role": "system",
                    "content": (
                        "You are a helpful assistant that transcribes audio accurately. "
                        "Format the transcription clearly with proper punctuation and paragraph breaks. "
                        "If there are multiple speakers, indicate speaker changes. Remove filler words. "
                        "Focus on the context provided."
                    ),
                },
                {"role": "user", "content": combined_prompt},
            ]

            # Generate transcription using chat context
            if len(audio_chunks) == 1:
                logger.info(f"[REQ {req_id}] 1 chunk; starting generation")
                t_gen0 = time.perf_counter()
                transcription = await generate_transcription_with_chat_context(
                    messages=messages, audio_array=audio_chunks[0], request_id=req_id
                )
                t_gen1 = time.perf_counter()
            else:
                # Multi-chunk processing with context
                logger.info(f"[REQ {req_id}] {len(audio_chunks)} chunks; starting sequential generation")
                t_gen0 = time.perf_counter()
                transcription = await process_audio_chunks_with_continuation(
                    chunks=audio_chunks, initial_messages=messages, request_id=req_id
                )
                t_gen1 = time.perf_counter()

            # Return in chat completion format
            total_t = (t_gen1 - t_gen0) + (t_audio1 - t_audio0)
            logger.info(
                f"[REQ {req_id}] Done. AudioProc={(t_audio1 - t_audio0):.2f}s, "
                f"Gen={(t_gen1 - t_gen0):.2f}s, Total={total_t:.2f}s"
            )

            # Log memory usage after processing
            model_manager._log_memory_usage(f"req-{req_id}-end")

            # Check if memory cleanup is needed after large model inference
            if "E4B" in request.model and model_manager._check_memory_pressure():
                logger.info(f"[REQ {req_id}] Performing cleanup after E4B inference")
                model_manager._force_cleanup()

            return {
                "id": f"chatcmpl-{uuid.uuid4().hex[:8]}",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": request.model,
                "system_fingerprint": f"req-{req_id}",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": transcription},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": len(combined_prompt.split()) if combined_prompt else 0,
                    "completion_tokens": len(transcription.split()) if transcription else 0,
                    "total_tokens": (
                        len(combined_prompt.split()) + len(transcription.split())
                        if combined_prompt and transcription
                        else 0
                    ),
                },
            }

        else:
            # Regular text chat completion
            # Build prompt from messages
            prompt = build_chat_prompt(request.messages)

            if request.stream:
                # Streaming response
                generator = StreamGenerator(model_manager=model_manager, audio_processor=audio_processor)

                return StreamingResponse(
                    generator.generate_chat_stream(
                        prompt=prompt,
                        temperature=request.temperature,
                        max_tokens=request.max_tokens or ServiceConfig.DEFAULT_MAX_TOKENS,
                        top_p=request.top_p,
                    ),
                    media_type="text/event-stream",
                )
            else:
                # Non-streaming response
                response_text = await generate_text(
                    prompt=prompt,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens or ServiceConfig.DEFAULT_MAX_TOKENS,
                    top_p=request.top_p,
                )

                return {
                    "id": f"chatcmpl-{uuid.uuid4().hex[:8]}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": request.model,
                    "choices": [
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": response_text},
                            "finish_reason": "stop",
                        }
                    ],
                    "usage": {
                        "prompt_tokens": len(prompt.split()),
                        "completion_tokens": len(response_text.split()),
                        "total_tokens": len(prompt.split()) + len(response_text.split()),
                    },
                }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat completion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Helper functions for model management


def determine_model_variant(requested_model: str) -> tuple[str, str]:
    """Determine the full model ID and variant from requested model name."""
    normalized = requested_model.replace("google/", "")

    if "E4B" in normalized.upper():
        return "google/gemma-3n-E4B-it", "E4B"
    elif "E2B" in normalized.upper():
        return "google/gemma-3n-E2B-it", "E2B"
    else:
        # Default to E2B if not specified
        return "google/gemma-3n-E2B-it", "E2B"


def check_model_cached(model_id: str) -> bool:
    """Check if model is already downloaded."""
    model_path = ServiceConfig.CACHE_DIR / "models" / model_id.replace("/", "--")
    return model_path.exists() and any(model_path.glob("*.safetensors"))


def get_huggingface_token() -> Optional[str]:
    """Get HuggingFace token from various environment variables."""
    token = (
        os.environ.get("HUGGINGFACE_TOKEN") or os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    )

    if not token:
        logger.warning("No HuggingFace token found. Attempting download without authentication.")
        logger.info("For gated models like Gemma, add HUGGINGFACE_TOKEN to .env file")

    return token


def get_model_revision(model_id: str) -> str:
    """Get revision for secure model download."""
    model_key = model_id.replace("/", "_").replace("-", "_").upper()
    env_key = f"{model_key}_REVISION"
    return os.environ.get(env_key) or os.environ.get("GEMMA_MODEL_REVISION", "main")


async def update_model_configuration(model_id: str, variant: str, model_manager: Any) -> None:
    """Update configuration and reload model manager."""
    # Update environment and configuration
    os.environ["GEMMA_MODEL_VARIANT"] = variant
    os.environ["GEMMA_MODEL_ID"] = model_id
    ServiceConfig.MODEL_VARIANT = variant
    ServiceConfig.MODEL_ID = model_id

    # Clear and refresh model manager
    if model_manager.is_model_loaded():
        await model_manager.unload_model()

    model_manager.refresh_config()
    logger.info(f"Configuration updated to use {model_id}")


async def download_model_files(model_id: str) -> Path:
    """Download model files from HuggingFace Hub."""
    from huggingface_hub import snapshot_download

    hf_token = get_huggingface_token()
    revision = get_model_revision(model_id)
    download_path = ServiceConfig.CACHE_DIR / "models" / model_id.replace("/", "--")

    result = snapshot_download(  # nosec B615 - revision pinned via config
        repo_id=model_id,
        revision=revision,
        cache_dir=ServiceConfig.CACHE_DIR / "models",
        local_dir=download_path,
        local_dir_use_symlinks=False,
        resume_download=True,
        token=hf_token,
    )
    return Path(result)


@app.post("/v1/models/pull", response_model=None)
async def pull_model(request: ModelPullRequest) -> Union[StreamingResponse, Dict[str, Any]]:
    """
    Download and prepare model with progress streaming.
    Dynamically downloads the requested model and updates configuration.
    """

    async def generate() -> Any:
        """Generator that yields SSE-formatted download progress."""
        try:
            # Determine model ID and variant
            model_id, variant = determine_model_variant(request.model_name)

            # Send initial status
            progress_event = {
                "status": "pulling",
                "digest": model_id,
                "total": None,
                "completed": 0,
            }
            yield f"data: {json.dumps(progress_event)}\n\n"

            # Check if the requested model is already cached
            if check_model_cached(model_id):
                progress_event = {
                    "status": "success",
                    "digest": model_id,
                    "message": "Model already downloaded",
                }
                yield f"data: {json.dumps(progress_event)}\n\n"

                # Update configuration to use this model
                await update_model_configuration(model_id, variant, model_manager)
                return

            # Download model files
            logger.info(f"Starting model download: {model_id}")

            try:
                # Download the model
                model_path = await download_model_files(model_id)

                # Send success message
                progress_event = {
                    "status": "success",
                    "digest": model_id,
                    "message": f"Model downloaded successfully to {model_path}",
                }
                yield f"data: {json.dumps(progress_event)}\n\n"

                # Update configuration to use this model
                await update_model_configuration(model_id, variant, model_manager)

            except Exception as e:
                error_event = {"status": "error", "error": str(e)}
                yield f"data: {json.dumps(error_event)}\n\n"

        except Exception as e:
            logger.error(f"Model pull error: {e}")
            error_event = {"status": "error", "error": str(e)}
            yield f"data: {json.dumps(error_event)}\n\n"

    if request.stream:
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        # Non-streaming download
        try:
            # Determine model ID and variant
            model_id, variant = determine_model_variant(request.model_name)

            # Check if the requested model is already cached
            if check_model_cached(model_id):
                await update_model_configuration(model_id, variant, model_manager)
                return {"status": "success", "message": "Model already downloaded"}

            # Download the model
            model_path = await download_model_files(model_id)

            # Update configuration to use this model
            await update_model_configuration(model_id, variant, model_manager)

            return {"status": "success", "message": f"Model {model_id} downloaded to {model_path}"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/models", response_model=None)
async def list_models() -> Dict[str, Any]:
    """List available models (OpenAI-compatible)."""
    models = []

    # Add current model if available
    if model_manager.is_model_available():
        models.append(
            ModelInfo(
                id=ServiceConfig.MODEL_ID,
                object="model",
                created=int(time.time()),
                owned_by="local",
                capabilities={
                    "chat": True,
                    "audio": True,
                    "transcription": True,
                    "streaming": True,
                },
                size_gb=3.0 if ServiceConfig.MODEL_VARIANT == "E2B" else 9.0,  # E2B: 3GB, E4B: 9GB
            ).dict()
        )

    return {"object": "list", "data": models}


@app.post("/v1/models/load")
async def load_model(background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """
    Explicitly load model into memory.
    """
    try:
        if model_manager.is_model_loaded():
            return {
                "status": "already_loaded",
                "message": f"Model {ServiceConfig.MODEL_ID} is already loaded",
                "device": model_manager.device,
            }

        if not model_manager.is_model_available():
            raise HTTPException(
                status_code=404,
                detail="Model not downloaded. Use /v1/models/pull to download first.",
            )

        # Load model in background
        background_tasks.add_task(model_manager.load_model)

        return {
            "status": "loading",
            "message": f"Loading model {ServiceConfig.MODEL_ID}...",
            "device": model_manager.device,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model load error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Legacy function for backwards compatibility
async def generate_transcription(prompt: str, audio_array: np.ndarray, temperature: float) -> str:
    """Legacy generate_transcription function - use generate_transcription_optimized instead."""
    return await generate_transcription_optimized(prompt, audio_array, temperature)


# Helper functions
def build_chat_prompt(messages: List[Dict[str, Any]], include_audio_token: bool = True) -> str:
    """Build a prompt from chat messages with audio token support."""
    prompt_parts = []

    for message in messages:
        role = message.get("role", "user")
        content = message.get("content", "")

        if role == "system":
            prompt_parts.append(f"System: {content}")
        elif role == "user":
            # Add audio token placeholder for Gemma 3N
            if include_audio_token and "audio" in content.lower():
                # Insert special audio token that Gemma 3N expects
                prompt_parts.append(f"User: <audio>\n{content}")
            else:
                prompt_parts.append(f"User: {content}")
        elif role == "assistant":
            prompt_parts.append(f"Assistant: {content}")

    # Add final prompt for assistant
    prompt_parts.append("Assistant:")

    return "\n\n".join(prompt_parts)


def _compute_decode_cap_for_audio(audio_array: np.ndarray) -> tuple[int, float]:
    """Compute dynamic max_new_tokens cap and duration (seconds) for an audio array."""
    try:
        samples = (
            audio_array.shape[-1]
            if getattr(audio_array, "ndim", None) and audio_array.ndim > 1
            else audio_array.shape[0]
        )
        duration_sec = samples / float(ServiceConfig.AUDIO_SAMPLE_RATE)
    except (AttributeError, IndexError) as e:
        logger.warning(f"Could not determine audio duration from shape, defaulting to 30s. Error: {e}")
        duration_sec = 30.0
    est_tokens = int(duration_sec * ServiceConfig.TOKENS_PER_SEC) + ServiceConfig.TOKEN_BUFFER
    cap = max(128, min(1024, est_tokens))
    return cap, duration_sec


async def generate_transcription_optimized(
    prompt: str,
    audio_array: NDArray[np.float32],
    temperature: float,
    task_type: str = "cpu_optimized",
    request_id: Optional[str] = None,
) -> str:
    """Generate transcription from audio."""

    try:
        # Use the processor to handle both audio and text together

        # Reshape audio to add batch dimension if needed
        if audio_array.ndim == 1:
            audio_array = audio_array.reshape(1, -1)

        # Process audio and text through the unified processor
        if model_manager.processor is None:
            raise ValueError("Processor not loaded")
        inputs = model_manager.processor(
            audio=audio_array,
            text=prompt,
            sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
            return_tensors="pt",
        )

        # Move inputs to device
        inputs = {k: v.to(model_manager.device) if hasattr(v, "to") else v for k, v in inputs.items()}

        # Get optimized generation config for the task + dynamic cap
        gen_config = ServiceConfig.get_generation_config(task_type)
        dynamic_cap, duration_sec = _compute_decode_cap_for_audio(audio_array)
        if model_manager.tokenizer is None:
            raise ValueError("Tokenizer not loaded")
        gen_config.update(
            {
                "pad_token_id": model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
                "eos_token_id": model_manager.tokenizer.eos_token_id,
                "max_new_tokens": min(gen_config.get("max_new_tokens", 2000), dynamic_cap),
            }
        )
        # Remove flags the Gemma 3N generate may ignore to reduce warnings
        for k in ("temperature", "top_p", "top_k", "early_stopping"):
            gen_config.pop(k, None)
        if request_id:
            logger.info(
                f"[REQ {request_id}] Decode cap: max_new_tokens={gen_config['max_new_tokens']} "
                f"(≈{duration_sec:.1f}s audio)"
            )
        else:
            logger.info(
                f"Transcription decode cap: max_new_tokens={gen_config['max_new_tokens']} "
                f"(duration≈{duration_sec:.1f}s)"
            )

        # Use inference mode for better CPU performance
        if model_manager.model is None:
            raise ValueError("Model not loaded")
        t0 = time.perf_counter()
        if model_manager.device == "cpu":
            with torch.inference_mode():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        else:
            with torch.no_grad():
                outputs = model_manager.model.generate(**inputs, **gen_config)
        t1 = time.perf_counter()

        # Check if generation succeeded
        if outputs is None or len(outputs) == 0:
            logger.error("Model generation failed - no outputs produced")
            raise ValueError("Model generation failed - no outputs produced")

        # Decode
        # Decode the output, skipping the input tokens
        if model_manager.tokenizer is None:
            raise ValueError("Tokenizer not loaded")
        input_length = inputs["input_ids"].shape[1] if "input_ids" in inputs else 0
        response = model_manager.tokenizer.decode(outputs[0][input_length:], skip_special_tokens=True)
        try:
            new_tokens = max(0, outputs.shape[1] - input_length)
            msg = f"Generated {new_tokens} tokens in {(t1 - t0):.2f}s ({(new_tokens / max(1e-3, (t1 - t0))):.1f} tok/s)"
            if request_id:
                logger.info(f"[REQ {request_id}] {msg}")
            else:
                logger.info(msg)
        except Exception as e:
            logger.warning(f"Could not log token generation stats: {e}")

        return response.strip()

    except Exception as e:
        logger.error("=== GENERATION ERROR ===")
        logger.error(f"Error type: {type(e).__name__}")
        logger.error(f"Error message: {e}")
        logger.error("Full traceback:", exc_info=True)
        raise


async def process_audio_chunks(chunks: List[np.ndarray], prompt: str, temperature: float) -> str:
    """Process multiple audio chunks and combine transcriptions."""

    transcriptions = []
    for i, chunk in enumerate(chunks):

        try:
            # Use shorter prompt for chunks after the first
            chunk_prompt = prompt if i == 0 else "Transcribe the following audio chunk:"

            transcription = await generate_transcription_optimized(
                prompt=chunk_prompt,
                audio_array=chunk,
                temperature=temperature,
                task_type="cpu_optimized",
            )

            if transcription.strip():
                transcriptions.append(transcription.strip())

        except Exception as e:
            logger.warning(f"Failed to process chunk {i + 1}: {e}")
            # Continue with other chunks

    # Combine transcriptions with proper spacing
    final_transcription = " ".join(transcriptions)

    return final_transcription


async def generate_transcription_with_chat_context(
    messages: List[Dict[str, Any]],
    audio_array: NDArray[np.float32],
    request_id: Optional[str] = None,
) -> str:
    """Generate transcription using chat context for better understanding."""
    try:
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            logger.error("Model not loaded for chunk processing!")

            # Check memory before loading
            if model_manager._check_memory_pressure():
                logger.warning("High memory usage before model loading, attempting cleanup")
                model_manager._force_cleanup()

            load_success = await model_manager.load_model()
            if not load_success or not model_manager.is_model_loaded():
                raise Exception(
                    f"Failed to load model for chunk processing. "
                    f"Load success: {load_success}, Is loaded: {model_manager.is_model_loaded()}"
                )

        prefix = f"[REQ {request_id}] " if request_id else ""
        logger.info(f"{prefix}Audio array shape: {audio_array.shape}, dtype: {audio_array.dtype}")

        # Convert audio to float32 and ensure it's in the correct format

        # Ensure audio is float32 (Gemma 3N expects this)
        if audio_array.dtype != np.float32:
            audio_array = audio_array.astype(np.float32)

        # Ensure audio is 1D
        if audio_array.ndim == 2:
            # If stereo, average both channels to create mono
            audio_array = np.mean(audio_array, axis=0)
        elif audio_array.ndim > 2:
            # Flatten multi-dimensional arrays
            audio_array = audio_array.flatten()

        # Ensure it's 1D with proper shape
        audio_array = np.squeeze(audio_array)
        if audio_array.ndim != 1:
            audio_array = audio_array.flatten()

        # Normalize audio to [-1, 1] range as expected by Gemma 3N
        max_val = np.abs(audio_array).max()
        if max_val > 1.0:
            audio_array = audio_array / max_val
        elif max_val == 0:
            # Handle silent audio
            logger.warning("Audio appears to be silent (all zeros)")

        # Ensure audio is not empty
        if len(audio_array) == 0:
            raise ValueError("Audio array is empty after preprocessing")

        logger.info(
            f"{prefix}Processed audio shape: {audio_array.shape}, dtype: {audio_array.dtype}, "
            f"range: [{audio_array.min():.2f}, {audio_array.max():.2f}]"
        )

        # Use Lotti-style structured prompting for better transcription
        # Create message structure with audio content matching Lotti's approach
        formatted_messages = [
            {
                "role": "user",
                "content": [
                    {"type": "audio", "audio": audio_array},  # Pass numpy array directly
                    {"type": "text", "text": "Transcribe the audio."},
                ],
            }
        ]

        logger.info(f"{prefix}Using apply_chat_template with structured messages")

        # Apply chat template to get proper inputs
        try:
            if model_manager.processor is None:
                raise ValueError("Processor not loaded")
            inputs = model_manager.processor.apply_chat_template(
                formatted_messages,
                add_generation_prompt=True,
                tokenize=True,
                return_dict=True,
                return_tensors="pt",
            )
            logger.info(f"{prefix}✅ Chat template applied successfully; input keys: {list(inputs.keys())}")

        except Exception as template_error:
            logger.error(f"Chat template error: {template_error}")
            # Fallback to direct processor call if apply_chat_template fails
            logger.info(f"{prefix}Falling back to direct processor call")

            if model_manager.processor is None:
                raise ValueError("Processor not loaded")
            inputs = model_manager.processor(
                text="Transcribe this audio",
                audio=audio_array,
                sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
                return_tensors="pt",
            )

        # Move inputs to device
        inputs = {k: v.to(model_manager.device) if hasattr(v, "to") else v for k, v in inputs.items()}

        # Get optimized generation config for transcription with dynamic cap
        gen_config = ServiceConfig.get_generation_config("transcription")
        dynamic_cap, duration_sec = _compute_decode_cap_for_audio(audio_array)
        if model_manager.tokenizer is None:
            raise ValueError("Tokenizer not loaded")
        gen_config.update(
            {
                "pad_token_id": model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
                "eos_token_id": model_manager.tokenizer.eos_token_id,
                "max_new_tokens": min(gen_config.get("max_new_tokens", 2000), dynamic_cap),
            }
        )
        for k in ("temperature", "top_p", "top_k", "early_stopping"):
            gen_config.pop(k, None)
        logger.info(f"{prefix}Decode cap: max_new_tokens={gen_config['max_new_tokens']} (≈{duration_sec:.1f}s audio)")

        # Use appropriate inference mode based on device
        if model_manager.model is None:
            raise ValueError("Model not loaded")
        try:
            t0 = time.perf_counter()
            if model_manager.device == "cpu":
                with torch.inference_mode():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
            else:  # mps or cuda
                with torch.no_grad():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
            t1 = time.perf_counter()
        except Exception as e:
            logger.error(f"Generation failed on {model_manager.device}: {e}")
            # Fallback to simpler generation with configured limits
            if model_manager.model is None or model_manager.tokenizer is None:
                raise ValueError("Model or tokenizer not loaded")
            outputs = model_manager.model.generate(
                **inputs,
                max_new_tokens=gen_config.get("max_new_tokens", 2000),
                do_sample=False,
                eos_token_id=model_manager.tokenizer.eos_token_id,
                pad_token_id=model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
            )

        # Decode the output, skipping the input tokens
        if model_manager.tokenizer is None:
            raise ValueError("Tokenizer not loaded")
        input_length = inputs["input_ids"].shape[1] if "input_ids" in inputs else 0
        response = model_manager.tokenizer.decode(outputs[0][input_length:], skip_special_tokens=True)
        try:
            new_tokens = max(0, outputs.shape[1] - input_length)
            logger.info(
                f"{prefix}Generated {new_tokens} tokens in {(t1 - t0):.2f}s "
                f"({(new_tokens / max(1e-3, (t1 - t0))):.1f} tok/s); "
                f"device={model_manager.device}, dtype={ServiceConfig.TORCH_DTYPE}"
            )
        except Exception as e:
            logger.warning(f"Could not log token generation stats: {e}")

        transcription = response.strip()

        # Whisper-like output cleaning - remove redundancy but keep full content
        def clean_whisper_style(text: str) -> str:
            """Clean transcription output to remove redundancy but preserve all content."""
            # If text contains "Transcription:" markers, it means multiple attempts
            if "Transcription:" in text:
                parts = text.split("Transcription:")
                if len(parts) > 1:
                    # Take the first actual transcription part
                    text = parts[1].split("Text Transcription:")[0]
                    text = text.split("\n")[0]  # Take first line of that part

            # Stop at indicators that the model is adding meta-commentary
            stop_indicators = [
                "Speaker change",
                "No fillers present",
                "Clear formatting",
                "This is a transcription",
                "The transcription is",
                "Here is the transcription",
                "I'm sorry",
                "I apologize",
                "Please provide",
            ]

            for indicator in stop_indicators:
                if indicator in text:
                    text = text.split(indicator)[0]

            # Remove common prefixes only if they exist
            prefixes_to_remove = ["Transcription: ", "Text: ", "Audio: "]
            for prefix in prefixes_to_remove:
                if text.startswith(prefix):
                    text = text[len(prefix) :]

            return text.strip()

        transcription = clean_whisper_style(transcription)

        # Final safety check for reasonable length
        max_reasonable_length = 2000  # ~1000 words max for 2-minute audio
        if len(transcription) > max_reasonable_length:
            transcription = transcription[:max_reasonable_length].strip()
            logger.info(f"Truncated to reasonable length: {max_reasonable_length} chars")

        logger.info(f"Final transcription result length: {len(transcription)} chars")

        return transcription

    except Exception as e:
        logger.error(f"Chat-context transcription error: {e}")
        logger.error("Full traceback:", exc_info=True)
        raise


async def process_audio_chunks_with_continuation(
    chunks: List[np.ndarray],
    initial_messages: List[Dict[str, Any]],
    request_id: Optional[str] = None,
) -> str:
    """
    Process multiple audio chunks with smart continuation.
    Each chunk gets the previous transcription as context to continue from.
    """
    transcriptions = []
    previous_text = ""

    prefix = f"[REQ {request_id}] " if request_id else ""
    logger.info(f"{prefix}Processing {len(chunks)} audio chunks with continuation context")

    # Process all chunks for full transcription
    chunks_to_process = chunks
    logger.info(f"{prefix}Processing all {len(chunks_to_process)} chunks for complete transcription")

    # Log chunk durations for debugging
    for i, chunk in enumerate(chunks_to_process):
        chunk_duration = len(chunk) / 16000  # assuming 16kHz sample rate
        logger.info(f"{prefix}Chunk {i + 1}: {chunk_duration:.1f}s ({len(chunk)} samples)")

    for i, chunk in enumerate(chunks_to_process):
        try:
            logger.info(f"{prefix}Processing chunk {i + 1}/{len(chunks_to_process)}")

            # Use simple prompt for all chunks
            chunk_messages = [
                {
                    "role": "system",
                    "content": "You are a helpful assistant that transcribes audio accurately.",
                },
                {"role": "user", "content": "Transcribe this audio:"},
            ]

            transcription = await generate_transcription_with_chat_context(
                messages=chunk_messages, audio_array=chunk, request_id=request_id
            )

            # Clean up transcription
            cleaned = transcription.strip()

            # Remove any duplicate text from the beginning that might overlap with previous
            if i > 0 and previous_text:
                # Check for overlap at the boundary (last 50 chars of previous with first 50 of current)
                overlap_window = min(50, len(previous_text), len(cleaned))
                if overlap_window > 10:
                    last_prev = previous_text[-overlap_window:].lower()
                    first_curr = cleaned[:overlap_window].lower()

                    # Find overlap
                    for j in range(overlap_window, 10, -1):
                        if last_prev[-j:] == first_curr[:j]:
                            # Remove the overlapping part from current
                            cleaned = cleaned[j:].strip()
                            logger.info(f"{prefix}Removed {j} overlapping characters from chunk {i + 1}")
                            break

            if cleaned:
                transcriptions.append(cleaned)
                previous_text = " ".join(transcriptions)  # Update context with all text so far
                logger.info(f"{prefix}Chunk {i + 1} transcribed ({len(cleaned)} chars)")

        except Exception as e:
            logger.error(f"Failed to process chunk {i + 1}: {e}")
            logger.error(f"Chunk {i + 1} error details:", exc_info=True)
            # Add placeholder to maintain chunk order
            transcriptions.append(f"[Chunk {i + 1} failed to process]")
            # Continue with other chunks but don't update previous_text

    # Join all transcriptions with proper spacing
    final_transcription = " ".join(transcriptions)

    # Final cleanup - remove any remaining artifacts
    final_transcription = final_transcription.replace("---|", "").replace("|---", "")
    final_transcription = final_transcription.replace("Previous transcription:", "")
    final_transcription = final_transcription.replace("Continue transcribing:", "")

    return final_transcription


async def process_audio_chunks_with_context(
    chunks: List[np.ndarray], messages: List[Dict[str, Any]], temperature: float
) -> str:
    """Legacy function - redirects to continuation-based processing (temperature ignored)."""
    return await process_audio_chunks_with_continuation(chunks, messages)


async def generate_text(prompt: str, temperature: float, max_tokens: int, top_p: float) -> str:
    """Generate text completion."""
    try:
        # Tokenize input
        if model_manager.tokenizer is None:
            raise ValueError("Tokenizer not loaded")
        if model_manager.model is None:
            raise ValueError("Model not loaded")
        inputs = model_manager.tokenizer(prompt, return_tensors="pt", truncation=True, max_length=2048).to(
            model_manager.device
        )

        # Generate
        with torch.no_grad():
            outputs = model_manager.model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=temperature,
                do_sample=temperature > 0,
                top_p=top_p,
                pad_token_id=model_manager.tokenizer.pad_token_id,
                eos_token_id=model_manager.tokenizer.eos_token_id,
            )

        # Decode
        response = model_manager.tokenizer.decode(outputs[0][inputs.input_ids.shape[1] :], skip_special_tokens=True)

        return response.strip()

    except Exception as e:
        logger.error(f"Generation error: {e}")
        raise


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=ServiceConfig.DEFAULT_HOST,
        port=ServiceConfig.DEFAULT_PORT,
        log_level=ServiceConfig.LOG_LEVEL.lower(),
    )
