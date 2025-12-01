"""Unit tests for Gemini client"""

import pytest
from unittest.mock import Mock, patch
from src.services.gemini_client import GeminiClient
from src.core.models import ChatMessage
from src.core.exceptions import AIProviderException


class TestGeminiClient:
    """Test cases for GeminiClient"""

    @pytest.fixture
    def gemini_client(self):
        """Create a Gemini client instance with mocked API"""
        with patch("google.generativeai.configure"):
            return GeminiClient(api_key="test-api-key")

    def test_init(self, gemini_client):
        """Test client initialization"""
        assert gemini_client.api_key == "test-api-key"

    def test_map_model_gpt4(self, gemini_client):
        """Test model mapping for gpt-4"""
        result = gemini_client._map_model("gpt-4")
        assert result == "gemini-2.5-pro"

    def test_map_model_gpt35(self, gemini_client):
        """Test model mapping for gpt-3.5-turbo"""
        result = gemini_client._map_model("gpt-3.5-turbo")
        assert result == "gemini-2.5-flash"

    def test_map_model_gemini_pro(self, gemini_client):
        """Test model mapping for gemini-pro"""
        result = gemini_client._map_model("gemini-pro")
        assert result == "gemini-2.5-pro"

    def test_map_model_unknown(self, gemini_client):
        """Test model mapping for unknown model (returns as-is)"""
        result = gemini_client._map_model("unknown-model")
        assert result == "unknown-model"

    def test_convert_messages_single_user(self, gemini_client):
        """Test message conversion with single user message"""
        messages = [ChatMessage(role="user", content="Hello, AI!")]
        system_instruction, history, last_user_message = gemini_client._convert_messages_to_gemini_format(messages)
        assert system_instruction is None
        assert history == []
        assert last_user_message == "Hello, AI!"

    def test_convert_messages_with_system(self, gemini_client):
        """Test message conversion with system message"""
        messages = [
            ChatMessage(role="system", content="You are a helpful assistant."),
            ChatMessage(role="user", content="Hello!"),
        ]
        system_instruction, history, last_user_message = gemini_client._convert_messages_to_gemini_format(messages)
        assert system_instruction == "You are a helpful assistant."
        assert history == []
        assert last_user_message == "Hello!"

    def test_convert_messages_with_assistant(self, gemini_client):
        """Test message conversion with assistant message (multi-turn)"""
        messages = [
            ChatMessage(role="user", content="What is 2+2?"),
            ChatMessage(role="assistant", content="4"),
            ChatMessage(role="user", content="What is 3+3?"),
        ]
        system_instruction, history, last_user_message = gemini_client._convert_messages_to_gemini_format(messages)
        assert system_instruction is None
        assert len(history) == 2
        assert history[0] == {"role": "user", "parts": ["What is 2+2?"]}
        assert history[1] == {"role": "model", "parts": ["4"]}
        assert last_user_message == "What is 3+3?"

    def test_convert_messages_multi_turn(self, gemini_client):
        """Test message conversion with system + multi-turn conversation"""
        messages = [
            ChatMessage(role="system", content="Be concise."),
            ChatMessage(role="user", content="Hi"),
            ChatMessage(role="assistant", content="Hello!"),
            ChatMessage(role="user", content="How are you?"),
        ]
        system_instruction, history, last_user_message = gemini_client._convert_messages_to_gemini_format(messages)
        assert system_instruction == "Be concise."
        assert len(history) == 2
        assert history[0] == {"role": "user", "parts": ["Hi"]}
        assert history[1] == {"role": "model", "parts": ["Hello!"]}
        assert last_user_message == "How are you?"

    @pytest.mark.asyncio
    async def test_generate_completion_success(self, gemini_client):
        """Test successful completion generation"""
        messages = [ChatMessage(role="user", content="Hello")]

        # Mock the Gemini API response
        mock_response = Mock()
        mock_response.candidates = [Mock()]
        mock_response.text = "Hello! How can I help you?"
        mock_response.usage_metadata = Mock(
            prompt_token_count=10,
            candidates_token_count=20,
            total_token_count=30,
        )

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            result = await gemini_client.generate_completion(
                messages=messages,
                model="gemini-pro",
                temperature=0.7,
            )

        assert result.model == "gemini-pro"
        assert result.choices[0].message.content == "Hello! How can I help you?"
        assert result.choices[0].message.role == "assistant"
        assert result.usage.prompt_tokens == 10
        assert result.usage.completion_tokens == 20
        assert result.usage.total_tokens == 30

    @pytest.mark.asyncio
    async def test_generate_completion_no_candidates(self, gemini_client):
        """Test completion generation when Gemini returns no candidates"""
        messages = [ChatMessage(role="user", content="Hello")]

        # Mock empty candidates
        mock_response = Mock()
        mock_response.candidates = []

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            with pytest.raises(AIProviderException, match="No candidates returned"):
                await gemini_client.generate_completion(
                    messages=messages,
                    model="gemini-pro",
                )

    @pytest.mark.asyncio
    async def test_generate_completion_api_error(self, gemini_client):
        """Test completion generation when Gemini API raises an error"""
        messages = [ChatMessage(role="user", content="Hello")]

        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=Exception("API Error"))

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            with pytest.raises(AIProviderException, match="Gemini API error"):
                await gemini_client.generate_completion(
                    messages=messages,
                    model="gemini-pro",
                )

    @pytest.mark.asyncio
    async def test_generate_completion_with_max_tokens(self, gemini_client):
        """Test completion generation with max_tokens parameter"""
        messages = [ChatMessage(role="user", content="Hello")]

        mock_response = Mock()
        mock_response.candidates = [Mock()]
        mock_response.text = "Response"
        mock_response.usage_metadata = Mock(
            prompt_token_count=5,
            candidates_token_count=10,
            total_token_count=15,
        )

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)

        with patch("google.generativeai.GenerativeModel", return_value=mock_model), patch(
            "google.generativeai.GenerationConfig"
        ) as mock_config:
            await gemini_client.generate_completion(
                messages=messages,
                model="gemini-pro",
                temperature=0.5,
                max_tokens=100,
            )

            # Verify GenerationConfig was called with max_tokens
            mock_config.assert_called_once_with(
                temperature=0.5,
                max_output_tokens=100,
            )
