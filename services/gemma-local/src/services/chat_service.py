"""Chat completion service implementation"""

import time
import uuid
import logging
from typing import AsyncIterator, Any, Optional, List

from ..core.interfaces import IChatService, IModelManager, IModelValidator
from ..core.models import ChatRequest, ChatResponse
from ..core.exceptions import TranscriptionError


logger = logging.getLogger(__name__)


class ChatService(IChatService):
    """Handles chat completions and audio transcription through chat interface"""

    def __init__(
        self,
        model_manager: IModelManager,
        model_validator: IModelValidator,
        transcription_service: Optional[Any] = None,  # Optional, to avoid circular import
    ) -> None:
        self.model_manager = model_manager
        self.model_validator = model_validator
        self._transcription_service = transcription_service

    def set_transcription_service(self, transcription_service: Any) -> None:
        """Set transcription service (dependency injection after creation)"""
        self._transcription_service = transcription_service

    async def complete_chat(self, request: ChatRequest) -> ChatResponse:
        """Generate chat completion"""
        request_id = uuid.uuid4().hex[:8]

        try:
            # Ensure model is available
            await self.model_validator.ensure_model_available(request.model)

            # Check if this is audio transcription
            if request.audio and self._transcription_service:
                # Handle as audio transcription
                from ..core.models import AudioRequest

                # Extract context from messages
                context_prompt = self._extract_context_from_messages(request.messages)

                audio_request = AudioRequest(
                    audio_data=request.audio,
                    model=request.model,
                    language=request.language,
                    context_prompt=context_prompt,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens,
                )

                result = await self._transcription_service.transcribe_audio(audio_request)

                # Return in chat completion format
                return ChatResponse(
                    id=f"chatcmpl-{request_id}",
                    model=request.model,
                    choices=[
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": result.text},
                            "finish_reason": "stop",
                        }
                    ],
                    usage={
                        "prompt_tokens": len(context_prompt.split()) if context_prompt else 0,
                        "completion_tokens": len(result.text.split()),
                        "total_tokens": (
                            len(context_prompt.split()) + len(result.text.split())
                            if context_prompt
                            else len(result.text.split())
                        ),
                    },
                    created=int(time.time()),
                    system_fingerprint=f"req-{request_id}",
                )
            else:
                # Regular text chat completion
                response_text = await self._generate_text_completion(request)

                return ChatResponse(
                    id=f"chatcmpl-{request_id}",
                    model=request.model,
                    choices=[
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": response_text},
                            "finish_reason": "stop",
                        }
                    ],
                    usage={
                        "prompt_tokens": self._count_tokens_in_messages(request.messages),
                        "completion_tokens": len(response_text.split()),
                        "total_tokens": self._count_tokens_in_messages(request.messages) + len(response_text.split()),
                    },
                    created=int(time.time()),
                )

        except Exception as e:
            logger.error(f"Chat completion error: {e}")
            raise

    async def complete_chat_stream(self, request: ChatRequest) -> AsyncIterator[str]:
        """Generate streaming chat completion"""
        # This would implement streaming chat completion
        # For now, we'll use the existing streaming generator
        from ..legacy.streaming_generator import StreamGenerator

        generator = StreamGenerator(self.model_manager, None)
        prompt = self._build_chat_prompt(request.messages)

        async for chunk in generator.generate_chat_stream(
            prompt=prompt,
            temperature=request.temperature,
            max_tokens=request.max_tokens or 2000,
            top_p=request.top_p,
        ):
            yield chunk

    def _extract_context_from_messages(self, messages: List[Any]) -> str:
        """Extract context prompt from chat messages"""
        for message in messages:
            if message.get("role") == "user" and "Context:" in message.get("content", ""):
                content = message.get("content", "")
                if "Context:" in content:
                    context_part = content.split("Context:")[1].split("\n\n")[0].strip()
                    if context_part:
                        return context_part
        return ""

    def _build_chat_prompt(self, messages: List[Any]) -> str:
        """Build a prompt from chat messages"""
        prompt_parts = []

        for message in messages:
            role = message.get("role", "user")
            content = message.get("content", "")

            if role == "system":
                prompt_parts.append(f"System: {content}")
            elif role == "user":
                prompt_parts.append(f"User: {content}")
            elif role == "assistant":
                prompt_parts.append(f"Assistant: {content}")

        prompt_parts.append("Assistant:")
        return "\n\n".join(prompt_parts)

    def _count_tokens_in_messages(self, messages: List[Any]) -> int:
        """Count approximate tokens in messages"""
        total = 0
        for message in messages:
            content = message.get("content", "")
            total += len(content.split())
        return total

    async def _generate_text_completion(self, request: ChatRequest) -> str:
        """Generate text completion"""
        # Ensure model is loaded
        if not self.model_manager.is_model_loaded():
            success = await self.model_manager.load_model()
            if not success:
                raise TranscriptionError("Failed to load model")

        # This would use the actual text generation logic
        # For now, we'll import the existing function
        from ..legacy.text_generator import generate_text

        prompt = self._build_chat_prompt(request.messages)
        return await generate_text(
            prompt=prompt,
            temperature=request.temperature,
            max_tokens=request.max_tokens or 2000,
            top_p=request.top_p,
            model_manager=self.model_manager,
        )
