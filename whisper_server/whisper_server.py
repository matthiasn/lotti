import os
import sys
import json
import base64
import tempfile
import logging
import time
import requests
from typing import Optional, Dict, Any
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenAI API configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")

def transcribe_audio_file(file_path: str, model: str = "whisper-1") -> Dict[str, Any]:
    """
    Transcribe an audio file using OpenAI's Whisper API.
    
    Args:
        file_path: Path to the audio file
        model: Whisper model to use (default: whisper-1)
        
    Returns:
        Dict containing transcription results
    """
    if not OPENAI_API_KEY:
        raise ValueError("OPENAI_API_KEY environment variable is required")
    
    # Validate file exists
    if not Path(file_path).exists():
        raise FileNotFoundError(f"Audio file not found: {file_path}")
    
    # Prepare the request
    url = f"{OPENAI_BASE_URL}/audio/transcriptions"
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}"
    }
    
    # Open and send the file
    with open(file_path, "rb") as audio_file:
        files = {
            "file": audio_file
        }
        data = {
            "model": model,
            "response_format": "json"
        }
        
        logger.info(f"Transcribing {file_path} with model {model}")
        start_time = time.time()
        
        try:
            response = requests.post(url, headers=headers, files=files, data=data)
            response.raise_for_status()
            
            processing_time = time.time() - start_time
            result = response.json()
            
            logger.info(f"Transcription completed in {processing_time:.2f}s")
            
            return {
                "text": result.get("text", ""),
                "processing_time": processing_time,
                "model": model,
                "file": file_path
            }
            
        except requests.exceptions.RequestException as e:
            logger.error(f"API request failed: {str(e)}")
            raise Exception(f"Transcription failed: {str(e)}")

def main():
    """Command line interface for testing."""
    if len(sys.argv) < 2:
        print("Usage: python whisper_server.py <audio_file_path> [model]")
        print("Example: python whisper_server.py test.mp3 whisper-1")
        sys.exit(1)
    
    file_path = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else "whisper-1"
    
    try:
        result = transcribe_audio_file(file_path, model)
        print(json.dumps(result, indent=2))
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main() 