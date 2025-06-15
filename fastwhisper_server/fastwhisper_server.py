import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, ValidationError
import uvicorn
import base64
import json
import tempfile
import logging
import time
import torch
import asyncio
from typing import List, Optional, Dict, Any, AsyncGenerator, Tuple
from functools import lru_cache
from transformers import pipeline
from transformers.pipelines.base import Pipeline

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Get allowed origins from environment variable or use default
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")

# Add CORS middleware with secure configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# Supported models
SUPPORTED_MODELS = {
    'small': 'openai/whisper-small',
    'medium': 'openai/whisper-medium',
    'large': 'openai/whisper-large-v3'
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
    """Determine optimal batch size based on device."""
    if device == "mps":
        return 2  # Conservative for Mac MPS backend
    elif device.startswith("cuda"):
        return 8  # Higher batch size for CUDA
    else:
        return 1  # CPU processing

def validate_model_name(model_name: str) -> str:
    """Validate and resolve model name to full HuggingFace identifier."""
    if model_name in SUPPORTED_MODELS:
        return SUPPORTED_MODELS[model_name]
    elif model_name in SUPPORTED_MODELS.values():
        return model_name
    else:
        supported_list = ', '.join(SUPPORTED_MODELS.keys())
        raise ValueError(f"Unsupported model '{model_name}'. Supported models: {supported_list}")

# Cache for loaded models to avoid reloading them for each request
@lru_cache(maxsize=4)
def get_model(model_name: str) -> Tuple[Pipeline, int]:
    """Get a Whisper model instance, loading it if necessary.
    
    Args:
        model_name: The name of the model to load
        
    Returns:
        Tuple containing:
            - Pipeline: The loaded Whisper pipeline
            - int: The optimal batch size for the current device
    """
    try:
        # Validate model name first, before any other operations
        full_model_name = validate_model_name(model_name)
        device = get_optimal_device()
        batch_size = get_optimal_batch_size(device)
        
        logger.info(f"Loading model {full_model_name} on {device} with batch size {batch_size}")
        
        if device == "cpu":
            pipe = pipeline(
                "automatic-speech-recognition",
                full_model_name,
                device=device,
                model_kwargs={"use_cache": True}
            )
        else:
            pipe = pipeline(
                "automatic-speech-recognition",
                full_model_name,
                torch_dtype=torch.float16,
                device=device,
                model_kwargs={"use_cache": True}
            )
            
        logger.info(f"Model {full_model_name} loaded successfully")
        return pipe, batch_size
        
    except ValueError as e:
        # Handle invalid model name separately
        logger.error(f"Invalid model name: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        # Only attempt fallback if we have a valid model name
        if 'full_model_name' in locals():
            try:
                logger.info(f"Falling back to CPU for model {full_model_name}...")
                pipe = pipeline(
                    "automatic-speech-recognition",
                    full_model_name,
                    device="cpu",
                    model_kwargs={"use_cache": True}
                )
                return pipe, 1
            except Exception as fallback_e:
                logger.error(f"Fallback also failed: {str(fallback_e)}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to initialize pipeline: {str(fallback_e)}"
                )
        else:
            # If we don't have a valid model name, raise the original error
            logger.error(f"Failed to load model: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to initialize pipeline: {str(e)}"
            )

class TranscribeRequest(BaseModel):
    audio: Optional[str] = None
    model: str = "base"
    language: Optional[str] = "auto"
    messages: Optional[List[Dict[str, Any]]] = None
    audio_options: Optional[Dict[str, Any]] = None
    stream: Optional[bool] = False
    num_beams: Optional[int] = 1  # Default to greedy decoding (1 beam)
    temperature: Optional[float] = 0.0  # Default to deterministic output

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
        content = msg.get('content')
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

async def stream_transcription(pipe, temp_file_path: str, batch_size: int, language: Optional[str] = None, num_beams: int = 1, temperature: float = 0.0) -> AsyncGenerator[str, None]:
    """Stream transcription results as they become available."""
    try:
        # Process in chunks and yield results
        for chunk in pipe(
            temp_file_path,
            chunk_length_s=30,
            batch_size=batch_size,
            return_timestamps=True,
            generate_kwargs={
                "temperature": temperature,
                "do_sample": temperature > 0.0,  # Only sample if temperature > 0
                "num_beams": num_beams,
                "language": language if language != "auto" else None,
            },
            stream=True
        ):
            if isinstance(chunk, dict):
                yield json.dumps({
                    "text": chunk.get('text', ''),
                    "timestamp": chunk.get('timestamp', [None, None]),
                    "is_final": chunk.get('is_final', False)
                }) + "\n"
            await asyncio.sleep(0.1)  # Small delay to prevent overwhelming the client
    except Exception as e:
        logger.error(f"Streaming transcription failed: {str(e)}")
        yield f"data: {json.dumps({'error': 'An internal error occurred during transcription.'})}\n\n"

@app.post("/transcribe")
async def transcribe(
    request: TranscribeRequest,
    stream: bool = Query(False, description="Enable streaming response. If both query parameter and request body stream are provided, query parameter takes precedence.")
):
    temp_file_path = None
    try:
        # Get the appropriate model
        try:
            pipe, batch_size = get_model(request.model)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

        # Get audio data
        try:
            audio_data = request.get_audio()
            audio_bytes = base64.b64decode(audio_data)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            logger.error(f"Failed to decode audio data: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail="Invalid audio data format"
            )
        
        # Save to a temporary file
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.tmp') as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name
        except Exception as e:
            logger.error(f"Failed to save temporary file: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Failed to process audio file"
            )

        # Handle streaming response - query parameter takes precedence over request body
        should_stream = stream or (not stream and request.stream)
        if should_stream:
            return StreamingResponse(
                stream_transcription(
                    pipe,
                    temp_file_path,
                    batch_size,
                    request.language,
                    request.num_beams,
                    request.temperature
                ),
                media_type="text/event-stream"
            )

        # Handle regular response
        try:
            start_time = time.time()
            outputs = pipe(
                temp_file_path,
                chunk_length_s=30,
                batch_size=batch_size,
                return_timestamps=True,
                generate_kwargs={
                    "temperature": request.temperature,
                    "do_sample": request.temperature > 0.0,  # Only sample if temperature > 0
                    "num_beams": request.num_beams,
                    "language": request.language if request.language != "auto" else None,
                }
            )

            # Process outputs
            if isinstance(outputs, dict):
                text = outputs.get('text', '')
                chunks = outputs.get('chunks', [])
                timestamps = [
                    {
                        'start': chunk.get('timestamp')[0] if chunk.get('timestamp') and len(chunk.get('timestamp')) >= 1 else None,
                        'end': chunk.get('timestamp')[1] if chunk.get('timestamp') and len(chunk.get('timestamp')) >= 2 else None,
                        'text': chunk.get('text', '')
                    }
                    for chunk in chunks
                ]
                processing_time = time.time() - start_time
                logger.info(f"Transcription completed in {processing_time:.2f}s")

            else:
                text = str(outputs)
                timestamps = []

            return {
                "text": text,
                "timestamps": timestamps,
                "processing_time": processing_time
            }

        except Exception as e:
            logger.error(f"Transcription failed: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Transcription failed: {str(e)}"
            )

    finally:
        # Clean up temporary file
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
            except Exception as e:
                logger.warning(f"Failed to delete temporary file: {str(e)}")

@app.post("/chat/completions")
async def chat_completions(request: TranscribeRequest):
    """OpenAI-style compatibility endpoint that proxies to /transcribe."""
    return await transcribe(request)

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8083) 