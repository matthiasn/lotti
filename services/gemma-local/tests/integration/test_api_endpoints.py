"""Integration tests for API endpoints"""

import pytest
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient

from src.main_new import create_app
from typing import Any


@pytest.mark.integration
class TestAPIEndpoints:
    """Test API endpoints integration"""

    @pytest.fixture
    def client(self) -> Any:
        """Create test client"""
        app = create_app()
        return TestClient(app)

    @pytest.fixture
    def mock_container(self) -> Any:
        """Mock the container with all services"""
        with patch("src.api.routes.container") as mock_container_obj:
            # Mock all services
            mock_config = Mock()
            mock_model_manager = Mock()
            mock_chat_service = Mock()
            mock_downloader = Mock()
            mock_validator = Mock()

            mock_container_obj.get_model_manager.return_value = mock_model_manager
            mock_container_obj.get_chat_service.return_value = mock_chat_service
            mock_container_obj.get_model_downloader.return_value = mock_downloader
            mock_container_obj.get_model_validator.return_value = mock_validator
            mock_container_obj.get_config_manager.return_value = mock_config

            # Set default return values
            mock_model_manager.is_model_available.return_value = True
            mock_model_manager.is_model_loaded.return_value = False
            mock_model_manager.device = "cpu"

            yield mock_container_obj

    def test_health_endpoint(self, client, mock_container) -> None:
        """Test health check endpoint"""
        mock_model_manager = mock_container.get_model_manager.return_value
        mock_model_manager.is_model_available.return_value = True
        mock_model_manager.is_model_loaded.return_value = False
        mock_model_manager.device = "cpu"

        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["model_available"] is True
        assert data["model_loaded"] is False
        assert data["device"] == "cpu"

    def test_chat_completion_text_only(self, client, mock_container) -> None:
        """Test text-only chat completion"""
        from src.core.models import ChatResponse
        from unittest.mock import AsyncMock

        mock_chat_service = mock_container.get_chat_service.return_value
        mock_chat_service.complete_chat = AsyncMock(
            return_value=ChatResponse(
                id="chatcmpl-test123",
                model="gemma-3n-E2B-it",
                choices=[
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "Test response"},
                        "finish_reason": "stop",
                    }
                ],
                usage={"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15},
                created=1234567890,
            )
        )

        request_data = {
            "model": "gemma-3n-E2B-it",
            "messages": [{"role": "user", "content": "Hello"}],
            "temperature": 0.7,
            "max_tokens": 100,
        }

        response = client.post("/v1/chat/completions", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "chatcmpl-test123"
        assert data["model"] == "gemma-3n-E2B-it"
        assert len(data["choices"]) == 1
        assert data["choices"][0]["message"]["content"] == "Test response"

    def test_chat_completion_with_audio(self, client, mock_container) -> None:
        """Test chat completion with audio transcription"""
        from src.core.models import ChatResponse
        from unittest.mock import AsyncMock

        mock_chat_service = mock_container.get_chat_service.return_value
        mock_chat_service.complete_chat = AsyncMock(
            return_value=ChatResponse(
                id="chatcmpl-test123",
                model="gemma-3n-E2B-it",
                choices=[
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "Transcribed audio"},
                        "finish_reason": "stop",
                    }
                ],
                usage={"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30},
                created=1234567890,
            )
        )

        request_data = {
            "model": "gemma-3n-E2B-it",
            "messages": [{"role": "user", "content": "Transcribe this audio"}],
            "audio": "base64encodedaudiodata",
            "language": "en",
        }

        response = client.post("/v1/chat/completions", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["choices"][0]["message"]["content"] == "Transcribed audio"

    def test_chat_completion_streaming(self, client, mock_container) -> None:
        """Test streaming chat completion"""
        mock_chat_service = mock_container.get_chat_service.return_value

        async def mock_stream() -> Any:
            yield "data: chunk1\n\n"
            yield "data: chunk2\n\n"

        mock_chat_service.complete_chat_stream.return_value = mock_stream()

        request_data = {
            "model": "gemma-3n-E2B-it",
            "messages": [{"role": "user", "content": "Hello"}],
            "stream": True,
        }

        response = client.post("/v1/chat/completions", json=request_data)

        assert response.status_code == 200
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8"

    def test_chat_completion_model_not_found(self, client, mock_container) -> None:
        """Test chat completion with model not found"""
        from src.core.exceptions import ModelNotFoundError

        mock_chat_service = mock_container.get_chat_service.return_value
        mock_chat_service.complete_chat.side_effect = ModelNotFoundError("test-model")

        request_data = {
            "model": "nonexistent-model",
            "messages": [{"role": "user", "content": "Hello"}],
        }

        response = client.post("/v1/chat/completions", json=request_data)

        assert response.status_code == 404
        assert "Model 'test-model' not found" in response.json()["detail"]

    def test_model_pull_streaming(self, client, mock_container) -> None:
        """Test model download with streaming"""
        from src.core.models import DownloadProgress, ModelStatus

        mock_downloader = mock_container.get_model_downloader.return_value

        async def mock_download_stream(model_name, stream) -> Any:
            yield DownloadProgress(status=ModelStatus.DOWNLOADING, message="Downloading model...", progress=50.0)
            yield DownloadProgress(status=ModelStatus.COMPLETE, message="Download complete", progress=100.0)

        mock_downloader.download_model = mock_download_stream

        request_data = {"model_name": "gemma-3n-E4B-it", "stream": True}

        response = client.post("/v1/models/pull", json=request_data)

        assert response.status_code == 200
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8"

    def test_model_pull_non_streaming(self, client, mock_container) -> None:
        """Test model download without streaming"""
        from src.core.models import DownloadProgress, ModelStatus

        mock_downloader = mock_container.get_model_downloader.return_value

        async def mock_download_stream(model_name, stream) -> Any:
            yield DownloadProgress(status=ModelStatus.COMPLETE, message="Model downloaded successfully", progress=100.0)

        mock_downloader.download_model = mock_download_stream

        request_data = {"model_name": "gemma-3n-E4B-it", "stream": False}

        response = client.post("/v1/models/pull", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"

    def test_list_models(self, client, mock_container) -> None:
        """Test listing available models"""
        mock_model_manager = mock_container.get_model_manager.return_value
        mock_validator = mock_container.get_model_validator.return_value
        mock_config = mock_container.get_config_manager.return_value

        from src.core.models import ModelInfo

        mock_model_manager.is_model_available.return_value = True
        mock_model_manager.get_model_info.return_value = ModelInfo(
            id="google/gemma-3n-E2B-it",
            name="Gemma 3n E2B",
            variant="E2B",
            is_available=True,
            is_loaded=False,
        )
        mock_config.get_model_id.return_value = "google/gemma-3n-E2B-it"
        mock_validator.get_available_models.return_value = [
            "google/gemma-3n-E2B-it",
            "google/gemma-3n-E4B-it",
        ]

        response = client.get("/v1/models")

        assert response.status_code == 200
        data = response.json()
        assert data["object"] == "list"
        assert len(data["data"]) >= 1
        assert any(model["id"] == "google/gemma-3n-E2B-it" for model in data["data"])

    def test_load_model_success(self, client, mock_container) -> None:
        """Test successful model loading"""
        mock_model_manager = mock_container.get_model_manager.return_value
        from src.core.models import ModelInfo
        from unittest.mock import AsyncMock

        mock_model_manager.is_model_loaded.return_value = False
        mock_model_manager.is_model_available.return_value = True
        mock_model_manager.load_model = AsyncMock(return_value=True)
        mock_model_manager.get_model_info.return_value = ModelInfo(
            id="google/gemma-3n-E2B-it",
            name="Gemma 3n E2B",
            variant="E2B",
            is_available=True,
            is_loaded=True,
            device="cpu",
        )

        response = client.post("/v1/models/load")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "loaded"
        assert "cpu" in data["device"]

    def test_load_model_already_loaded(self, client, mock_container) -> None:
        """Test loading model when already loaded"""
        mock_model_manager = mock_container.get_model_manager.return_value
        from src.core.models import ModelInfo

        mock_model_manager.is_model_loaded.return_value = True
        mock_model_manager.get_model_info.return_value = ModelInfo(
            id="google/gemma-3n-E2B-it",
            name="Gemma 3n E2B",
            variant="E2B",
            is_available=True,
            is_loaded=True,
            device="cpu",
        )

        response = client.post("/v1/models/load")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "already_loaded"
