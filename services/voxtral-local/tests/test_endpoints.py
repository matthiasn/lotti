"""Tests for API endpoints."""

import base64
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from main import app


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


class TestHealthEndpoint:
    """Tests for health check endpoint."""

    def test_health_returns_200(self, client):
        """Test health endpoint returns 200."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_status(self, client):
        """Test health endpoint returns status field."""
        response = client.get("/health")
        data = response.json()
        assert "status" in data
        assert data["status"] == "healthy"

    def test_health_returns_model_info(self, client):
        """Test health endpoint returns model availability info."""
        response = client.get("/health")
        data = response.json()
        assert "model_available" in data
        assert "model_loaded" in data
        assert "device" in data

    def test_health_returns_max_audio_minutes(self, client):
        """Test health endpoint returns max audio duration."""
        response = client.get("/health")
        data = response.json()
        assert "max_audio_minutes" in data
        assert data["max_audio_minutes"] == 30  # 1800 seconds / 60


class TestModelsEndpoint:
    """Tests for models listing endpoint."""

    def test_list_models_returns_200(self, client):
        """Test models endpoint returns 200."""
        response = client.get("/v1/models")
        assert response.status_code == 200

    def test_list_models_returns_list(self, client):
        """Test models endpoint returns list structure."""
        response = client.get("/v1/models")
        data = response.json()
        assert "object" in data
        assert data["object"] == "list"
        assert "data" in data
        assert isinstance(data["data"], list)


class TestChatCompletionsEndpoint:
    """Tests for chat completions endpoint."""

    def test_chat_completions_without_audio_returns_error(self, client):
        """Test chat completions returns error when no audio provided."""
        response = client.post(
            "/v1/chat/completions",
            json={
                "model": "voxtral-mini",
                "messages": [{"role": "user", "content": "Hello"}],
            },
        )
        # Returns 400 (no audio), 404 (model not downloaded), or 500 (model load failed)
        assert response.status_code in [400, 404, 500]


class TestModelPullEndpoint:
    """Tests for model pull endpoint."""

    def test_model_pull_returns_200(self, client):
        """Test model pull endpoint returns 200."""
        response = client.post(
            "/v1/models/pull",
            json={
                "model_name": "mistralai/Voxtral-Mini-3B-2507",
                "stream": False,
            },
        )
        assert response.status_code == 200

    def test_model_pull_returns_status(self, client):
        """Test model pull returns status field."""
        response = client.post(
            "/v1/models/pull",
            json={
                "model_name": "mistralai/Voxtral-Mini-3B-2507",
                "stream": False,
            },
        )
        data = response.json()
        assert "status" in data
        assert data["status"] == "success"


class TestModelLoadEndpoint:
    """Tests for model load endpoint."""

    def test_model_load_returns_response(self, client):
        """Test model load returns a response."""
        response = client.post("/v1/models/load")
        # Can be 200 (loaded/already loaded) or 404 (not downloaded) or 500 (load failed)
        assert response.status_code in [200, 404, 500]


class TestContextExtraction:
    """Tests for context extraction from messages."""

    def test_extracts_user_message_content(self):
        """Test context extraction from user messages."""
        messages = [
            {"role": "system", "content": "You are a transcription assistant."},
            {"role": "user", "content": "Dictionary: Flutter, Riverpod\n\nTranscribe this."},
        ]

        # Simulate context extraction logic from main.py
        context_parts = []
        for message in messages:
            role = message.get("role", "")
            content = message.get("content", "")
            if isinstance(content, str) and content.strip():
                if role == "system":
                    context_parts.append(f"Instructions: {content}")
                elif role == "user":
                    context_parts.append(content)

        context = "\n".join(context_parts)

        assert "Instructions:" in context
        assert "transcription assistant" in context
        assert "Dictionary: Flutter, Riverpod" in context

    def test_handles_empty_messages(self):
        """Test context extraction handles empty messages."""
        messages = []

        context_parts = []
        for message in messages:
            role = message.get("role", "")
            content = message.get("content", "")
            if isinstance(content, str) and content.strip():
                context_parts.append(content)

        context = "\n".join(context_parts) if context_parts else None

        assert context is None

    def test_extracts_speech_dictionary(self):
        """Test that speech dictionary content is preserved in context."""
        messages = [
            {
                "role": "user",
                "content": """IMPORTANT - SPEECH DICTIONARY (MUST USE):
Required spellings: ["macOS", "iPhone", "Flutter"]

Transcribe this audio.""",
            },
        ]

        context_parts = []
        for message in messages:
            role = message.get("role", "")
            content = message.get("content", "")
            if isinstance(content, str) and content.strip():
                if role == "user":
                    context_parts.append(content)

        context = "\n".join(context_parts)

        assert "SPEECH DICTIONARY" in context
        assert "macOS" in context
        assert "iPhone" in context
        assert "Flutter" in context
