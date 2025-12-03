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

    # ==================== Streaming Tests ====================

    @pytest.mark.asyncio
    async def test_generate_completion_stream_success(self, gemini_client):
        """Test successful streaming completion with multiple chunks"""
        messages = [ChatMessage(role="user", content="Hello")]

        # Create mock chunks that simulate streaming response
        mock_chunk1 = Mock()
        mock_chunk1.text = "Hello"
        mock_chunk1.usage_metadata = None

        mock_chunk2 = Mock()
        mock_chunk2.text = " there"
        mock_chunk2.usage_metadata = None

        mock_chunk3 = Mock()
        mock_chunk3.text = "!"
        mock_chunk3.usage_metadata = Mock(
            prompt_token_count=5,
            candidates_token_count=3,
            total_token_count=8,
        )

        # Mock the streaming response as an iterable
        mock_stream = [mock_chunk1, mock_chunk2, mock_chunk3]

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=iter(mock_stream))

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            chunks = []
            async for chunk in gemini_client.generate_completion_stream(
                messages=messages,
                model="gemini-pro",
                temperature=0.7,
            ):
                chunks.append(chunk)

        # First chunk should have role
        assert chunks[0]["choices"][0]["delta"]["role"] == "assistant"

        # Content chunks (chunks 1-3 are the text chunks)
        content_chunks = [c for c in chunks if "content" in c["choices"][0]["delta"]]
        assert len(content_chunks) == 3
        assert content_chunks[0]["choices"][0]["delta"]["content"] == "Hello"
        assert content_chunks[1]["choices"][0]["delta"]["content"] == " there"
        assert content_chunks[2]["choices"][0]["delta"]["content"] == "!"

        # Final chunk should have finish_reason and usage
        final_chunk = chunks[-1]
        assert final_chunk["choices"][0]["finish_reason"] == "stop"
        assert final_chunk["usage"]["prompt_tokens"] == 5
        assert final_chunk["usage"]["completion_tokens"] == 3
        assert final_chunk["usage"]["total_tokens"] == 8

    @pytest.mark.asyncio
    async def test_generate_completion_stream_empty(self, gemini_client):
        """Test streaming with no chunks returns empty content but no exception"""
        messages = [ChatMessage(role="user", content="Hello")]

        # Empty stream - no chunks
        mock_stream = []

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=iter(mock_stream))

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            chunks = []
            async for chunk in gemini_client.generate_completion_stream(
                messages=messages,
                model="gemini-pro",
            ):
                chunks.append(chunk)

        # Should still get first chunk (role) and final chunk (finish_reason)
        assert len(chunks) == 2
        assert chunks[0]["choices"][0]["delta"]["role"] == "assistant"
        assert chunks[-1]["choices"][0]["finish_reason"] == "stop"
        # Usage should be zeros since no chunks had metadata
        assert chunks[-1]["usage"]["prompt_tokens"] == 0
        assert chunks[-1]["usage"]["completion_tokens"] == 0

    @pytest.mark.asyncio
    async def test_generate_completion_stream_api_error(self, gemini_client):
        """Test streaming when Gemini API raises an error"""
        messages = [ChatMessage(role="user", content="Hello")]

        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=Exception("Stream API Error"))

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            with pytest.raises(AIProviderException, match="Gemini API error"):
                async for _ in gemini_client.generate_completion_stream(
                    messages=messages,
                    model="gemini-pro",
                ):
                    pass

    @pytest.mark.asyncio
    async def test_generate_completion_stream_error_mid_stream(self, gemini_client):
        """Test streaming when error occurs mid-stream during iteration"""
        messages = [ChatMessage(role="user", content="Hello")]

        # Create an iterator that raises an exception after yielding some chunks
        def error_iterator():
            mock_chunk = Mock()
            mock_chunk.text = "Hello"
            mock_chunk.usage_metadata = None
            yield mock_chunk
            raise Exception("Mid-stream error")

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=error_iterator())

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            with pytest.raises(AIProviderException, match="Gemini API error"):
                chunks = []
                async for chunk in gemini_client.generate_completion_stream(
                    messages=messages,
                    model="gemini-pro",
                ):
                    chunks.append(chunk)

    @pytest.mark.asyncio
    async def test_generate_completion_stream_with_max_tokens(self, gemini_client):
        """Test streaming completion with temperature and max_tokens parameters"""
        messages = [ChatMessage(role="user", content="Hello")]

        mock_chunk = Mock()
        mock_chunk.text = "Response"
        mock_chunk.usage_metadata = Mock(
            prompt_token_count=5,
            candidates_token_count=1,
            total_token_count=6,
        )
        mock_stream = [mock_chunk]

        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=iter(mock_stream))

        with patch("google.generativeai.GenerativeModel", return_value=mock_model), patch(
            "google.generativeai.GenerationConfig"
        ) as mock_config:
            async for _ in gemini_client.generate_completion_stream(
                messages=messages,
                model="gemini-pro",
                temperature=0.3,
                max_tokens=50,
            ):
                pass

            # Verify GenerationConfig was called with correct parameters
            mock_config.assert_called_once_with(
                temperature=0.3,
                max_output_tokens=50,
            )

    @pytest.mark.asyncio
    async def test_generate_completion_stream_with_history(self, gemini_client):
        """Test streaming with conversation history uses start_chat"""
        messages = [
            ChatMessage(role="user", content="Hi"),
            ChatMessage(role="assistant", content="Hello!"),
            ChatMessage(role="user", content="How are you?"),
        ]

        mock_chunk = Mock()
        mock_chunk.text = "I'm doing well!"
        mock_chunk.usage_metadata = Mock(
            prompt_token_count=20,
            candidates_token_count=5,
            total_token_count=25,
        )
        mock_stream = [mock_chunk]

        mock_chat = Mock()
        mock_chat.send_message = Mock(return_value=iter(mock_stream))

        mock_model = Mock()
        mock_model.start_chat = Mock(return_value=mock_chat)

        with patch("google.generativeai.GenerativeModel", return_value=mock_model):
            chunks = []
            async for chunk in gemini_client.generate_completion_stream(
                messages=messages,
                model="gemini-pro",
            ):
                chunks.append(chunk)

        # Verify start_chat was called with history
        mock_model.start_chat.assert_called_once()
        call_kwargs = mock_model.start_chat.call_args
        history = call_kwargs[1]["history"]
        assert len(history) == 2
        assert history[0]["role"] == "user"
        assert history[0]["parts"] == ["Hi"]
        assert history[1]["role"] == "model"
        assert history[1]["parts"] == ["Hello!"]

        # Verify send_message was called with the last user message
        mock_chat.send_message.assert_called_once()
        assert mock_chat.send_message.call_args[0][0] == "How are you?"
