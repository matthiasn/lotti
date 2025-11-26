"""Integration tests for API endpoints"""

import os
import pytest
from httpx import AsyncClient, ASGITransport

from src.main import app


class TestHealthEndpoint:
    """Test cases for health check endpoint"""

    @pytest.mark.asyncio
    async def test_health_check(self):
        """Test health check endpoint"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")

        assert response.status_code == 200
        assert response.json() == {"status": "healthy"}


class TestChatCompletionsEndpoint:
    """Test cases for chat completions endpoint"""

    @pytest.mark.asyncio
    @pytest.mark.skipif(not os.getenv("GEMINI_API_KEY"), reason="GEMINI_API_KEY not set - skipping integration test")
    async def test_chat_completions_basic(self):
        """Test basic chat completion (requires GEMINI_API_KEY)"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/v1/chat/completions",
                json={
                    "model": "gemini-pro",
                    "messages": [{"role": "user", "content": "Say 'Hello, World!' and nothing else."}],
                    "temperature": 0.1,
                    "user_id": "test@example.com",
                },
            )

        assert response.status_code == 200
        data = response.json()

        # Validate response structure
        assert "id" in data
        assert data["object"] == "chat.completion"
        assert "created" in data
        assert data["model"] == "gemini-pro"
        assert "choices" in data
        assert len(data["choices"]) == 1
        assert data["choices"][0]["message"]["role"] == "assistant"
        assert "content" in data["choices"][0]["message"]
        assert "usage" in data
        assert data["usage"]["total_tokens"] > 0

    @pytest.mark.asyncio
    async def test_chat_completions_empty_messages(self):
        """Test chat completion with empty messages"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/v1/chat/completions",
                json={
                    "model": "gemini-pro",
                    "messages": [],
                },
            )

        assert response.status_code == 400

    @pytest.mark.asyncio
    @pytest.mark.skipif(not os.getenv("GEMINI_API_KEY"), reason="GEMINI_API_KEY not set - skipping integration test")
    async def test_chat_completions_model_mapping(self):
        """Test that OpenAI model names are mapped to Gemini models"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/v1/chat/completions",
                json={
                    "model": "gpt-4",  # Should map to gemini-1.5-pro
                    "messages": [{"role": "user", "content": "Say 'test' and nothing else."}],
                    "temperature": 0.1,
                    "user_id": "test@example.com",
                },
            )

        assert response.status_code == 200
        data = response.json()
        assert data["model"] == "gpt-4"  # Should return the requested model name
