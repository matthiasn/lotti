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
from typing import List, Optional, Dict
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
    if model_name not in valid_models:
        raise ValueError(f"Invalid model name. Must be one of: {', '.join(valid_models)}")
    return WhisperModel(model_name)

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
    audio: str
    model: str = "base"  # Default to base model
    language: str = "auto"

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
            audio_bytes = base64.b64decode(request.audio)
        except Exception as e:
            logger.error(f"Failed to decode base64 audio: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail="Invalid audio data: Could not decode base64 audio"
            )
        
        # Save to a temporary file
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.m4a') as temp_file:
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

@app.post("/transcribe/chat/completions")
async def transcribe_chat_completions(request: TranscribeRequest):
    return await transcribe(request)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 