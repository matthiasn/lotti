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

    @pytest.mark.asyncio
    @pytest.mark.skipif(not os.getenv("GEMINI_API_KEY"), reason="GEMINI_API_KEY not set - skipping integration test")
    async def test_chat_completions_streaming(self):
        """Test streaming chat completion"""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/v1/chat/completions",
                json={
                    "model": "gemini-pro",
                    "messages": [{"role": "user", "content": "Say 'Hello' and nothing else."}],
                    "temperature": 0.1,
                    "stream": True,
                    "user_id": "test@example.com",
                },
            )

        assert response.status_code == 200
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8"

        # Collect streaming chunks
        chunks = []
        async for line in response.aiter_lines():
            if line.strip() and line.startswith("data: "):
                chunk_data = line[6:]  # Remove "data: " prefix
                if chunk_data != "[DONE]":
                    import json

                    chunks.append(json.loads(chunk_data))

        # Verify streaming response structure
        assert len(chunks) > 0
        assert chunks[0]["object"] == "chat.completion.chunk"
        assert chunks[0]["choices"][0]["delta"]["role"] == "assistant"

        # Verify final chunk has usage data
        final_chunk = chunks[-1]
        assert final_chunk["choices"][0]["finish_reason"] == "stop"
        assert "usage" in final_chunk
        assert final_chunk["usage"]["total_tokens"] > 0


class TestErrorHandling:
    """Test cases for error handling"""

    @pytest.mark.asyncio
    async def test_invalid_model_error(self):
        """Test error handling for invalid model (mocked)"""
        from unittest.mock import patch, Mock
        from src.core.exceptions import InvalidModelException

        transport = ASGITransport(app=app)

        # Mock the gemini client to raise InvalidModelException
        with patch("src.container.container.get_gemini_client") as mock_get_client:
            mock_client = Mock()
            mock_client.generate_completion.side_effect = InvalidModelException("Invalid model")
            mock_get_client.return_value = mock_client

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/v1/chat/completions",
                    json={
                        "model": "invalid-model",
                        "messages": [{"role": "user", "content": "Test"}],
                    },
                )

        assert response.status_code == 400
        assert "Invalid model" in response.text

    @pytest.mark.asyncio
    async def test_ai_provider_error(self):
        """Test error handling for AI provider errors (mocked)"""
        from unittest.mock import patch, Mock
        from src.core.exceptions import AIProviderException

        transport = ASGITransport(app=app)

        # Mock the gemini client to raise AIProviderException
        with patch("src.container.container.get_gemini_client") as mock_get_client:
            mock_client = Mock()
            mock_client.generate_completion.side_effect = AIProviderException("Provider error")
            mock_get_client.return_value = mock_client

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/v1/chat/completions",
                    json={
                        "model": "gemini-pro",
                        "messages": [{"role": "user", "content": "Test"}],
                    },
                )

        assert response.status_code == 500
        assert "AI provider error" in response.text

    @pytest.mark.asyncio
    async def test_unexpected_error(self):
        """Test error handling for unexpected errors (mocked)"""
        from unittest.mock import patch, Mock

        transport = ASGITransport(app=app)

        # Mock the gemini client to raise a generic exception
        with patch("src.container.container.get_gemini_client") as mock_get_client:
            mock_client = Mock()
            mock_client.generate_completion.side_effect = RuntimeError("Unexpected error")
            mock_get_client.return_value = mock_client

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post(
                    "/v1/chat/completions",
                    json={
                        "model": "gemini-pro",
                        "messages": [{"role": "user", "content": "Test"}],
                    },
                )

        assert response.status_code == 500
        assert "Internal server error" in response.text
