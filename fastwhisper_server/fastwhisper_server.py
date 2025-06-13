import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ValidationError
from faster_whisper import WhisperModel
import uvicorn
import base64
import json
import tempfile
import logging
from typing import List, Optional, Dict, Any
from functools import lru_cache

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Get allowed origins from environment variable or use default for development
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://localhost:8000"  # Default for development
).split(",")

# Add CORS middleware with secure configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Only allow specific origins
    allow_credentials=True,
    allow_methods=["POST"],  # Only allow POST method since that's all we need
    allow_headers=["Content-Type", "Authorization"],  # Only allow necessary headers
)

# Cache for loaded models to avoid reloading them for each request
@lru_cache(maxsize=4)  # Cache up to 4 different models
def get_model(model_name: str) -> WhisperModel:
    """
    Get a Whisper model instance, loading it if necessary.
    Uses LRU cache to avoid reloading models for each request.
    """
    valid_models = ["tiny", "base", "small", "medium", "large-v1", "large-v2", "large-v3"]
    # Extract base model name if it's a full model ID (e.g., 'small.en' -> 'small')
    base_model = model_name.split('.')[0] if '.' in model_name else model_name
    if base_model not in valid_models:
        raise ValueError(f"Invalid model name. Must be one of: {', '.join(valid_models)}")
    return WhisperModel(base_model)

class TranscriptionSegment:
    def __init__(self, id: int, start: float, end: float, text: str):
        self.id = id
        self.start = start
        self.end = end
        self.text = text

    def to_dict(self):
        return {
            "id": self.id,
            "start": self.start,
            "end": self.end,
            "text": self.text
        }

class TranscribeRequest(BaseModel):
    audio: Optional[str] = None
    model: str = "base"  # Default to base model
    language: str = "auto"
    messages: Optional[List[Dict[str, Any]]] = None
    audio_options: Optional[Dict[str, Any]] = None

    def get_audio(self) -> str:
        # First check if audio is directly provided
        if self.audio:
            return self.audio

        # Check if audio is in audio_options
        if self.audio_options and "data" in self.audio_options:
            return self.audio_options["data"]

        # Check messages array
        if self.messages:
            logger.info("Processing messages array")
            for msg in self.messages:
                audio_data = self._extract_audio_from_message(msg)
                if audio_data:
                    return audio_data

        logger.error("No audio data found in request structure")
        raise ValueError("No audio data found in request")

    def _extract_audio_from_message(self, msg: dict) -> str:
        content = msg.get('content')
        logger.info(f"Message content type: {type(content)}")

        if isinstance(content, list):
            logger.info("Content is a list, checking parts")
            for part in content:
                logger.info(f"Part type: {part.get('type')}")
                logger.info(f"Part content: {json.dumps(part, indent=2)}")
                if part.get("type") in ["audio", "input_audio"]:
                    if "inputAudio" in part and "data" in part["inputAudio"]:
                        logger.info("Found audio in inputAudio.data")
                        return part["inputAudio"]["data"]
                    elif "data" in part:
                        logger.info("Found audio in part.data")
                        return part["data"]
        elif isinstance(content, dict):
            logger.info("Content is a dict, checking for data")
            if "data" in content:
                logger.info("Found audio in content.data")
                return content["data"]
            elif "format" in content and "data" in content:
                logger.info("Found audio in content with format")
                return content["data"]
        return None

@app.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    temp_file_path = None
    try:
        # Get the appropriate model
        try:
            model = get_model(request.model)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))

        # Decode base64 audio
        try:
            audio_bytes = base64.b64decode(request.get_audio())
        except Exception as e:
            logger.error(f"Failed to decode base64 audio: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail="Invalid audio data: Could not decode base64 audio"
            )
        
        # Save to a temporary file
        try:
            audio_format = audio_bytes.get('format', 'm4a')
            with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{audio_format}') as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name
        except Exception as e:
            logger.error(f"Failed to create temporary file: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Server error: Could not process audio file"
            )

        # Transcribe
        try:
            segments, info = model.transcribe(
                temp_file_path,
                language=request.language if request.language != "auto" else None,
                beam_size=5
            )
        except Exception as e:
            logger.error(f"Transcription failed: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Transcription failed: {str(e)}"
            )
        
        # Convert segments to list of dictionaries
        try:
            segments_list = []
            for i, segment in enumerate(segments):
                segments_list.append(
                    TranscriptionSegment(
                        id=i,
                        start=segment.start,
                        end=segment.end,
                        text=segment.text
                    ).to_dict()
                )
        except Exception as e:
            logger.error(f"Failed to process transcription segments: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail="Server error: Could not process transcription results"
            )
        
        # Prepare response
        response = {
            "text": " ".join([seg["text"] for seg in segments_list]),
            "language": info.language,
            "segments": segments_list,
            "model_used": request.model
        }
        return response
        
    except HTTPException:
        # Re-raise HTTP exceptions as they're already properly formatted
        raise
    except ValidationError as e:
        # Handle Pydantic validation errors
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid request data: {str(e)}"
        )
    except Exception as e:
        # Log unexpected errors with full details
        logger.exception("Unexpected error during transcription")
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred. Please try again later."
        )
        
    finally:
        # Always clean up the temporary file
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
            except Exception as e:
                # Log cleanup errors but don't raise them
                logger.error(f"Error cleaning up temporary file {temp_file_path}: {str(e)}")

@app.post("/chat/completions")
async def chat_completions(request: TranscribeRequest):
    """OpenAI-style compatibility endpoint that proxies to /transcribe."""
    return await transcribe(request)

# Added for compatibility with openai_dart package which automatically prepends /v1
@app.post("/v1/chat/completions")
async def chat_completions_v1(request: TranscribeRequest):
    """OpenAI-style compatibility endpoint with /v1 prefix that proxies to /transcribe."""
    return await transcribe(request)

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8083) 