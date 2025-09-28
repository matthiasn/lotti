"""Transcription service implementation"""

import time
import uuid
import logging
from typing import Any, List

from ..core.interfaces import ITranscriptionService, IModelManager, IAudioProcessor, IModelValidator
from ..core.models import AudioRequest, TranscriptionResult
from ..core.exceptions import TranscriptionError, AudioProcessingError


logger = logging.getLogger(__name__)


class TranscriptionService(ITranscriptionService):
    """Handles audio transcription using the loaded model"""

    def __init__(
        self,
        model_manager: IModelManager,
        audio_processor: IAudioProcessor,
        model_validator: IModelValidator,
    ):
        self.model_manager = model_manager
        self.audio_processor = audio_processor
        self.model_validator = model_validator

    async def transcribe_audio(self, request: AudioRequest) -> TranscriptionResult:
        """Transcribe audio to text"""
        request_id = uuid.uuid4().hex[:8]
        logger.info(f"[REQ {request_id}] Audio transcription request received. Model={request.model}")

        start_time = time.perf_counter()

        try:
            # Ensure the requested model is available
            await self.model_validator.ensure_model_available(request.model)

            # Ensure model is loaded
            if not self.model_manager.is_model_loaded():
                logger.info("Loading model for transcription...")
                success = await self.model_manager.load_model()
                if not success:
                    raise TranscriptionError("Failed to load model for transcription")

            # Process audio
            t_audio0 = time.perf_counter()
            try:
                result = await self.audio_processor.process_audio_base64(
                    request.audio_data,
                    request.context_prompt,
                    use_chunking=True,
                    request_id=request_id,
                )
                t_audio1 = time.perf_counter()
            except Exception as e:
                raise AudioProcessingError(f"Failed to process audio: {e}") from e

            # Handle chunked vs single audio
            if isinstance(result[0], list):
                audio_chunks, combined_prompt = result
            else:
                audio_array, combined_prompt = result
                audio_chunks = [audio_array]

            # Add language hint if provided
            if request.language:
                combined_prompt = f"{combined_prompt}\n\nLanguage: {request.language}"

            # Build messages for transcription
            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful assistant that transcribes audio accurately. "
                    "Format the transcription clearly with proper punctuation and paragraph breaks. "
                    "If there are multiple speakers, indicate speaker changes. Remove filler words. "
                    "Focus on the context provided.",
                },
                {"role": "user", "content": combined_prompt},
            ]

            # Generate transcription
            t_gen0 = time.perf_counter()
            if len(audio_chunks) == 1:
                logger.info(f"[REQ {request_id}] 1 chunk; starting generation")
                transcription = await self._generate_single_transcription(messages, audio_chunks[0], request_id)
            else:
                logger.info(f"[REQ {request_id}] {len(audio_chunks)} chunks; starting sequential generation")
                transcription = await self._generate_chunked_transcription(audio_chunks, messages, request_id)
            t_gen1 = time.perf_counter()

            total_time = time.perf_counter() - start_time
            audio_time = t_audio1 - t_audio0
            gen_time = t_gen1 - t_gen0

            logger.info(
                f"[REQ {request_id}] Done. AudioProc={audio_time:.2f}s, "
                f"Gen={gen_time:.2f}s, Total={total_time:.2f}s"
            )

            # Calculate audio duration
            audio_duration = None
            if len(audio_chunks) == 1:
                try:
                    samples = audio_chunks[0].shape[0]
                    audio_duration = samples / 16000.0  # Assuming 16kHz
                except Exception as e:
                    logger.debug(f"Could not calculate audio duration: {e}")
                    # Keep default audio_duration = 0.0

            return TranscriptionResult(
                text=transcription,
                model_used=request.model,
                processing_time=total_time,
                audio_duration=audio_duration,
                request_id=request_id,
            )

        except Exception as e:
            logger.error(f"[REQ {request_id}] Transcription failed: {e}")
            if isinstance(e, (TranscriptionError, AudioProcessingError)):
                raise
            raise TranscriptionError(f"Transcription failed: {e}") from e

    async def _generate_single_transcription(self, messages: List[Any], audio_array: Any, request_id: str) -> str:
        """Generate transcription for a single audio chunk"""
        # This would call the actual model inference
        # For now, we'll import and use the existing function
        # In a real refactor, this logic would be extracted to a separate class
        from ..legacy.transcription_engine import generate_transcription_with_chat_context

        return await generate_transcription_with_chat_context(
            messages=messages,
            audio_array=audio_array,
            request_id=request_id,
            model_manager=self.model_manager,
        )

    async def _generate_chunked_transcription(
        self, audio_chunks: List[Any], initial_messages: List[Any], request_id: str
    ) -> str:
        """Generate transcription for multiple audio chunks"""
        # This would call the actual chunked processing
        # For now, we'll import and use the existing function
        from ..legacy.transcription_engine import process_audio_chunks_with_continuation

        return await process_audio_chunks_with_continuation(
            chunks=audio_chunks,
            initial_messages=initial_messages,
            request_id=request_id,
            model_manager=self.model_manager,
        )
