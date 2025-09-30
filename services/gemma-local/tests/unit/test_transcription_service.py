"""Unit tests for TranscriptionService"""

import pytest
import numpy as np
from unittest.mock import AsyncMock, patch

from src.services.transcription_service import TranscriptionService
from src.core.models import AudioRequest, TranscriptionResult
from src.core.exceptions import TranscriptionError, AudioProcessingError
from typing import Any


@pytest.mark.unit
class TestTranscriptionService:
    """Test TranscriptionService functionality"""

    def test_init(self, mock_model_manager, mock_audio_processor, mock_model_validator) -> None:
        """Test service initialization"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)
        assert service.model_manager == mock_model_manager
        assert service.audio_processor == mock_audio_processor
        assert service.model_validator == mock_model_validator

    @pytest.mark.asyncio
    async def test_transcribe_audio_success_single_chunk(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test successful transcription with single audio chunk"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        # Mock audio processing to return single chunk
        audio_array = np.array([1, 2, 3, 4, 5], dtype=np.float32)
        mock_audio_processor.process_audio_base64.return_value = (
            audio_array,
            "Test prompt",
        )  # Single array, not list

        # Mock model is loaded
        mock_model_manager.is_model_loaded.return_value = True

        # Mock single transcription generation
        with patch.object(
            service,
            "_generate_single_transcription",
            new=AsyncMock(return_value="Test transcription"),
        ) as mock_gen:
            request = AudioRequest(
                audio_data="base64encodedaudio",
                model="gemma-3n-E2B-it",
                context_prompt="Test context",
            )

            result = await service.transcribe_audio(request)

            assert isinstance(result, TranscriptionResult)
            assert result.text == "Test transcription"
            assert result.model_used == "gemma-3n-E2B-it"
            assert result.processing_time > 0

            # Verify service calls
            mock_model_validator.ensure_model_available.assert_called_once_with("gemma-3n-E2B-it")
            mock_audio_processor.process_audio_base64.assert_called_once()
            mock_gen.assert_called_once()

    @pytest.mark.asyncio
    async def test_transcribe_audio_success_multiple_chunks(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test successful transcription with multiple audio chunks"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        # Mock audio processing to return multiple chunks
        chunk1 = np.array([1, 2, 3], dtype=np.float32)
        chunk2 = np.array([4, 5, 6], dtype=np.float32)
        mock_audio_processor.process_audio_base64.return_value = (
            [chunk1, chunk2],
            "Test prompt",
        )  # List of arrays

        mock_model_manager.is_model_loaded.return_value = True

        # Mock chunked transcription generation
        with patch.object(
            service,
            "_generate_chunked_transcription",
            new=AsyncMock(return_value="Chunked transcription"),
        ) as mock_gen:
            request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it")

            result = await service.transcribe_audio(request)

            assert result.text == "Chunked transcription"
            mock_gen.assert_called_once()

    @pytest.mark.asyncio
    async def test_transcribe_audio_model_not_loaded(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test transcription when model needs to be loaded"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        # Mock model not loaded initially
        mock_model_manager.is_model_loaded.return_value = False
        mock_model_manager.load_model.return_value = True

        # Mock audio processing
        audio_array = np.array([1, 2, 3], dtype=np.float32)
        mock_audio_processor.process_audio_base64.return_value = (audio_array, "Test prompt")

        with patch.object(
            service,
            "_generate_single_transcription",
            new=AsyncMock(return_value="Test transcription"),
        ):
            request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it")

            result = await service.transcribe_audio(request)

            # Should have loaded the model
            mock_model_manager.load_model.assert_called_once()
            assert result.text == "Test transcription"

    @pytest.mark.asyncio
    async def test_transcribe_audio_model_load_failure(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test transcription when model loading fails"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        mock_model_manager.is_model_loaded.return_value = False
        mock_model_manager.load_model.return_value = False  # Load fails

        request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it")

        with pytest.raises(TranscriptionError, match="Failed to load model"):
            await service.transcribe_audio(request)

    @pytest.mark.asyncio
    async def test_transcribe_audio_processing_error(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test transcription when audio processing fails"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        mock_model_manager.is_model_loaded.return_value = True
        mock_audio_processor.process_audio_base64.side_effect = Exception("Audio processing failed")

        request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it")

        with pytest.raises(AudioProcessingError, match="Failed to process audio"):
            await service.transcribe_audio(request)

    @pytest.mark.asyncio
    async def test_transcribe_audio_with_language_hint(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test transcription with language hint"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        mock_model_manager.is_model_loaded.return_value = True
        audio_array = np.array([1, 2, 3], dtype=np.float32)
        mock_audio_processor.process_audio_base64.return_value = (audio_array, "Test prompt")

        with patch.object(
            service,
            "_generate_single_transcription",
            new=AsyncMock(return_value="Test transcription"),
        ) as mock_gen:
            request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it", language="en")

            await service.transcribe_audio(request)

            # Check that language hint was added to the message
            call_args = mock_gen.call_args
            messages = call_args[0][0]  # First positional argument
            user_message = next(msg for msg in messages if msg["role"] == "user")
            assert "Language: en" in user_message["content"]

    @pytest.mark.asyncio
    async def test_transcribe_audio_audio_duration_calculation(
        self, mock_model_manager, mock_audio_processor, mock_model_validator
    ) -> None:
        """Test audio duration calculation for single chunk"""
        service = TranscriptionService(mock_model_manager, mock_audio_processor, mock_model_validator)

        mock_model_manager.is_model_loaded.return_value = True

        # Create audio with known sample count
        samples = 16000  # 1 second at 16kHz
        audio_array = np.array(range(samples), dtype=np.float32)
        mock_audio_processor.process_audio_base64.return_value = (audio_array, "Test prompt")

        with patch.object(
            service,
            "_generate_single_transcription",
            new=AsyncMock(return_value="Test transcription"),
        ):
            request = AudioRequest(audio_data="base64encodedaudio", model="gemma-3n-E2B-it")

            result = await service.transcribe_audio(request)

            # Should calculate duration as 1.0 second
            assert result.audio_duration == 1.0
