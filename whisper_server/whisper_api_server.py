import os
import base64
import tempfile
import logging
import time
import json
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel
from typing import Optional, Dict, Any
from pathlib import Path
import requests

# Import our modules
from config import WhisperConfig
from validators import (
    validate_base64_audio, 
    validate_model_name, 
    validate_audio_format,
    sanitize_filename,
    ValidationError,
    AudioValidationError,
    SecurityValidationError
)

# Configure logging
logging.basicConfig(
    level=getattr(logging, WhisperConfig.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Whisper API Server",
    description="OpenAI Whisper API proxy server",
    version="1.0.0"
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
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=WhisperConfig.ALLOWED_HOSTS
)

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

@app.post("/v1/audio/transcriptions")
async def transcribe(request: TranscribeRequest, client_request: Request):
    temp_file_path = None
    
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
            b'\xff\xfb': 'mp3',
            b'\xff\xf3': 'mp3',
            b'\xff\xf2': 'mp3',
            b'ID3': 'mp3',
            b'ftyp': 'mp4',
            b'moov': 'mp4',
            b'mdat': 'mp4',
            b'RIFF': 'wav',
            b'fLaC': 'flac',
            b'OggS': 'ogg',
            b'\x1a\x45\xdf\xa3': 'webm',
        }.items():
            if audio_bytes.startswith(signature):
                detected_format = format_name
                break
        
        # Check for ID3 tag at different positions (MP3)
        if not detected_format and b'ID3' in audio_bytes[:128]:
            detected_format = 'mp3'
        
        # Check for MP4 signatures at different positions
        if not detected_format and (b'ftyp' in audio_bytes[:32] or b'moov' in audio_bytes[:32]):
            detected_format = 'mp4'
        
        # Use detected format or default to mp3 (OpenAI can handle this)
        if detected_format == "mp4":
            file_extension = "m4a"
        else:
            file_extension = detected_format or "mp3"
        
        if not detected_format:
            logger.warning(f"Could not detect audio format, using default: {file_extension}")
        
        # Save to a temporary file with proper extension
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=f'.{file_extension}') as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name
        except Exception as e:
            logger.error(f"Failed to save temporary file: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to process audio file")

        # Transcribe using OpenAI API
        try:
            start_time = time.time()
            
            # Prepare the request to OpenAI
            url = f"{WhisperConfig.OPENAI_BASE_URL}/audio/transcriptions"
            headers = {
                "Authorization": f"Bearer {WhisperConfig.OPENAI_API_KEY}"
            }
            
            # Get MIME type for detected format
            mime_type = WhisperConfig.SUPPORTED_AUDIO_FORMATS.get(file_extension, "audio/mpeg")
            
            # Open and send the file
            with open(temp_file_path, "rb") as audio_file:
                files = {
                    "file": (f"audio.{file_extension}", audio_file, mime_type)
                }
                data = {
                    "model": request.model,
                    "response_format": "json"
                }
                
                logger.info(f"Transcribing with model {request.model}, format: {file_extension}")
                
                response = requests.post(url, headers=headers, files=files, data=data, timeout=60)
                response.raise_for_status()
                
                processing_time = time.time() - start_time
                result = response.json()
                
                logger.info(f"Transcription completed in {processing_time:.2f}s")
                
                return {
                    "text": result.get("text", ""),
                    "processing_time": processing_time,
                    "model": request.model,
                    "format": file_extension
                }

        except requests.exceptions.Timeout:
            logger.error("OpenAI API request timed out")
            raise HTTPException(status_code=504, detail="Transcription request timed out")
        except requests.exceptions.RequestException as e:
            logger.error(f"OpenAI API request failed: {str(e)}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"OpenAI API response: {e.response.status_code} - {e.response.text}")
                if e.response.status_code == 401:
                    raise HTTPException(status_code=401, detail="Invalid OpenAI API key")
                elif e.response.status_code == 429:
                    raise HTTPException(status_code=429, detail="OpenAI API rate limit exceeded")
                elif e.response.status_code >= 500:
                    raise HTTPException(status_code=503, detail="OpenAI API service unavailable")
            logger.error("OpenAI API error details: %s", str(e), exc_info=True)
            raise HTTPException(status_code=500, detail="OpenAI API service error")
        except Exception as e:
            logger.error(f"Unexpected error during transcription: {str(e)}")
            raise HTTPException(status_code=500, detail="Internal server error")

    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        # Clean up temporary file
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
            except Exception as e:
                logger.warning(f"Failed to delete temporary file: {str(e)}")

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
    """Debug endpoint to analyze audio data without transcribing"""
    try:
        audio_data = request.get_audio()
        audio_bytes = base64.b64decode(audio_data)
        
        # Analyze the audio data
        analysis = {
            "size_bytes": len(audio_bytes),
            "size_mb": len(audio_bytes) / 1024 / 1024,
            "first_16_bytes": audio_bytes[:16].hex(),
            "first_32_bytes": audio_bytes[:32].hex(),
            "contains_id3": b'ID3' in audio_bytes[:128],
            "contains_ftyp": b'ftyp' in audio_bytes[:32],
            "contains_moov": b'moov' in audio_bytes[:32],
            "contains_riff": b'RIFF' in audio_bytes[:16],
            "contains_flac": b'fLaC' in audio_bytes[:16],
            "contains_ogg": b'OggS' in audio_bytes[:16],
        }
        
        # Try to detect format
        detected_format = None
        for signature, format_name in {
            b'\xff\xfb': 'mp3',
            b'\xff\xf3': 'mp3',
            b'\xff\xf2': 'mp3',
            b'ID3': 'mp3',
            b'ftyp': 'mp4',
            b'moov': 'mp4',
            b'mdat': 'mp4',
            b'RIFF': 'wav',
            b'fLaC': 'flac',
            b'OggS': 'ogg',
            b'\x1a\x45\xdf\xa3': 'webm',
        }.items():
            if audio_bytes.startswith(signature):
                detected_format = format_name
                break
        
        analysis["detected_format"] = detected_format
        analysis["default_format"] = detected_format or "mp3"
        
        return analysis
        
    except Exception as e:
        logger.error("An error occurred in debug_audio_info: %s", str(e), exc_info=True)
        return {"error": "An internal error occurred. Please contact support."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host=WhisperConfig.HOST, 
        port=WhisperConfig.PORT,
        log_level=WhisperConfig.LOG_LEVEL.lower()
    ) 