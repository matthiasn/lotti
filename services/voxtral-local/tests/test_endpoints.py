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
        # Should return 400 (no audio) or 404 (model not downloaded)
        # Do not accept 500 as it masks actual server errors
        assert response.status_code in [
            400,
            404,
        ], f"Expected 400 or 404, got {response.status_code}: {response.text}"
        # Verify error message is present in response
        response_json = response.json()
        assert "detail" in response_json or "error" in response_json


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

        # Extract content from messages (empty list case)
        context_parts = [
            message.get("content", "")
            for message in messages
            if isinstance(message.get("content", ""), str) and message.get("content", "").strip()
        ]

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


def _build_transcription_instruction(context: str | None, language: str | None) -> str:
    """Helper to build transcription instruction - mirrors logic from main.py.

    This helper duplicates the prompt construction logic from main.py for testing.
    Keep it in sync with the actual implementation when the prompt changes.
    """
    instruction_parts = []

    if context and context.strip():
        instruction_parts.append(context)

    # Add transcription directive with explicit language preservation
    # CRITICAL: Voxtral must NOT translate - output must match source language
    if language and language != "auto":
        instruction_parts.append(
            f"Transcribe the following audio in {language}. "
            "Output the transcription in the SAME language as spoken - do NOT translate."
        )
    else:
        instruction_parts.append(
            "Transcribe the following audio in its ORIGINAL language. "
            "Do NOT translate to English or any other language. "
            "Output the exact words spoken in the same language as the speaker."
        )

    # Add speech dictionary instruction if context was provided
    if context and context.strip():
        instruction_parts.append(
            "IMPORTANT: If a word sounds similar to any term in the speech dictionary or context above, "
            "use the exact spelling from the dictionary. The audio may be unclear but those are the "
            "correct spellings for this context."
        )

    # Request proper grammar and plain text output
    instruction_parts.append(
        "Use proper grammar and capitalization appropriate for the detected language "
        "(e.g., in English: capitalize 'I', first letter of sentences, proper nouns). "
        "Return ONLY the plain text transcription - no JSON, XML, or other formatting."
    )

    return "\n\n".join(instruction_parts)


class TestTranscriptionPrompt:
    """Tests for transcription prompt construction."""

    def test_prompt_includes_grammar_instruction(self):
        """Test that transcription prompt includes grammar/capitalization instruction."""
        transcription_instruction = _build_transcription_instruction(
            context="Dictionary: Flutter, Dart",
            language=None,
        )

        # Verify grammar instruction is present
        assert "proper grammar and capitalization" in transcription_instruction

    def test_prompt_includes_context_when_provided(self):
        """Test that context is included in the prompt."""
        transcription_instruction = _build_transcription_instruction(
            context="Speech dictionary: Riverpod, GetIt, Flutter",
            language=None,
        )

        assert "Speech dictionary: Riverpod, GetIt, Flutter" in transcription_instruction

    def test_prompt_works_without_context(self):
        """Test that prompt works when no context is provided."""
        transcription_instruction = _build_transcription_instruction(
            context=None,
            language=None,
        )

        # Should still have transcription directive and grammar instruction
        assert (
            "Transcribe the following audio in its ORIGINAL language" in transcription_instruction
        )
        assert "proper grammar and capitalization" in transcription_instruction

    def test_prompt_includes_language_when_specified(self):
        """Test that language is included when specified."""
        transcription_instruction = _build_transcription_instruction(
            context=None,
            language="German",
        )

        assert "Transcribe the following audio in German." in transcription_instruction
        assert "do NOT translate" in transcription_instruction

    def test_prompt_uses_auto_detect_for_auto_language(self):
        """Test that 'auto' language falls back to original language preservation."""
        transcription_instruction = _build_transcription_instruction(
            context=None,
            language="auto",
        )

        # Should use generic "Transcribe in ORIGINAL language" without specific language
        assert "ORIGINAL language" in transcription_instruction
        assert "Do NOT translate to English" in transcription_instruction
        assert "in auto" not in transcription_instruction

    def test_prompt_explicitly_prevents_translation(self):
        """Test that prompt explicitly prevents translation to English."""
        # Without language specified
        instruction_no_lang = _build_transcription_instruction(context=None, language=None)
        assert "Do NOT translate to English" in instruction_no_lang
        assert (
            "Output the exact words spoken in the same language as the speaker"
            in instruction_no_lang
        )

        # With language specified
        instruction_with_lang = _build_transcription_instruction(context=None, language="German")
        assert "do NOT translate" in instruction_with_lang
        assert "SAME language as spoken" in instruction_with_lang

    def test_prompt_preserves_source_language(self):
        """Test that prompt instructs model to preserve source language."""
        transcription_instruction = _build_transcription_instruction(
            context=None,
            language=None,
        )

        # These phrases ensure German audio stays German, not translated to English
        assert "ORIGINAL language" in transcription_instruction
        assert "same language as the speaker" in transcription_instruction

    def test_prompt_includes_dictionary_instruction_when_context_provided(self):
        """Test that speech dictionary usage instruction is included when context is provided."""
        transcription_instruction = _build_transcription_instruction(
            context="Speech dictionary: macOS, iPhone, Flutter, Riverpod",
            language=None,
        )

        # Should include instruction to use dictionary spellings for similar-sounding words
        assert "speech dictionary" in transcription_instruction
        assert "sounds similar" in transcription_instruction
        assert "exact spelling from the dictionary" in transcription_instruction

    def test_prompt_omits_dictionary_instruction_without_context(self):
        """Test that dictionary instruction is not included when no context is provided."""
        transcription_instruction = _build_transcription_instruction(
            context=None,
            language=None,
        )

        # Should NOT include dictionary-specific instruction when no context
        assert "speech dictionary" not in transcription_instruction
        assert "sounds similar" not in transcription_instruction


class TestStreamingSupport:
    """Tests for streaming transcription support."""

    def test_text_iterator_streamer_import(self):
        """Test that TextIteratorStreamer can be imported."""
        from transformers import TextIteratorStreamer

        assert TextIteratorStreamer is not None

    def test_streaming_function_exists(self):
        """Test that _transcribe_streaming function exists in main module."""
        import inspect

        from main import _transcribe_streaming

        assert inspect.isasyncgenfunction(_transcribe_streaming)

    def test_non_streaming_function_exists(self):
        """Test that _transcribe_single function exists in main module."""
        import inspect

        from main import _transcribe_single

        assert inspect.iscoroutinefunction(_transcribe_single)


class _FakeTokenizer:
    """Deterministic stand-in for the Voxtral tokenizer.

    Avoids loading 3B+ model files just to verify the helper's
    bookkeeping: which terms are kept, which variants are registered,
    and which single-token entries are correctly skipped.
    """

    def __init__(self, table):
        self._table = table

    def encode(self, text, add_special_tokens=False):  # noqa: ARG002
        assert add_special_tokens is False
        return list(self._table[text])


class TestBuildSequenceBias:
    """Tests for the speech-dictionary -> `sequence_bias` helper."""

    def test_returns_none_when_no_terms(self):
        from main import _build_sequence_bias

        assert (
            _build_sequence_bias(terms=None, tokenizer=_FakeTokenizer({}), bias=2.0)
            is None
        )
        assert (
            _build_sequence_bias(terms=[], tokenizer=_FakeTokenizer({}), bias=2.0)
            is None
        )

    def test_returns_none_when_bias_is_zero(self):
        from main import _build_sequence_bias

        result = _build_sequence_bias(
            terms=["Flutter"],
            tokenizer=_FakeTokenizer({"Flutter": [1, 2], " Flutter": [3, 4]}),
            bias=0.0,
        )
        assert result is None

    def test_registers_multi_token_variants(self):
        """Both bare and leading-space tokenizations are registered when
        each tokenizes to ≥2 ids."""
        from main import _build_sequence_bias

        tokenizer = _FakeTokenizer(
            {"Riverpod": [201, 202], " Riverpod": [200, 202]}
        )
        result = _build_sequence_bias(
            terms=["Riverpod"], tokenizer=tokenizer, bias=2.0
        )
        assert result == {(201, 202): 2.0, (200, 202): 2.0}

    def test_skips_single_token_variants(self):
        """Single-token entries match the empty prefix and would bias
        the token globally, so they must be skipped."""
        from main import _build_sequence_bias

        # `" Flutter"` collapses to a single merged token in the real
        # Mistral tokenizer; only the bare variant should be biased.
        tokenizer = _FakeTokenizer(
            {"Flutter": [101, 102], " Flutter": [107651]}
        )
        result = _build_sequence_bias(
            terms=["Flutter"], tokenizer=tokenizer, bias=2.0
        )
        assert result == {(101, 102): 2.0}

    def test_returns_none_when_every_variant_is_single_token(self):
        """If neither variant is biasable, the helper returns None so
        the caller can skip wiring `sequence_bias` into `generate()`."""
        from main import _build_sequence_bias

        tokenizer = _FakeTokenizer({"X": [50], " X": [60]})
        result = _build_sequence_bias(
            terms=["X"], tokenizer=tokenizer, bias=2.0
        )
        assert result is None

    def test_strips_and_skips_empty_terms(self):
        """Whitespace-only or empty entries don't reach the tokenizer."""
        from main import _build_sequence_bias

        tokenizer = _FakeTokenizer(
            {
                "Flutter": [101, 102],
                " Flutter": [99, 100],
                "": [],
                " ": [1],
            }
        )
        result = _build_sequence_bias(
            terms=["Flutter", "   ", "", "  Flutter  "],
            tokenizer=tokenizer,
            bias=2.0,
        )
        # "  Flutter  " strips to "Flutter" — duplicate of the first
        # entry, so the result remains a single bias entry per variant.
        assert result == {(101, 102): 2.0, (99, 100): 2.0}

    def test_combines_multiple_terms(self):
        from main import _build_sequence_bias

        tokenizer = _FakeTokenizer(
            {
                "Flutter": [101, 102],
                " Flutter": [99],  # single token, skipped
                "Riverpod": [201, 202],
                " Riverpod": [200, 202],
            }
        )
        result = _build_sequence_bias(
            terms=["Flutter", "Riverpod"], tokenizer=tokenizer, bias=3.5
        )
        assert result == {
            (101, 102): 3.5,
            (201, 202): 3.5,
            (200, 202): 3.5,
        }
