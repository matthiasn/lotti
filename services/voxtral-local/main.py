"""Main FastAPI application for Voxtral Local Service."""

import json
import logging
import os
import sys
import time
import uuid
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import numpy as np
import torch
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from numpy.typing import NDArray
from pydantic import BaseModel, Field

# Load environment variables
env_path = Path(__file__).parent / ".env"
if env_path.exists():
    load_dotenv(env_path)

from audio_processor import audio_processor
from config import ServiceConfig
from model_manager import model_manager

# Configure logging
logging.basicConfig(
    level=getattr(logging, ServiceConfig.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

try:
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))

    log_file = ServiceConfig.LOG_DIR / "service.log"
    file_handler = RotatingFileHandler(
        log_file, maxBytes=5 * 1024 * 1024, backupCount=3
    )
    file_handler.setLevel(getattr(logging, ServiceConfig.LOG_LEVEL))
    fmt = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    file_handler.setFormatter(fmt)
    if not any(isinstance(h, RotatingFileHandler) for h in root_logger.handlers):
        root_logger.addHandler(file_handler)

    if os.getenv("LOG_TO_STDOUT", "0").lower() in ("1", "true", "yes", "on"):
        if not any(
            isinstance(h, logging.StreamHandler)
            and getattr(h, "stream", None) is sys.stdout
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
    title="Voxtral Local Service",
    description="Local Voxtral model service with OpenAI-compatible API for speech transcription",
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
class TranscriptionRequest(BaseModel):
    """Request model for audio transcription."""

    file: Optional[str] = Field(None, description="Base64-encoded audio data")
    model: str = "voxtral-mini"
    language: Optional[str] = Field(None, description="Language hint (auto-detected)")
    prompt: Optional[str] = Field(None, description="Context prompt for transcription")
    temperature: float = 0.0


class ChatCompletionRequest(BaseModel):
    """Request model for chat completion with audio support."""

    model: str = "voxtral-mini"
    messages: List[Dict[str, Any]]
    temperature: float = 0.0
    max_tokens: Optional[int] = 4096
    stream: bool = False
    audio: Optional[str] = Field(None, description="Base64-encoded audio data")
    language: Optional[str] = Field(None, description="Language hint")


class ModelPullRequest(BaseModel):
    """Request model for model download."""

    model_name: str = "mistralai/Voxtral-Mini-3B-2507"
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
    logger.info(f"Starting Voxtral Local Service with model: {ServiceConfig.MODEL_ID}")
    logger.info(f"Device: {ServiceConfig.DEFAULT_DEVICE}")
    logger.info(
        f"Torch version: {torch.__version__}; dtype: {ServiceConfig.TORCH_DTYPE}"
    )
    logger.info(
        f"Max audio duration: {ServiceConfig.MAX_AUDIO_DURATION_SECONDS}s "
        f"({ServiceConfig.MAX_AUDIO_DURATION_SECONDS/60:.0f} min)"
    )

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
        "max_audio_minutes": ServiceConfig.MAX_AUDIO_DURATION_SECONDS / 60,
    }


# OpenAI-compatible transcription endpoint
@app.post("/v1/audio/transcriptions")
async def transcribe_audio(request: TranscriptionRequest) -> Dict[str, Any]:
    """
    OpenAI-compatible audio transcription endpoint.

    Accepts base64-encoded audio and returns transcription.
    """
    try:
        req_id = uuid.uuid4().hex[:8]
        logger.info(f"[REQ {req_id}] Transcription request received")

        if not request.file:
            raise HTTPException(status_code=400, detail="No audio data provided")

        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(
                    status_code=404,
                    detail="Model not downloaded. Use /v1/models/pull to download.",
                )
            logger.info(f"[REQ {req_id}] Loading model...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(status_code=500, detail="Failed to load model")

        # Process audio
        t0 = time.perf_counter()
        result = await audio_processor.process_audio_base64(
            request.file,
            request.prompt,
            use_chunking=True,
            request_id=req_id,
        )
        t1 = time.perf_counter()

        # Handle chunked vs single audio
        if isinstance(result[0], list):
            audio_chunks, prompt = result
            transcription = await _process_chunks(
                audio_chunks, prompt, request.language, req_id
            )
        else:
            audio_array, prompt = result
            transcription = await _transcribe_single(
                audio_array, prompt, request.language, req_id
            )

        t2 = time.perf_counter()
        logger.info(
            f"[REQ {req_id}] Done. AudioProc={(t1-t0):.2f}s, "
            f"Transcribe={(t2-t1):.2f}s, Total={(t2-t0):.2f}s"
        )

        return {
            "text": transcription,
            "model": request.model,
            "language": request.language or "auto",
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Transcription error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# Chat completions endpoint with audio support
@app.post("/v1/chat/completions", response_model=None)
async def chat_completion(
    request: ChatCompletionRequest,
) -> Union[Dict[str, Any], StreamingResponse]:
    """
    OpenAI-compatible chat completion endpoint with audio transcription support.

    When audio data is provided, performs transcription.
    """
    try:
        req_id = uuid.uuid4().hex[:8]

        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            if not model_manager.is_model_available():
                raise HTTPException(
                    status_code=404,
                    detail="Model not downloaded. Use /v1/models/pull to download.",
                )
            logger.info(f"[REQ {req_id}] Loading model...")
            success = await model_manager.load_model()
            if not success:
                raise HTTPException(status_code=500, detail="Failed to load model")

        # Check if this is audio transcription
        if request.audio:
            logger.info(f"[REQ {req_id}] Audio transcription via chat completions")

            # Extract full context from messages (system + user messages)
            context_parts = []
            for message in request.messages:
                role = message.get("role", "")
                content = message.get("content", "")
                if isinstance(content, str) and content.strip():
                    if role == "system":
                        context_parts.append(f"Instructions: {content}")
                    elif role == "user":
                        context_parts.append(content)

            context_prompt = "\n".join(context_parts) if context_parts else None
            logger.info(f"[REQ {req_id}] Context: {context_prompt[:200] if context_prompt else 'None'}...")

            # Process audio
            t0 = time.perf_counter()
            result = await audio_processor.process_audio_base64(
                request.audio,
                context_prompt,
                use_chunking=True,
                request_id=req_id,
            )
            t1 = time.perf_counter()

            # Handle chunked vs single audio
            if isinstance(result[0], list):
                audio_chunks, prompt = result
                transcription = await _process_chunks(
                    audio_chunks, prompt, request.language, req_id
                )
            else:
                audio_array, prompt = result
                transcription = await _transcribe_single(
                    audio_array, prompt, request.language, req_id
                )

            t2 = time.perf_counter()
            logger.info(
                f"[REQ {req_id}] Done. AudioProc={(t1-t0):.2f}s, "
                f"Transcribe={(t2-t1):.2f}s"
            )

            return {
                "id": f"chatcmpl-{req_id}",
                "object": "chat.completion",
                "created": int(time.time()),
                "model": request.model,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": transcription},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": 0,
                    "completion_tokens": len(transcription.split()),
                    "total_tokens": len(transcription.split()),
                },
            }

        else:
            # Text-only chat not supported yet
            raise HTTPException(
                status_code=400,
                detail="Text-only chat not supported. Provide audio for transcription.",
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat completion error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


async def _transcribe_single(
    audio_array: NDArray[np.float32],
    context: Optional[str],
    language: Optional[str],
    req_id: str,
) -> str:
    """Transcribe a single audio array with optional context."""
    logger.info(f"[REQ {req_id}] Transcribing single audio segment")

    # Ensure audio is float32 and 1D
    if audio_array.dtype != np.float32:
        audio_array = audio_array.astype(np.float32)
    if audio_array.ndim == 2:
        audio_array = np.mean(audio_array, axis=0)
    audio_array = np.squeeze(audio_array)

    # Normalize
    max_val = np.abs(audio_array).max()
    if max_val > 1.0:
        audio_array = audio_array / max_val

    # Build transcription instruction with context
    instruction_parts = []
    if context:
        instruction_parts.append(context)

    if language and language != "auto":
        instruction_parts.append(f"Transcribe the following audio in {language}.")
    else:
        instruction_parts.append("Transcribe the following audio.")

    transcription_instruction = "\n\n".join(instruction_parts)

    # Build conversation for Voxtral
    conversation = [
        {
            "role": "user",
            "content": [
                {"type": "audio", "audio": audio_array},
                {"type": "text", "text": transcription_instruction},
            ],
        }
    ]

    # Process with Voxtral
    try:
        inputs = model_manager.processor.apply_chat_template(
            conversation,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        )
    except Exception as e:
        logger.warning(f"[REQ {req_id}] Chat template failed: {e}, using fallback")
        inputs = model_manager.processor(
            text="Transcribe this audio.",
            audio=audio_array,
            sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
            return_tensors="pt",
        )

    # Move to device
    inputs = {
        k: v.to(model_manager.device) if hasattr(v, "to") else v
        for k, v in inputs.items()
    }

    # Generate
    gen_config = ServiceConfig.get_generation_config("transcription")
    gen_config["pad_token_id"] = model_manager.processor.tokenizer.pad_token_id
    gen_config["eos_token_id"] = model_manager.processor.tokenizer.eos_token_id

    t0 = time.perf_counter()
    with torch.inference_mode() if model_manager.device == "cpu" else torch.no_grad():
        outputs = model_manager.model.generate(**inputs, **gen_config)
    t1 = time.perf_counter()

    # Decode
    input_length = inputs["input_ids"].shape[1] if "input_ids" in inputs else 0
    transcription = model_manager.processor.tokenizer.decode(
        outputs[0][input_length:], skip_special_tokens=True
    )

    new_tokens = max(0, outputs.shape[1] - input_length)
    logger.info(
        f"[REQ {req_id}] Generated {new_tokens} tokens in {t1-t0:.2f}s "
        f"({new_tokens/max(0.001, t1-t0):.1f} tok/s)"
    )

    return transcription.strip()


async def _process_chunks(
    chunks: List[NDArray[np.float32]],
    prompt: str,
    language: Optional[str],
    req_id: str,
) -> str:
    """Process multiple audio chunks and combine transcriptions."""
    logger.info(f"[REQ {req_id}] Processing {len(chunks)} audio chunks")

    transcriptions = []
    for i, chunk in enumerate(chunks):
        try:
            logger.info(f"[REQ {req_id}] Processing chunk {i+1}/{len(chunks)}")
            chunk_transcription = await _transcribe_single(
                chunk, prompt, language, req_id
            )
            if chunk_transcription.strip():
                transcriptions.append(chunk_transcription.strip())
        except Exception as e:
            logger.warning(f"[REQ {req_id}] Chunk {i+1} failed: {e}")
            transcriptions.append(f"[Chunk {i+1} failed]")

    return " ".join(transcriptions)


# Model management endpoints
@app.post("/v1/models/pull", response_model=None)
async def pull_model(
    request: ModelPullRequest,
) -> Union[StreamingResponse, Dict[str, Any]]:
    """Download model from HuggingFace."""

    async def generate() -> Any:
        try:
            model_id = request.model_name

            yield f"data: {json.dumps({'status': 'pulling', 'digest': model_id})}\n\n"

            if model_manager.is_model_available():
                yield f"data: {json.dumps({'status': 'success', 'message': 'Model already downloaded'})}\n\n"
                return

            logger.info(f"Starting model download: {model_id}")

            async for progress in model_manager.download_model():
                yield f"data: {json.dumps(progress)}\n\n"

        except Exception as e:
            logger.error(f"Model pull error: {e}")
            yield f"data: {json.dumps({'status': 'error', 'error': str(e)})}\n\n"

    if request.stream:
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        try:
            if model_manager.is_model_available():
                return {"status": "success", "message": "Model already downloaded"}

            async for _ in model_manager.download_model():
                pass

            return {"status": "success", "message": "Model downloaded"}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/v1/models")
async def list_models() -> Dict[str, Any]:
    """List available models."""
    models = []

    if model_manager.is_model_available():
        models.append(
            ModelInfo(
                id=ServiceConfig.MODEL_ID,
                object="model",
                created=int(time.time()),
                owned_by="local",
                capabilities={
                    "audio": True,
                    "transcription": True,
                    "streaming": False,  # Will be True with vLLM
                },
                size_gb=9.5,  # Voxtral Mini 3B
            ).model_dump()
        )

    return {"object": "list", "data": models}


@app.post("/v1/models/load")
async def load_model() -> Dict[str, Any]:
    """Explicitly load model into memory."""
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
                detail="Model not downloaded. Use /v1/models/pull first.",
            )

        success = await model_manager.load_model()
        if not success:
            raise HTTPException(status_code=500, detail="Failed to load model")

        return {
            "status": "loaded",
            "message": f"Model {ServiceConfig.MODEL_ID} loaded",
            "device": model_manager.device,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Model load error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        app,
        host=ServiceConfig.DEFAULT_HOST,
        port=ServiceConfig.DEFAULT_PORT,
        log_level=ServiceConfig.LOG_LEVEL.lower(),
    )
