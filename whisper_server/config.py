import os
from typing import List

class WhisperConfig:
    """Configuration for Whisper API Server"""
    
    # Server Configuration
    HOST = os.getenv("WHISPER_SERVER_HOST", "127.0.0.1")
    PORT = int(os.getenv("WHISPER_SERVER_PORT", "8084"))
    
    # Security Configuration
    MAX_AUDIO_FILE_SIZE_MB = int(os.getenv("MAX_AUDIO_FILE_SIZE_MB", "25"))
    MAX_AUDIO_FILE_SIZE_BYTES = MAX_AUDIO_FILE_SIZE_MB * 1024 * 1024
    
    # Rate Limiting
    RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "10"))
    RATE_LIMIT_WINDOW = os.getenv("RATE_LIMIT_WINDOW", "1 minute")
    
    # Supported Audio Formats
    SUPPORTED_AUDIO_FORMATS = {
        "mp3": "audio/mpeg",
        "mp4": "audio/mp4", 
        "m4a": "audio/mp4",
        "wav": "audio/wav",
        "flac": "audio/flac",
        "webm": "audio/webm",
        "ogg": "audio/ogg"
    }
    
    # Default Model
    DEFAULT_MODEL = "whisper-1"
    
    # CORS Configuration
    ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
    
    # Trusted Hosts Configuration
    ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "*").split(",")
    
    # Logging Configuration
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    
    @classmethod
    def validate_config(cls) -> List[str]:
        """Validate configuration and return list of errors"""
        errors = []
        
        if cls.MAX_AUDIO_FILE_SIZE_MB <= 0:
            errors.append("MAX_AUDIO_FILE_SIZE_MB must be positive")
            
        if cls.PORT <= 0 or cls.PORT > 65535:
            errors.append("PORT must be between 1 and 65535")
            
        return errors 