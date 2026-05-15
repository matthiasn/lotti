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


class TestBuildTranscriptionInstruction:
    """Tests for the transcription user-message builder.

    These pin the *shape* of the prompt — order matters for Voxtral:
    the no-translate / language directive must lead so the dictionary
    text doesn't pull the model toward English."""

    def test_no_language_falls_back_to_detect_then_transcribe_rules(self):
        from main import _build_transcription_instruction

        out = _build_transcription_instruction(context=None, language=None)
        first_block = out.split("\n\n", 1)[0]
        # Detect-then-transcribe chain, with explicit no-translate.
        assert "Detect the language" in first_block
        assert "Transcribe in that EXACT language" in first_block
        assert "NEVER translate" in first_block
        # No dictionary block when context is missing.
        assert "Proper nouns" not in out

    def test_auto_language_uses_the_same_fallback(self):
        from main import _build_transcription_instruction

        out = _build_transcription_instruction(context=None, language="auto")
        assert "Detect the language" in out.split("\n\n", 1)[0]

    def test_iso_code_resolves_to_language_name(self):
        from main import _build_transcription_instruction

        out = _build_transcription_instruction(context=None, language="de")
        first_block = out.split("\n\n", 1)[0]
        # The German hint must be named explicitly; Voxtral has been
        # seen to ignore the raw ISO code.
        assert "German" in first_block
        assert "Transcribe this audio in German" in first_block
        assert "Do NOT translate" in first_block

    def test_unknown_iso_code_passes_through(self):
        """Codes not in the language-name table pass through as-is so
        downstream Voxtral can still try."""
        from main import _build_transcription_instruction

        out = _build_transcription_instruction(context=None, language="xx")
        assert "Transcribe this audio in xx" in out

    def test_language_directive_leads_before_dictionary(self):
        """Regression: dictionary in front of the directive lets the
        model drift into English. Directive must come first."""
        from main import _build_transcription_instruction

        out = _build_transcription_instruction(
            context="Bijan\nRike\nLotti",
            language="de",
        )
        directive_idx = out.find("Transcribe this audio in German")
        dictionary_idx = out.find("Bijan")
        assert directive_idx >= 0 and dictionary_idx >= 0
        assert directive_idx < dictionary_idx, (
            f"language directive should precede the dictionary block; "
            f"got directive@{directive_idx} dictionary@{dictionary_idx}"
        )

    def test_dictionary_block_omitted_for_empty_context(self):
        from main import _build_transcription_instruction

        for empty in (None, "", "   ", "\n"):
            out = _build_transcription_instruction(
                context=empty, language="de"
            )
            assert "Proper nouns" not in out


class TestStripVoxtralTimestamps:
    """Tests for the non-streaming `[from … to …]` regex stripper."""

    def test_strips_single_marker(self):
        from main import _strip_voxtral_timestamps

        text = "[from 0 minutes 0 seconds to 15 seconds] Hello world."
        assert _strip_voxtral_timestamps(text) == "Hello world."

    def test_strips_multiple_markers(self):
        from main import _strip_voxtral_timestamps

        text = (
            "[from 0 seconds to 15 seconds] First segment. "
            "[from 15 seconds to 30 seconds] Second segment."
        )
        assert (
            _strip_voxtral_timestamps(text) == "First segment. Second segment."
        )

    def test_collapses_whitespace_left_behind(self):
        from main import _strip_voxtral_timestamps

        # Marker on its own line should leave a single blank, not three.
        text = "Para one.\n\n[from 0 seconds to 5 seconds]\n\nPara two."
        assert _strip_voxtral_timestamps(text) == "Para one.\n\nPara two."

    def test_preserves_non_timestamp_brackets(self):
        """Annotations like `[inaudible]` and `[laughs]` must survive —
        the regex only matches brackets whose inner text starts with
        `from`.
        """
        from main import _strip_voxtral_timestamps

        text = "She said hello [inaudible] then [laughs] left."
        assert (
            _strip_voxtral_timestamps(text)
            == "She said hello [inaudible] then [laughs] left."
        )

    def test_handles_empty_and_unmarked_text(self):
        from main import _strip_voxtral_timestamps

        assert _strip_voxtral_timestamps("") == ""
        assert _strip_voxtral_timestamps("Plain text.") == "Plain text."


class TestTimestampStripper:
    """Tests for the streaming filter that survives marker splits
    across token-batch boundaries."""

    def test_passes_text_with_no_brackets_unchanged(self):
        from main import _TimestampStripper

        s = _TimestampStripper()
        assert s.feed("Hello world.") == "Hello world."
        assert s.flush() == ""

    def test_strips_marker_within_a_single_feed(self):
        from main import _TimestampStripper

        s = _TimestampStripper()
        out = s.feed("[from 0 seconds to 15 seconds] hello")
        assert out == " hello"
        assert s.flush() == ""

    def test_strips_marker_split_across_two_feeds(self):
        """A marker split mid-token must still be elided — the whole
        point of the streaming stripper."""
        from main import _TimestampStripper

        s = _TimestampStripper()
        first = s.feed("Hello [from 0 sec")
        second = s.feed("onds to 15 seconds] world.")
        # Nothing past the `[` should emit until the close-bracket
        # arrives and the prefix is examined.
        assert first == "Hello "
        assert second == " world."
        assert s.flush() == ""

    def test_strips_marker_split_into_many_pieces(self):
        from main import _TimestampStripper

        s = _TimestampStripper()
        out = "".join(
            [
                s.feed("a"),
                s.feed("["),
                s.feed("from"),
                s.feed(" 0 to 5 seconds"),
                s.feed("]"),
                s.feed("b"),
            ]
        )
        assert out == "ab"
        assert s.flush() == ""

    def test_preserves_non_from_brackets(self):
        from main import _TimestampStripper

        s = _TimestampStripper()
        out = s.feed("She said [inaudible] hello.")
        assert out == "She said [inaudible] hello."
        assert s.flush() == ""

    def test_flushes_unclosed_bracket_at_end_of_stream(self):
        """If the stream ends mid-bracket we must not silently drop the
        held text — flush returns it so the consumer sees the original
        characters."""
        from main import _TimestampStripper

        s = _TimestampStripper()
        out = s.feed("Hello [from 0 sec")
        assert out == "Hello "
        # Stream ends before the close-bracket arrives.
        assert s.flush() == "[from 0 sec"

    def test_long_unclosed_bracket_bails_out_safely(self):
        """A very long stretch of text after `[` without a close-bracket
        triggers the sanity bail-out and gets flushed as-is rather than
        held indefinitely."""
        from main import _TimestampStripper

        s = _TimestampStripper()
        payload = "[" + "x" * 250
        out = s.feed(payload)
        # When the cap trips, the entire held buffer flushes — so the
        # consumer sees every character we held.
        assert out == payload
        assert s.flush() == ""
