"""Gemini AI client implementation"""

import asyncio
import logging
import time
import uuid
from typing import List

import google.generativeai as genai

from ..core.constants import MODEL_MAPPINGS
from ..core.exceptions import AIProviderException
from ..core.interfaces import IGeminiClient
from ..core.models import ChatMessage, ChatCompletionResponse, ChatChoice, Usage

logger = logging.getLogger(__name__)


class GeminiClient(IGeminiClient):
    """Client for interacting with Google Gemini API"""

    def __init__(self, api_key: str):
        """
        Initialize Gemini client

        Args:
            api_key: Google Gemini API key
        """
        self.api_key = api_key
        genai.configure(api_key=api_key)
        logger.info("Gemini client initialized")

    def _map_model(self, requested_model: str) -> str:
        """
        Map OpenAI-style model names to Gemini models

        Args:
            requested_model: Requested model name (e.g., 'gpt-4', 'gemini-pro')

        Returns:
            Gemini model name
        """
        mapped_model = MODEL_MAPPINGS.get(requested_model, requested_model)
        logger.debug(f"Mapped model '{requested_model}' to '{mapped_model}'")
        return mapped_model

    def _convert_messages_to_gemini_format(self, messages: List[ChatMessage]) -> tuple[str | None, list[dict], str]:
        """
        Convert OpenAI-style messages to Gemini's native chat format

        Args:
            messages: List of chat messages

        Returns:
            Tuple of (system_instruction, history, last_user_message)
            - system_instruction: System message content if present, None otherwise
            - history: List of previous messages in Gemini format for chat history
            - last_user_message: The final user message to send
        """
        system_instruction = None
        history = []
        last_user_message = ""

        # Extract system instruction if present
        non_system_messages = []
        for message in messages:
            if message.role == "system":
                # Combine multiple system messages if present
                if system_instruction:
                    system_instruction += "\n\n" + message.content
                else:
                    system_instruction = message.content
            else:
                non_system_messages.append(message)

        # Convert remaining messages to Gemini format
        # Gemini uses "user" and "model" roles
        for i, message in enumerate(non_system_messages):
            gemini_role = "user" if message.role == "user" else "model"

            # Last user message is sent separately via send_message()
            if i == len(non_system_messages) - 1 and message.role == "user":
                last_user_message = message.content
            else:
                history.append(
                    {
                        "role": gemini_role,
                        "parts": [message.content],
                    }
                )

        # If the last message wasn't from user, include it in history
        # and use empty string for last_user_message (edge case)
        if non_system_messages and non_system_messages[-1].role != "user":
            last_user_message = ""

        return system_instruction, history, last_user_message

    async def generate_completion(
        self,
        messages: List[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ) -> ChatCompletionResponse:
        """
        Generate a chat completion using Gemini

        Args:
            messages: List of chat messages
            model: Model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate

        Returns:
            ChatCompletionResponse with the completion

        Raises:
            InvalidModelException: If model is not supported
            AIProviderException: If Gemini API returns an error
        """
        try:
            # Map the model name
            gemini_model = self._map_model(model)

            # Convert messages to Gemini's native format
            system_instruction, history, last_user_message = self._convert_messages_to_gemini_format(messages)

            logger.info(f"Generating completion with model '{gemini_model}', temperature={temperature}")

            # Configure generation parameters
            generation_config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            )

            # Create the model with optional system instruction
            gemini = genai.GenerativeModel(
                gemini_model,
                system_instruction=system_instruction,
            )

            # Use chat for multi-turn conversations
            loop = asyncio.get_event_loop()
            if history or system_instruction:
                # Start chat with history and send the last message
                chat = gemini.start_chat(history=history)
                response = await loop.run_in_executor(
                    None,
                    lambda: chat.send_message(last_user_message, generation_config=generation_config),
                )
            else:
                # Simple single-message case - use generate_content directly
                response = await loop.run_in_executor(
                    None,
                    lambda: gemini.generate_content(last_user_message, generation_config=generation_config),
                )

            # Extract the generated text
            if not response.candidates:
                raise AIProviderException("No candidates returned from Gemini")

            generated_text = response.text

            # Extract usage metadata
            usage_metadata = response.usage_metadata
            prompt_tokens = usage_metadata.prompt_token_count
            completion_tokens = usage_metadata.candidates_token_count
            total_tokens = usage_metadata.total_token_count

            logger.info(
                f"Completion generated: {prompt_tokens} prompt tokens, "
                f"{completion_tokens} completion tokens, {total_tokens} total"
            )

            # Build OpenAI-compatible response
            completion_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
            created_timestamp = int(time.time())

            chat_response = ChatCompletionResponse(
                id=completion_id,
                object="chat.completion",
                created=created_timestamp,
                model=model,  # Return the requested model name, not the mapped one
                choices=[
                    ChatChoice(
                        index=0,
                        message=ChatMessage(role="assistant", content=generated_text),
                        finish_reason="stop",
                    )
                ],
                usage=Usage(
                    prompt_tokens=prompt_tokens,
                    completion_tokens=completion_tokens,
                    total_tokens=total_tokens,
                ),
            )

            return chat_response

        except Exception as e:
            logger.error(f"Error generating completion: {e}")
            raise AIProviderException(f"Gemini API error: {e}") from e

    async def generate_completion_stream(
        self,
        messages: List[ChatMessage],
        model: str,
        temperature: float = 0.7,
        max_tokens: int | None = None,
    ):
        """
        Generate a streaming chat completion using Gemini

        Args:
            messages: List of chat messages
            model: Model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate

        Yields:
            Chunks of the streaming response in OpenAI format

        Raises:
            InvalidModelException: If model is not supported
            AIProviderException: If Gemini API returns an error
        """
        try:
            # Map the model name
            gemini_model = self._map_model(model)

            # Convert messages to Gemini's native format
            system_instruction, history, last_user_message = self._convert_messages_to_gemini_format(messages)

            logger.info(f"Generating streaming completion with model '{gemini_model}', temperature={temperature}")

            # Configure generation parameters
            generation_config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            )

            # Create the model with optional system instruction
            gemini = genai.GenerativeModel(
                gemini_model,
                system_instruction=system_instruction,
            )

            # Generate streaming content
            loop = asyncio.get_event_loop()
            if history or system_instruction:
                # Start chat with history and send the last message with streaming
                chat = gemini.start_chat(history=history)
                response_stream = await loop.run_in_executor(
                    None,
                    lambda: chat.send_message(last_user_message, generation_config=generation_config, stream=True),
                )
            else:
                # Simple single-message case - use generate_content directly
                response_stream = await loop.run_in_executor(
                    None,
                    lambda: gemini.generate_content(
                        last_user_message, generation_config=generation_config, stream=True
                    ),
                )

            # Track token usage (accumulated from chunks)
            prompt_tokens = 0
            completion_tokens = 0
            total_tokens = 0

            # Generate unique completion ID
            completion_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
            created_timestamp = int(time.time())

            # First chunk: role
            first_chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created_timestamp,
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "delta": {"role": "assistant"},
                        "finish_reason": None,
                    }
                ],
            }
            yield first_chunk

            # Stream content chunks as they arrive
            for chunk in response_stream:
                if hasattr(chunk, "text") and chunk.text:
                    content_chunk = {
                        "id": completion_id,
                        "object": "chat.completion.chunk",
                        "created": created_timestamp,
                        "model": model,
                        "choices": [
                            {
                                "index": 0,
                                "delta": {"content": chunk.text},
                                "finish_reason": None,
                            }
                        ],
                    }
                    yield content_chunk

                # Accumulate usage metadata if available
                if hasattr(chunk, "usage_metadata") and chunk.usage_metadata:
                    usage_metadata = chunk.usage_metadata
                    prompt_tokens = usage_metadata.prompt_token_count
                    completion_tokens = usage_metadata.candidates_token_count
                    total_tokens = usage_metadata.total_token_count

            logger.info(
                f"Streaming completion finished: {prompt_tokens} prompt tokens, "
                f"{completion_tokens} completion tokens, {total_tokens} total"
            )

            # Final chunk: finish_reason and usage
            final_chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created_timestamp,
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "total_tokens": total_tokens,
                },
            }
            yield final_chunk

        except Exception as e:
            logger.error(f"Error generating streaming completion: {e}")
            raise AIProviderException(f"Gemini API error: {e}") from e
