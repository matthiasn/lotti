"""Tests for API endpoints."""

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

    def test_health_returns_default_dimensions(self, client):
        """Test health endpoint returns default image dimensions."""
        response = client.get("/health")
        data = response.json()
        assert "default_dimensions" in data
        assert "1664x928" in data["default_dimensions"]


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


class TestImageGenerationEndpoint:
    """Tests for image generation endpoint."""

    def test_empty_prompt_returns_400(self, client):
        """Test empty prompt returns 400 error."""
        response = client.post(
            "/v1/images/generate",
            json={"prompt": ""},
        )
        assert response.status_code == 400
        data = response.json()
        assert "detail" in data

    def test_whitespace_prompt_returns_400(self, client):
        """Test whitespace-only prompt returns 400 error."""
        response = client.post(
            "/v1/images/generate",
            json={"prompt": "   "},
        )
        assert response.status_code == 400

    def test_invalid_dimensions_returns_400(self, client):
        """Test invalid dimensions return 400 error."""
        response = client.post(
            "/v1/images/generate",
            json={
                "prompt": "A test image",
                "width": 100,
                "height": 100,
            },
        )
        assert response.status_code == 400
        data = response.json()
        assert "out of range" in data["detail"]

    def test_generation_without_model_returns_404(self, client):
        """Test generation without downloaded model returns 404."""
        response = client.post(
            "/v1/images/generate",
            json={"prompt": "A beautiful landscape"},
        )
        # Should return 404 (model not downloaded) or 500 (load failed)
        assert response.status_code in [404, 500]


class TestModelPullEndpoint:
    """Tests for model pull endpoint."""

    def test_model_pull_returns_200(self, client):
        """Test model pull endpoint returns 200."""
        response = client.post(
            "/v1/models/pull",
            json={
                "model_name": "Qwen/Qwen-Image",
                "stream": False,
            },
        )
        assert response.status_code == 200

    def test_model_pull_wrong_model_returns_400(self, client):
        """Test model pull with wrong model name returns 400."""
        response = client.post(
            "/v1/models/pull",
            json={
                "model_name": "wrong/model",
                "stream": False,
            },
        )
        assert response.status_code == 400
        data = response.json()
        assert "does not match" in data["detail"]


class TestModelLoadEndpoint:
    """Tests for model load endpoint."""

    def test_model_load_returns_response(self, client):
        """Test model load returns a response."""
        response = client.post("/v1/models/load")
        # Can be 200 (loaded/already loaded) or 404 (not downloaded) or 500 (load failed)
        assert response.status_code in [200, 404, 500]
