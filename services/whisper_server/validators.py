import base64
import re
from typing import Tuple, Optional
from config import WhisperConfig


class ValidationError(Exception):
    """Custom exception for validation errors"""

    pass


class AudioValidationError(ValidationError):
    """Exception for audio validation errors"""

    pass


class SecurityValidationError(ValidationError):
    """Exception for security validation errors"""

    pass


def validate_base64_audio(audio_base64: str) -> Tuple[bool, Optional[str]]:
    """
    Validate base64 audio data

    Args:
        audio_base64: Base64 encoded audio data

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not audio_base64:
        return False, "Audio data is required"

    # Check if it's valid base64
    try:
        audio_bytes = base64.b64decode(audio_base64)
    except Exception:
        return False, "Invalid base64 encoding"

    # Check file size
    if len(audio_bytes) > WhisperConfig.MAX_AUDIO_FILE_SIZE_BYTES:
        max_size_mb = WhisperConfig.MAX_AUDIO_FILE_SIZE_MB
        return False, f"Audio file too large. Maximum size is {max_size_mb}MB"

    # Check minimum size (prevent empty files)
    if len(audio_bytes) < 1024:  # 1KB minimum
        return False, "Audio file too small. Minimum size is 1KB"

    return True, None


def validate_model_name(model: str) -> Tuple[bool, Optional[str]]:
    """
    Validate Whisper model name

    Args:
        model: Model name to validate

    Returns:
        Tuple of (is_valid, error_message)
    """
    if not model:
        return False, "Model name is required"

    # Only allow whisper-1 for now (can be expanded)
    allowed_models = ["whisper-1"]
    if model not in allowed_models:
        return False, f"Invalid model. Allowed models: {', '.join(allowed_models)}"

    return True, None


def sanitize_filename(filename: str) -> str:
    """
    Sanitize filename to prevent path traversal attacks

    Args:
        filename: Original filename

    Returns:
        Sanitized filename
    """
    # Remove any path separators and dangerous characters
    sanitized = re.sub(r'[<>:"/\\|?*]', "", filename)
    # Limit length
    if len(sanitized) > 100:
        sanitized = sanitized[:100]
    return sanitized


def detect_audio_format(audio_bytes: bytes) -> Optional[str]:
    """
    Detect audio format from file header

    Args:
        audio_bytes: Audio file bytes

    Returns:
        Detected format or None
    """
    if len(audio_bytes) < 4:
        return None

    # Check file signatures (magic bytes)
    signatures = {
        # MP3 signatures
        b"\xff\xfb": "mp3",  # MPEG-1 Layer 3
        b"\xff\xf3": "mp3",  # MPEG-1 Layer 3
        b"\xff\xf2": "mp3",  # MPEG-1 Layer 3
        b"ID3": "mp3",  # ID3 tag
        # MP4/M4A signatures
        b"ftyp": "mp4",  # MP4/M4A container
        b"moov": "mp4",  # MP4 container
        b"mdat": "mp4",  # MP4 container
        # WAV signature
        b"RIFF": "wav",  # WAV format
        # FLAC signature
        b"fLaC": "flac",  # FLAC format
        # OGG signature
        b"OggS": "ogg",  # OGG format
        # WebM signature
        b"\x1a\x45\xdf\xa3": "webm",  # WebM format
    }

    # Check for signatures at the beginning
    for signature, format_name in signatures.items():
        if audio_bytes.startswith(signature):
            return format_name

    # Check for ID3 tag at different positions (MP3)
    if b"ID3" in audio_bytes[:128]:
        return "mp3"

    # Check for MP4 signatures at different positions
    if b"ftyp" in audio_bytes[:32] or b"moov" in audio_bytes[:32]:
        return "mp4"

    # If we can't detect format, try to infer from file extension or default
    return None


def validate_audio_format(audio_bytes: bytes) -> Tuple[bool, Optional[str]]:
    """
    Validate audio format is supported

    Args:
        audio_bytes: Audio file bytes

    Returns:
        Tuple of (is_valid, error_message)
    """
    detected_format = detect_audio_format(audio_bytes)

    # If we can't detect format, assume it's a valid audio format and let OpenAI handle it
    if not detected_format:
        # Log a warning but don't fail - OpenAI can handle many formats
        import logging

        logger = logging.getLogger(__name__)
        logger.warning("Could not detect audio format from file headers, proceeding with default format")
        return True, None

    if detected_format not in WhisperConfig.SUPPORTED_AUDIO_FORMATS:
        supported = ", ".join(WhisperConfig.SUPPORTED_AUDIO_FORMATS.keys())
        return False, f"Unsupported audio format: {detected_format}. Supported: {supported}"

    return True, None
