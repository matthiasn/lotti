"""Tests for Gemma Local Service."""

import pytest
import asyncio
import base64
import json
from unittest.mock import Mock, patch, MagicMock, AsyncMock
from fastapi.testclient import TestClient
import numpy as np

from main import app
from model_manager import GemmaModelManager, ModelStatus
from audio_processor import AudioProcessor
from config import ServiceConfig


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


@pytest.fixture
def mock_model_manager():
    """Create mock model manager."""
    manager = Mock(spec=GemmaModelManager)
    manager.is_model_available.return_value = True
    manager.is_model_loaded.return_value = True
    manager.device = "cpu"
    manager.model_id = "test-model"
    return manager


@pytest.fixture
def mock_audio_processor():
    """Create mock audio processor."""
    processor = Mock(spec=AudioProcessor)
    processor.sample_rate = 16000
    return processor


class TestHealthEndpoint:
    """Test health check endpoint."""
    
    def test_health_check(self, client, mock_model_manager):
        """Test basic health check."""
        with patch('main.model_manager', mock_model_manager):
            response = client.get("/health")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "healthy"
            assert "model_available" in data
            assert "model_loaded" in data
            assert "device" in data


class TestModelManagement:
    """Test model management endpoints."""
    
    def test_list_models(self, client, mock_model_manager):
        """Test listing available models."""
        mock_model_manager.get_model_info = AsyncMock(return_value={
            "model_id": "test-model",
            "device": "cpu",
            "is_available": True,
            "is_loaded": True,
            "supports_multimodal": False,
            "size_gb": 2.5
        })
        
        with patch('main.model_manager', mock_model_manager):
            response = client.get("/v1/models")
            assert response.status_code == 200
            data = response.json()
            assert data["object"] == "list"
            assert len(data["data"]) == 1
            assert data["data"][0]["id"] == "test-model"
    
    @pytest.mark.asyncio
    async def test_model_pull_streaming(self, client, mock_model_manager):
        """Test model download with streaming progress."""
        async def mock_download():
            yield {"status": "downloading", "progress": 50, "total": 100, "completed": 50}
            yield {"status": "complete", "progress": 100, "total": 100, "completed": 100}
        
        mock_model_manager.download_model = Mock(return_value=mock_download())
        
        with patch('main.model_manager', mock_model_manager):
            response = client.post(
                "/v1/models/pull",
                json={"model_name": "test-model", "stream": True}
            )
            assert response.status_code == 200
            # Check that response is SSE format
            assert response.headers["content-type"] == "text/event-stream; charset=utf-8"
    
    def test_model_load(self, client, mock_model_manager):
        """Test model loading."""
        mock_model_manager.load_model = AsyncMock(return_value=True)
        
        with patch('main.model_manager', mock_model_manager):
            response = client.post("/v1/models/load")
            assert response.status_code == 200
            data = response.json()
            assert "message" in data


class TestTranscriptionEndpoint:
    """Test audio transcription endpoint."""
    
    def test_transcription_missing_audio(self, client):
        """Test transcription without audio input."""
        response = client.post(
            "/v1/audio/transcriptions",
            data={"model": "test-model"}
        )
        assert response.status_code == 400
        assert "Either 'file' or 'audio' must be provided" in response.json()["detail"]
    
    @pytest.mark.asyncio
    async def test_transcription_with_base64_audio(self, client, mock_model_manager, mock_audio_processor):
        """Test transcription with base64 audio."""
        # Create mock audio data
        audio_data = np.random.randn(16000).astype(np.float32)  # 1 second of audio
        audio_bytes = audio_data.tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        # Mock audio processing
        mock_audio_processor.process_audio_base64 = AsyncMock(
            return_value=(audio_data, "Transcribe this audio")
        )
        
        # Mock transcription generation
        with patch('main.model_manager', mock_model_manager), \
             patch('main.audio_processor', mock_audio_processor), \
             patch('main.generate_transcription', AsyncMock(return_value="Test transcription")):
            
            response = client.post(
                "/v1/audio/transcriptions",
                data={
                    "audio": audio_base64,
                    "model": "test-model",
                    "response_format": "json"
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["text"] == "Test transcription"
    
    def test_transcription_model_not_available(self, client, mock_model_manager):
        """Test transcription when model is not available."""
        mock_model_manager.is_model_loaded.return_value = False
        mock_model_manager.is_model_available.return_value = False
        
        with patch('main.model_manager', mock_model_manager):
            response = client.post(
                "/v1/audio/transcriptions",
                data={
                    "audio": "test",
                    "model": "test-model"
                }
            )
            assert response.status_code == 404
            assert "Model not downloaded" in response.json()["detail"]


class TestChatCompletionEndpoint:
    """Test chat completion endpoint."""
    
    def test_chat_completion_basic(self, client, mock_model_manager):
        """Test basic chat completion."""
        with patch('main.model_manager', mock_model_manager), \
             patch('main.generate_text', AsyncMock(return_value="Hello! How can I help you?")):
            
            response = client.post(
                "/v1/chat/completions",
                json={
                    "model": "test-model",
                    "messages": [
                        {"role": "user", "content": "Hello"}
                    ],
                    "temperature": 0.7,
                    "stream": False
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["object"] == "chat.completion"
            assert len(data["choices"]) == 1
            assert data["choices"][0]["message"]["content"] == "Hello! How can I help you?"
    
    def test_chat_completion_with_system_message(self, client, mock_model_manager):
        """Test chat completion with system message."""
        with patch('main.model_manager', mock_model_manager), \
             patch('main.generate_text', AsyncMock(return_value="Response")):
            
            response = client.post(
                "/v1/chat/completions",
                json={
                    "model": "test-model",
                    "messages": [
                        {"role": "system", "content": "You are a helpful assistant"},
                        {"role": "user", "content": "Hello"}
                    ],
                    "temperature": 0.7,
                    "stream": False
                }
            )
            assert response.status_code == 200
            data = response.json()
            assert data["choices"][0]["message"]["content"] == "Response"


class TestAudioProcessor:
    """Test audio processing functionality."""
    
    @pytest.mark.asyncio
    async def test_process_audio_base64(self):
        """Test processing base64 audio."""
        processor = AudioProcessor()
        
        # Create test audio
        audio_data = np.random.randn(16000).astype(np.float32)
        audio_bytes = audio_data.tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        # Mock soundfile read
        with patch('audio_processor.sf.read') as mock_read:
            mock_read.return_value = (audio_data, 16000)
            
            result_audio, result_prompt = await processor.process_audio_base64(
                audio_base64,
                "Test context"
            )
            
            assert result_audio is not None
            assert "Test context" in result_prompt
            assert "<audio>" in result_prompt
    
    def test_normalize_audio(self):
        """Test audio normalization."""
        processor = AudioProcessor()
        
        # Create test audio with known range
        audio = np.array([0.5, 1.0, -0.5, -1.0, 0.0])
        normalized = processor._normalize_audio(audio)
        
        # Check that audio is normalized to [-0.95, 0.95]
        assert np.max(np.abs(normalized)) <= 0.95
        assert np.mean(normalized) < 0.01  # Near zero mean
    
    def test_chunk_audio(self):
        """Test audio chunking."""
        processor = AudioProcessor()
        
        # Create 3 seconds of audio
        audio = np.random.randn(processor.sample_rate * 3)
        
        # Chunk into 2-second chunks with 0.5 second overlap
        chunks = processor.chunk_audio(audio, chunk_duration=2.0, overlap=0.5)
        
        assert len(chunks) == 2  # Should have 2 chunks
        assert len(chunks[0]) == processor.sample_rate * 2  # First chunk is 2 seconds
        assert len(chunks[1]) == processor.sample_rate * 2  # Second chunk is padded to 2 seconds


class TestModelManager:
    """Test model management functionality."""
    
    @pytest.mark.asyncio
    async def test_model_info(self):
        """Test getting model information."""
        manager = GemmaModelManager()
        info = await manager.get_model_info()
        
        assert "model_id" in info
        assert "device" in info
        assert "is_available" in info
        assert "is_loaded" in info
    
    def test_is_model_cached(self):
        """Test checking if model is cached."""
        with patch('config.ServiceConfig.is_model_cached', return_value=True):
            manager = GemmaModelManager()
            assert manager.is_model_available()
    
    @pytest.mark.asyncio
    async def test_download_already_cached(self):
        """Test download when model is already cached."""
        with patch('config.ServiceConfig.is_model_cached', return_value=True):
            manager = GemmaModelManager()
            
            progress_updates = []
            async for progress in manager.download_model():
                progress_updates.append(progress)
            
            assert len(progress_updates) > 0
            assert progress_updates[-1]["progress"] == 100
            assert "already downloaded" in progress_updates[-1]["status"].lower()


class TestStreamingResponses:
    """Test streaming response generation."""
    
    def test_build_chat_prompt(self):
        """Test building chat prompt from messages."""
        from main import build_chat_prompt
        
        messages = [
            {"role": "system", "content": "Be helpful"},
            {"role": "user", "content": "Hello"},
            {"role": "assistant", "content": "Hi there"},
            {"role": "user", "content": "How are you?"}
        ]
        
        prompt = build_chat_prompt(messages)
        
        assert "System: Be helpful" in prompt
        assert "User: Hello" in prompt
        assert "Assistant: Hi there" in prompt
        assert "User: How are you?" in prompt
        assert prompt.endswith("Assistant:")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])