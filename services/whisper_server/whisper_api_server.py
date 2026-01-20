import os
import base64
import tempfile
import logging
import time
import json
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
from pathlib import Path
import torch
from transformers import pipeline, BitsAndBytesConfig
from functools import lru_cache
import librosa
import soundfile as sf
import numpy as np

# Import our modules
from config import WhisperConfig
from validators import (
    validate_base64_audio,
    validate_model_name,
    validate_audio_format,
    sanitize_filename,
    ValidationError,
    AudioValidationError,
    SecurityValidationError,
)

# Configure logging
logging.basicConfig(
    level=getattr(logging, WhisperConfig.LOG_LEVEL), format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Enable performance optimizations
torch.backends.cudnn.benchmark = True
torch.backends.cuda.matmul.allow_tf32 = True

app = FastAPI(
    title="Whisper API Server", description="Local Whisper API server with OpenAI-compatible interface", version="1.0.0"
)

# Validate configuration on startup
config_errors = WhisperConfig.validate_config()
if config_errors:
    logger.error("Configuration errors:")
    for error in config_errors:
        logger.error(f"  - {error}")
    raise RuntimeError("Invalid configuration")

# Add CORS middleware with secure configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=WhisperConfig.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Add trusted host middleware
app.add_middleware(TrustedHostMiddleware, allowed_hosts=WhisperConfig.ALLOWED_HOSTS)

# Supported local models mapping to OpenAI model names (optimized for speed)
SUPPORTED_MODELS = {
    "whisper-1": "openai/whisper-large-v3",  # Use large for similar accuracy as hosted version
    "whisper-tiny": "openai/whisper-tiny",
    "whisper-small": "openai/whisper-small",
    "whisper-medium": "openai/whisper-medium",
    "whisper-large": "openai/whisper-large-v3",
}


def get_optimal_device() -> str:
    """Determine the best device for Whisper inference."""
    if torch.backends.mps.is_available():
        logger.info("MPS (Metal Performance Shaders) is available - using GPU acceleration")
        return "mps"
    elif torch.cuda.is_available():
        logger.info("CUDA is available - using GPU acceleration")
        return "cuda:0"
    else:
        logger.info("No GPU acceleration available, falling back to CPU")
        return "cpu"


def get_optimal_batch_size(device: str) -> int:
    """Determine optimal batch size based on device (optimized for speed)."""
    if device == "mps":
        return 4  # Increased from 2 for better throughput
    elif device.startswith("cuda"):
        return 16  # Increased from 8 for better throughput
    else:
        return 2  # Increased from 1 for better throughput


def validate_model_name(model: str) -> tuple[bool, Optional[str]]:
    """
    Validate Whisper model name

    Args:
        model: Model name to validate

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not model:
        return False, "Model name is required"

    # Allow OpenAI model names and local model names
    allowed_models = list(SUPPORTED_MODELS.keys())
    if model not in allowed_models:
        return False, f"Invalid model. Allowed models: {', '.join(allowed_models)}"

    return True, None


def preprocess_audio(audio_path: str) -> str:
    """
    Preprocess audio for optimal Whisper performance.

    Args:
        audio_path: Path to the audio file

    Returns:
        Path to the preprocessed audio file
    """
    try:
        # Load audio with explicit format handling and suppress warnings
        import warnings

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            audio, sr = librosa.load(audio_path, sr=None, mono=True)

        # Resample to 16kHz (Whisper's optimal sample rate)
        if sr != 16000:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)

        # Normalize audio
        audio = librosa.util.normalize(audio)

        # Trim silence
        audio, _ = librosa.effects.trim(audio, top_db=20)

        # Save preprocessed audio as WAV (most compatible format)
        preprocessed_path = audio_path.replace(".", "_preprocessed.wav")
        sf.write(preprocessed_path, audio, 16000, format="WAV")

        return preprocessed_path
    except Exception as e:
        logger.warning(f"Audio preprocessing failed: {str(e)}, using original file")
        return audio_path


# Cache for loaded models to avoid reloading them for each request
@lru_cache(maxsize=4)
def get_model(model_name: str):
    """Get a Whisper model instance, loading it if necessary (optimized for speed)."""
    try:
        # Map OpenAI model name to local model
        local_model_name = SUPPORTED_MODELS.get(model_name, model_name)
        device = get_optimal_device()
        batch_size = get_optimal_batch_size(device)

        logger.info(f"Loading model {local_model_name} on {device} with batch size {batch_size}")

        # Configure quantization (only for CUDA, not MPS)
        quantization_config = None
        use_quantization = False
        try:
            if device.startswith("cuda"):
                # Use 8-bit quantization for CUDA GPU only
                quantization_config = BitsAndBytesConfig(
                    load_in_8bit=True,
                    llm_int8_threshold=6.0,
                    llm_int8_has_fp16_weight=False,
                )
                use_quantization = True
                logger.info("8-bit quantization enabled for CUDA GPU")
        except Exception as e:
            logger.warning(f"Quantization setup failed: {str(e)}, continuing without quantization")

        # Optimized model loading with quantization and flash attention
        if device == "cpu":
            pipe = pipeline(
                "automatic-speech-recognition",
                local_model_name,
                device=device,
                model_kwargs={
                    "use_cache": True,
                },
            )
        else:
            model_kwargs = {
                "use_cache": True,
                "torch_dtype": torch.float16,
            }

            # Add flash attention if available and compatible (CUDA only)
            if device.startswith("cuda"):
                try:
                    import flash_attn

                    model_kwargs["attn_implementation"] = "flash_attention_2"
                    logger.info("Flash attention 2 enabled for CUDA")
                except ImportError:
                    logger.info("Flash attention not available, using standard attention")
                except Exception as e:
                    logger.warning(f"Flash attention setup failed: {str(e)}, using standard attention")
            else:
                logger.info("Flash attention not available for MPS, using standard attention")

            # Create pipeline with or without quantization config
            if use_quantization and quantization_config is not None:
                pipe = pipeline(
                    "automatic-speech-recognition",
                    local_model_name,
                    device=device,
                    quantization_config=quantization_config,
                    model_kwargs=model_kwargs,
                )
            else:
                pipe = pipeline(
                    "automatic-speech-recognition", local_model_name, device=device, model_kwargs=model_kwargs
                )

        # Enable torch compile for additional speedup
        try:
            pipe.model = torch.compile(pipe.model, mode="reduce-overhead")
            logger.info("Torch compile enabled for model optimization")
        except Exception as e:
            logger.warning(f"Torch compile failed: {str(e)}, continuing without it")

        logger.info(f"Model {local_model_name} loaded successfully with optimizations")
        return pipe, batch_size

    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to initialize pipeline: {str(e)}")


class TranscribeRequest(BaseModel):
    audio: Optional[str] = None
    model: str = WhisperConfig.DEFAULT_MODEL
    language: Optional[str] = "auto"
    messages: Optional[list] = None
    audio_options: Optional[Dict[str, Any]] = None

    def get_audio(self) -> str:
        if self.audio:
            return self.audio
        if self.audio_options and "data" in self.audio_options:
            return self.audio_options["data"]
        if self.messages:
            for msg in self.messages:
                audio_data = self._extract_audio_from_message(msg)
                if audio_data:
                    return audio_data
        raise ValueError("No audio data found in request")

    def _extract_audio_from_message(self, msg: dict) -> str:
        content = msg.get("content")
        if isinstance(content, list):
            for part in content:
                if part.get("type") in ["audio", "input_audio"]:
                    if "inputAudio" in part and "data" in part["inputAudio"]:
                        return part["inputAudio"]["data"]
                    elif "data" in part:
                        return part["data"]
        elif isinstance(content, dict):
            if "data" in content:
                return content["data"]
            elif "format" in content and "data" in content:
                return content["data"]
        return None


@app.post("/v1/audio/transcriptions")
async def transcribe(request: TranscribeRequest, client_request: Request):
    temp_file_path = None
    preprocessed_path = None

    try:
        # Log request for monitoring
        client_ip = client_request.client.host if client_request.client else "unknown"
        logger.info(f"Transcription request from {client_ip} with model {request.model}")

        # Validate model
        is_valid_model, model_error = validate_model_name(request.model)
        if not is_valid_model:
            raise HTTPException(status_code=400, detail=model_error)

        # Get and validate audio data
        try:
            audio_data = request.get_audio()
        except ValueError as e:
            logger.error("Invalid audio data format: %s", str(e))
            raise HTTPException(status_code=400, detail="Invalid audio data format")

        # Validate base64 audio
        is_valid_audio, audio_error = validate_base64_audio(audio_data)
        if not is_valid_audio:
            raise HTTPException(status_code=400, detail=audio_error)

        # Decode audio
        try:
            audio_bytes = base64.b64decode(audio_data)
        except Exception as e:
            logger.error(f"Failed to decode base64 audio: {str(e)}")
            raise HTTPException(status_code=400, detail="Invalid audio data format")

        # Validate audio format
        is_valid_format, format_error = validate_audio_format(audio_bytes)
        if not is_valid_format:
            raise HTTPException(status_code=400, detail=format_error)

        # Detect format for file extension
        detected_format = None
        for signature, format_name in {
            b"\xff\xfb": "mp3",
            b"\xff\xf3": "mp3",
            b"\xff\xf2": "mp3",
            b"ID3": "mp3",
            b"ftyp": "mp4",
            b"moov": "mp4",
            b"mdat": "mp4",
            b"RIFF": "wav",
            b"fLaC": "flac",
            b"OggS": "ogg",
            b"\x1a\x45\xdf\xa3": "webm",
        }.items():
            if audio_bytes.startswith(signature):
                detected_format = format_name
                break

        # Check for ID3 tag at different positions (MP3)
        if not detected_format and b"ID3" in audio_bytes[:128]:
            detected_format = "mp3"

        # Check for MP4 signatures at different positions
        if not detected_format and (b"ftyp" in audio_bytes[:32] or b"moov" in audio_bytes[:32]):
            detected_format = "mp4"

        # Use detected format or default to mp3
        if detected_format == "mp4":
            file_extension = "m4a"
        else:
            file_extension = detected_format or "mp3"

        if not detected_format:
            logger.warning(f"Could not detect audio format, using default: {file_extension}")

        # Save to a temporary file with proper extension
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_extension}") as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name
        except Exception as e:
            logger.error(f"Failed to save temporary file: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to process audio file")

        # Preprocess audio for optimal performance
        try:
            preprocessed_path = preprocess_audio(temp_file_path)
        except Exception as e:
            logger.warning(f"Audio preprocessing failed: {str(e)}, using original file")
            preprocessed_path = temp_file_path

        # Transcribe using local Whisper model
        try:
            start_time = time.time()

            # Get the local model
            pipe, batch_size = get_model(request.model)

            # Set language if specified (not "auto")
            language = request.language if request.language != "auto" else None

            logger.info(f"Transcribing with model {request.model}, format: {file_extension}")

            # Perform transcription with optimized parameters
            result = pipe(
                preprocessed_path,
                batch_size=batch_size,
                return_timestamps=True,
                generate_kwargs={
                    "language": language,
                    "do_sample": False,  # Deterministic for speed
                    "num_beams": 1,  # Greedy decoding for speed
                },
            )

            processing_time = time.time() - start_time

            # Extract text from result
            if isinstance(result, dict):
                text = result.get("text", "")
            elif isinstance(result, list) and len(result) > 0:
                text = result[0].get("text", "")
            else:
                text = str(result)

            logger.info(f"Transcription completed in {processing_time:.2f}s")

            return {"text": text, "processing_time": processing_time, "model": request.model, "format": file_extension}

        except Exception as e:
            logger.error(f"Transcription failed: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        # Clean up temporary files
        for file_path in [temp_file_path, preprocessed_path]:
            if file_path and Path(file_path).exists() and file_path != temp_file_path:
                try:
                    Path(file_path).unlink()
                except Exception as e:
                    logger.warning(f"Failed to clean up temporary file {file_path}: {str(e)}")


@app.post("/v1/chat/completions")
async def chat_completions(request: TranscribeRequest, client_request: Request):
    """OpenAI-style compatibility endpoint that proxies to /v1/audio/transcriptions."""
    return await transcribe(request, client_request)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "whisper-api-server"}


@app.post("/debug/audio-info")
async def debug_audio_info(request: TranscribeRequest):
    """Debug endpoint to get information about audio data without transcribing."""
    try:
        audio_data = request.get_audio()
        audio_bytes = base64.b64decode(audio_data)

        return {
            "audio_size_bytes": len(audio_bytes),
            "audio_size_mb": len(audio_bytes) / (1024 * 1024),
            "base64_length": len(audio_data),
            "model": request.model,
            "language": request.language,
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=WhisperConfig.HOST, port=WhisperConfig.PORT, log_level=WhisperConfig.LOG_LEVEL.lower())
