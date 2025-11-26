"""Gemini AI client implementation"""

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

    def _convert_messages_to_prompt(self, messages: List[ChatMessage]) -> str:
        """
        Convert OpenAI-style messages to a single prompt for Gemini

        Args:
            messages: List of chat messages

        Returns:
            Combined prompt string
        """
        # Gemini 1.5 supports multi-turn conversations, but for simplicity
        # we'll combine them into a single prompt for now
        prompt_parts = []

        for message in messages:
            if message.role == "system":
                prompt_parts.append(f"System: {message.content}")
            elif message.role == "user":
                prompt_parts.append(f"User: {message.content}")
            elif message.role == "assistant":
                prompt_parts.append(f"Assistant: {message.content}")

        # For single user message (most common case), just use the content
        if len(messages) == 1 and messages[0].role == "user":
            return messages[0].content

        return "\n\n".join(prompt_parts)

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

            # Convert messages to prompt
            prompt = self._convert_messages_to_prompt(messages)

            logger.info(f"Generating completion with model '{gemini_model}', temperature={temperature}")

            # Configure generation parameters
            generation_config = genai.GenerationConfig(
                temperature=temperature,
                max_output_tokens=max_tokens,
            )

            # Create the model
            gemini = genai.GenerativeModel(gemini_model)

            # Generate content
            response = gemini.generate_content(
                prompt,
                generation_config=generation_config,
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
