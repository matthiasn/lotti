"""Pytest configuration and fixtures"""

import pytest
import asyncio
from pathlib import Path
from unittest.mock import Mock, AsyncMock
import tempfile
import shutil

from src.core.interfaces import (
    IConfigManager, IModelManager, IModelDownloader,
    IModelValidator, ITranscriptionService, IChatService, IAudioProcessor
)
from src.core.models import ModelInfo, DownloadProgress, ModelStatus
from src.services.config_manager import ConfigManager


@pytest.fixture
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def temp_dir():
    """Create a temporary directory for tests"""
    temp_dir = tempfile.mkdtemp()
    yield Path(temp_dir)
    shutil.rmtree(temp_dir)


@pytest.fixture
def mock_config_manager(temp_dir):
    """Mock configuration manager with secure temp directory"""
    mock = Mock(spec=IConfigManager)
    mock.get_model_id.return_value = "google/gemma-3n-E2B-it"
    mock.set_model_id.return_value = None
    mock.get_model_variant.return_value = "E2B"
    mock.set_model_variant.return_value = None
    mock.get_cache_dir.return_value = temp_dir / "test-cache"
    mock.get_huggingface_token.return_value = "test-token"
    mock.get_model_revision.return_value = "main"  # Add the new method
    mock.get_device.return_value = "cpu"
    mock.get_log_level.return_value = "INFO"
    mock.get_host.return_value = "localhost"
    mock.get_port.return_value = 8000
    mock.validate_config.return_value = None
    return mock


@pytest.fixture
def mock_model_manager():
    """Mock model manager"""
    mock = Mock(spec=IModelManager)
    mock.load_model = AsyncMock(return_value=True)
    mock.unload_model = AsyncMock()
    mock.is_model_available.return_value = True
    mock.is_model_loaded.return_value = False
    mock.get_model_info.return_value = ModelInfo(
        id="google/gemma-3n-E2B-it",
        name="Gemma 3n E2B",
        variant="E2B",
        is_available=True,
        is_loaded=False,
        device="cpu"
    )
    mock.refresh_config = Mock()
    return mock


@pytest.fixture
def mock_model_downloader():
    """Mock model downloader"""
    mock = Mock(spec=IModelDownloader)

    async def mock_download_generator(model_name: str, stream: bool = True):
        yield DownloadProgress(
            status=ModelStatus.CHECKING,
            message="Checking model...",
            progress=0.0
        )
        yield DownloadProgress(
            status=ModelStatus.DOWNLOADING,
            message="Downloading model...",
            progress=50.0
        )
        yield DownloadProgress(
            status=ModelStatus.COMPLETE,
            message="Download complete",
            progress=100.0
        )

    mock.download_model = mock_download_generator
    mock.is_model_downloaded.return_value = False
    return mock


@pytest.fixture
def mock_model_validator():
    """Mock model validator"""
    mock = Mock(spec=IModelValidator)
    mock.validate_model_request.return_value = True
    mock.ensure_model_available = AsyncMock()
    mock.get_available_models.return_value = ["google/gemma-3n-E2B-it", "google/gemma-3n-E4B-it"]
    return mock


@pytest.fixture
def mock_audio_processor():
    """Mock audio processor"""
    mock = Mock(spec=IAudioProcessor)
    mock.process_audio_base64 = AsyncMock(return_value=(
        [[1, 2, 3, 4, 5]],  # Mock audio array
        "Test audio prompt"  # Mock combined prompt
    ))
    return mock


@pytest.fixture
def mock_transcription_service():
    """Mock transcription service"""
    mock = Mock(spec=ITranscriptionService)
    from src.core.models import TranscriptionResult

    mock.transcribe_audio = AsyncMock(return_value=TranscriptionResult(
        text="Test transcription",
        model_used="gemma-3n-E2B-it",
        processing_time=1.5,
        audio_duration=5.0,
        request_id="test123"
    ))
    return mock


@pytest.fixture
def mock_chat_service():
    """Mock chat service"""
    mock = Mock(spec=IChatService)
    from src.core.models import ChatResponse

    mock.complete_chat = AsyncMock(return_value=ChatResponse(
        id="chatcmpl-test123",
        model="gemma-3n-E2B-it",
        choices=[{
            "index": 0,
            "message": {"role": "assistant", "content": "Test response"},
            "finish_reason": "stop"
        }],
        usage={"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30},
        created=1234567890
    ))

    async def mock_stream():
        yield "data: test streaming response\n\n"

    mock.complete_chat_stream = AsyncMock(return_value=mock_stream())
    return mock


@pytest.fixture
def real_config_manager(temp_dir):
    """Real configuration manager with temporary directory"""
    import os
    original_cache = os.environ.get('GEMMA_CACHE_DIR')
    os.environ['GEMMA_CACHE_DIR'] = str(temp_dir)

    config = ConfigManager()

    yield config

    # Cleanup
    if original_cache:
        os.environ['GEMMA_CACHE_DIR'] = original_cache
    else:
        os.environ.pop('GEMMA_CACHE_DIR', None)