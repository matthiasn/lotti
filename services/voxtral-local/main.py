"""Main FastAPI application for Voxtral Local Service."""

import asyncio
import json
import logging
import os
import sys
import time
import uuid
from contextlib import asynccontextmanager
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

import numpy as np
import torch
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from numpy.typing import NDArray
from pydantic import BaseModel, Field
from threading import Thread
from transformers import TextIteratorStreamer

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


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup/shutdown events."""
    # Startup
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

    yield
    # Shutdown (nothing to do currently)


# Create FastAPI app
app = FastAPI(
    title="Voxtral Local Service",
    description="Local Voxtral model service with OpenAI-compatible API for speech transcription",
    version="1.0.0",
    lifespan=lifespan,
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
            use_chunking=False,
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
    Supports streaming mode (stream=true) for progressive chunk-by-chunk output.
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
            logger.info(f"[REQ {req_id}] Audio transcription via chat completions (stream={request.stream})")

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
                use_chunking=False,
                request_id=req_id,
            )
            t1 = time.perf_counter()
            logger.info(f"[REQ {req_id}] Audio processing took {t1-t0:.2f}s")

            # Handle streaming vs non-streaming response
            if request.stream:
                # Stream each chunk's transcription as it completes
                return StreamingResponse(
                    _stream_transcription(result, request, context_prompt, req_id, t0),
                    media_type="text/event-stream",
                    headers={
                        "Cache-Control": "no-cache",
                        "Connection": "keep-alive",
                        "X-Accel-Buffering": "no",  # Disable nginx buffering
                    },
                )
            else:
                # Non-streaming: process all and return single response
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


async def _stream_transcription(
    result: Union[
        Tuple[NDArray[np.float32], str], Tuple[List[NDArray[np.float32]], str]
    ],
    request: ChatCompletionRequest,
    context_prompt: Optional[str],
    req_id: str,
    t0: float,
) -> Any:
    """
    Stream transcription chunks as SSE events.

    Each chunk's transcription is sent as a separate SSE event, providing
    real-time feedback to the client as each 60-second segment is processed.
    """
    try:
        created_time = int(time.time())
        chunk_index = 0

        if isinstance(result[0], list):
            # Multiple chunks - stream each one
            audio_chunks, prompt = result
            total_chunks = len(audio_chunks)
            logger.info(f"[REQ {req_id}] Streaming {total_chunks} audio chunks")

            for i, chunk in enumerate(audio_chunks):
                try:
                    logger.info(f"[REQ {req_id}] Transcribing chunk {i+1}/{total_chunks}")
                    chunk_transcription = await _transcribe_single(
                        chunk, prompt, request.language, req_id
                    )

                    if chunk_transcription.strip():
                        # Add space separator between chunks (except first)
                        content = chunk_transcription.strip()
                        if chunk_index > 0:
                            content = " " + content

                        # Send SSE event with chunk transcription
                        event_data = {
                            "id": f"chatcmpl-{req_id}",
                            "object": "chat.completion.chunk",
                            "created": created_time,
                            "model": request.model,
                            "choices": [
                                {
                                    "index": 0,
                                    "delta": {"content": content},
                                    "finish_reason": None,
                                }
                            ],
                        }
                        yield f"data: {json.dumps(event_data)}\n\n"
                        chunk_index += 1

                except Exception as e:
                    logger.warning(f"[REQ {req_id}] Chunk {i+1} failed: {e}")
                    # Send error indicator in stream
                    error_content = f" [Chunk {i+1} failed]"
                    if chunk_index == 0:
                        error_content = error_content.strip()
                    event_data = {
                        "id": f"chatcmpl-{req_id}",
                        "object": "chat.completion.chunk",
                        "created": created_time,
                        "model": request.model,
                        "choices": [
                            {
                                "index": 0,
                                "delta": {"content": error_content},
                                "finish_reason": None,
                            }
                        ],
                    }
                    yield f"data: {json.dumps(event_data)}\n\n"
                    chunk_index += 1

        else:
            # Single audio segment - stream token by token
            audio_array, prompt = result
            logger.info(f"[REQ {req_id}] Starting token-by-token streaming")

            async for token in _transcribe_streaming(
                audio_array, prompt, request.language, req_id
            ):
                if token:
                    event_data = {
                        "id": f"chatcmpl-{req_id}",
                        "object": "chat.completion.chunk",
                        "created": created_time,
                        "model": request.model,
                        "choices": [
                            {
                                "index": 0,
                                "delta": {"content": token},
                                "finish_reason": None,
                            }
                        ],
                    }
                    yield f"data: {json.dumps(event_data)}\n\n"

        # Send final chunk with finish_reason
        final_event = {
            "id": f"chatcmpl-{req_id}",
            "object": "chat.completion.chunk",
            "created": created_time,
            "model": request.model,
            "choices": [
                {
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop",
                }
            ],
        }
        yield f"data: {json.dumps(final_event)}\n\n"
        yield "data: [DONE]\n\n"

        t_end = time.perf_counter()
        logger.info(f"[REQ {req_id}] Streaming complete. Total time: {t_end-t0:.2f}s")

    except Exception as e:
        logger.error(f"[REQ {req_id}] Streaming error: {e}", exc_info=True)
        error_event = {
            "id": f"chatcmpl-{req_id}",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": request.model,
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "content": (
                            "[Error: An internal error occurred during streaming. "
                            "Please try again later.]"
                        )
                    },
                    "finish_reason": "stop",
                }
            ],
        }
        yield f"data: {json.dumps(error_event)}\n\n"
        yield "data: [DONE]\n\n"


def _audio_array_to_base64(audio_array: NDArray[np.float32], sample_rate: int) -> str:
    """Convert numpy audio array to base64-encoded WAV."""
    import io
    import base64
    import soundfile as sf

    buffer = io.BytesIO()
    sf.write(buffer, audio_array, sample_rate, format='WAV')
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode('utf-8')


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

    # Build transcription instruction
    instruction_parts = []

    # Include context (speech dictionary, task context, etc.) if provided
    if context and context.strip():
        instruction_parts.append(context)

    # Add transcription directive with explicit language preservation
    # CRITICAL: Voxtral must NOT translate - output must match source language
    if language and language != "auto":
        instruction_parts.append(
            f"Transcribe the following audio in {language}. "
            "Output the transcription in the SAME language as spoken - do NOT translate."
        )
    else:
        instruction_parts.append(
            "Transcribe the following audio in its ORIGINAL language. "
            "Do NOT translate to English or any other language. "
            "Output the exact words spoken in the same language as the speaker."
        )

    # Add speech dictionary instruction if context was provided
    if context and context.strip():
        instruction_parts.append(
            "IMPORTANT: If a word sounds similar to any term in the speech dictionary or context above, "
            "use the exact spelling from the dictionary. The audio may be unclear but those are the "
            "correct spellings for this context."
        )

    # Request proper grammar and plain text output
    instruction_parts.append(
        "Use proper grammar and capitalization appropriate for the detected language "
        "(e.g., in English: capitalize 'I', first letter of sentences, proper nouns). "
        "Return ONLY the plain text transcription - no JSON, XML, or other formatting."
    )

    transcription_instruction = "\n\n".join(instruction_parts)

    # Convert audio to base64 for the chat template
    audio_base64 = _audio_array_to_base64(audio_array, ServiceConfig.AUDIO_SAMPLE_RATE)

    # Build conversation for Voxtral
    conversation = [
        {
            "role": "user",
            "content": [
                {"type": "audio", "base64": audio_base64},
                {"type": "text", "text": transcription_instruction},
            ],
        }
    ]

    logger.info(f"[REQ {req_id}] Transcribing with chat template")
    inputs = model_manager.processor.apply_chat_template(conversation)

    # Run blocking inference in thread pool to avoid blocking event loop
    # This allows SSE events to be sent between chunks
    def _run_inference():
        # Move inputs to device with correct dtype
        device_inputs = inputs.to(model_manager.device, dtype=ServiceConfig.TORCH_DTYPE)

        # Generate
        gen_config = ServiceConfig.get_generation_config("transcription")

        t0 = time.perf_counter()
        with torch.inference_mode():
            outputs = model_manager.model.generate(**device_inputs, **gen_config)
        t1 = time.perf_counter()

        # Decode - skip input tokens
        input_length = device_inputs.input_ids.shape[1] if hasattr(device_inputs, 'input_ids') else device_inputs["input_ids"].shape[1]
        transcription = model_manager.processor.batch_decode(
            outputs[:, input_length:], skip_special_tokens=True
        )[0]

        new_tokens = max(0, outputs.shape[1] - input_length)
        logger.info(
            f"[REQ {req_id}] Generated {new_tokens} tokens in {t1-t0:.2f}s "
            f"({new_tokens/max(0.001, t1-t0):.1f} tok/s)"
        )

        return transcription.strip()

    # Run in thread pool to not block event loop (enables SSE streaming)
    transcription = await asyncio.to_thread(_run_inference)
    return transcription


async def _transcribe_streaming(
    audio_array: NDArray[np.float32],
    context: Optional[str],
    language: Optional[str],
    req_id: str,
):
    """Transcribe audio with true token-by-token streaming."""
    logger.info(f"[REQ {req_id}] Starting streaming transcription")

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

    # Build transcription instruction
    instruction_parts = []

    if context and context.strip():
        instruction_parts.append(context)

    if language and language != "auto":
        instruction_parts.append(
            f"Transcribe the following audio in {language}. "
            "Output the transcription in the SAME language as spoken - do NOT translate."
        )
    else:
        instruction_parts.append(
            "Transcribe the following audio in its ORIGINAL language. "
            "Do NOT translate to English or any other language. "
            "Output the exact words spoken in the same language as the speaker."
        )

    if context and context.strip():
        instruction_parts.append(
            "IMPORTANT: If a word sounds similar to any term in the speech dictionary or context above, "
            "use the exact spelling from the dictionary. The audio may be unclear but those are the "
            "correct spellings for this context."
        )

    instruction_parts.append(
        "Use proper grammar and capitalization appropriate for the detected language "
        "(e.g., in English: capitalize 'I', first letter of sentences, proper nouns). "
        "Return ONLY the plain text transcription - no JSON, XML, or other formatting."
    )

    transcription_instruction = "\n\n".join(instruction_parts)

    # Convert audio to base64 for the chat template
    audio_base64 = _audio_array_to_base64(audio_array, ServiceConfig.AUDIO_SAMPLE_RATE)

    # Build conversation for Voxtral
    conversation = [
        {
            "role": "user",
            "content": [
                {"type": "audio", "base64": audio_base64},
                {"type": "text", "text": transcription_instruction},
            ],
        }
    ]

    logger.info(f"[REQ {req_id}] Applying chat template for streaming")
    inputs = model_manager.processor.apply_chat_template(conversation)

    # Create streamer for token-by-token output
    streamer = TextIteratorStreamer(
        model_manager.processor.tokenizer,
        skip_prompt=True,
        skip_special_tokens=True,
    )

    # Move inputs to device
    device_inputs = inputs.to(model_manager.device, dtype=ServiceConfig.TORCH_DTYPE)

    # Get generation config
    gen_config = ServiceConfig.get_generation_config("transcription")
    gen_config["streamer"] = streamer

    # Start generation in background thread
    def _generate():
        with torch.inference_mode():
            model_manager.model.generate(**device_inputs, **gen_config)

    generation_thread = Thread(target=_generate)
    generation_thread.start()

    # Yield tokens in batches to reduce overhead
    # Batching every 6 tokens balances SSE/JSON overhead with smooth progress display
    token_count = 0
    batch_size = 6
    token_buffer = []
    t0 = time.perf_counter()

    for text in streamer:
        if text:
            token_count += 1
            token_buffer.append(text)

            # Yield when we have enough tokens
            if len(token_buffer) >= batch_size:
                yield "".join(token_buffer)
                token_buffer = []

    # Yield any remaining tokens
    if token_buffer:
        yield "".join(token_buffer)

    generation_thread.join()
    t1 = time.perf_counter()
    logger.info(
        f"[REQ {req_id}] Streamed ~{token_count} tokens in {t1-t0:.2f}s "
        f"({token_count/(t1-t0) if t1 > t0 else 0:.1f} tok/s, batched every {batch_size})"
    )


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
    # Validate requested model matches configured model
    configured_model = ServiceConfig.MODEL_ID
    if request.model_name != configured_model:
        raise HTTPException(
            status_code=400,
            detail=f"Requested model '{request.model_name}' does not match "
            f"configured model '{configured_model}'. "
            f"Set VOXTRAL_MODEL_ID environment variable to change the model.",
        )

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
