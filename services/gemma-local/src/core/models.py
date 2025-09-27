"""Core domain models for the Gemma service"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional, List, Dict, Any
from pathlib import Path
import numpy as np


class ModelStatus(Enum):
    """Model status enumeration"""

    IDLE = "idle"
    CHECKING = "checking"
    PREPARING = "preparing"
    DOWNLOADING = "downloading"
    LOADING = "loading"
    LOADED = "loaded"
    ERROR = "error"
    COMPLETE = "complete"


class InferenceStatus(Enum):
    """Inference status enumeration"""

    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class ModelInfo:
    """Model information"""

    id: str
    name: str
    variant: str
    size_gb: Optional[float] = None
    is_available: bool = False
    is_loaded: bool = False
    device: Optional[str] = None
    path: Optional[Path] = None


@dataclass
class DownloadProgress:
    """Model download progress"""

    status: ModelStatus
    message: str
    progress: float = 0.0
    total_size: int = 0
    downloaded_size: int = 0
    error: Optional[str] = None


@dataclass
class AudioRequest:
    """Audio transcription request"""

    audio_data: str  # base64 encoded
    model: str
    language: Optional[str] = None
    context_prompt: Optional[str] = None
    temperature: float = 0.7
    max_tokens: Optional[int] = None


@dataclass
class TranscriptionResult:
    """Transcription result"""

    text: str
    model_used: str
    processing_time: float
    audio_duration: Optional[float] = None
    request_id: Optional[str] = None


@dataclass
class ChatRequest:
    """Chat completion request"""

    model: str
    messages: List[Dict[str, Any]]
    temperature: float = 0.7
    max_tokens: Optional[int] = 2000
    top_p: float = 0.95
    stream: bool = False
    audio: Optional[str] = None
    language: Optional[str] = None


@dataclass
class ChatResponse:
    """Chat completion response"""

    id: str
    model: str
    choices: List[Dict[str, Any]]
    usage: Dict[str, int]
    created: int
    system_fingerprint: Optional[str] = None
