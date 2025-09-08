"""Streaming response generation for Gemma Local Service."""

import json
import time
import uuid
import logging
from typing import AsyncGenerator, Optional
import torch
from transformers import TextIteratorStreamer
from threading import Thread

from config import ServiceConfig

logger = logging.getLogger(__name__)


class StreamGenerator:
    """Handles streaming response generation."""
    
    def __init__(self, model_manager, audio_processor):
        self.model_manager = model_manager
        self.audio_processor = audio_processor
    
    async def generate_stream(
        self,
        prompt: str,
        audio_array: Optional[object] = None,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        top_p: float = 0.95
    ) -> AsyncGenerator[str, None]:
        """
        Generate streaming transcription response.
        
        Yields SSE-formatted chunks for audio transcription.
        """
        try:
            
            # Use the working non-streaming generation and convert to streaming format
            from main import generate_transcription_optimized
            import numpy as np
            
            # Handle list of audio chunks (use first chunk for streaming)
            if isinstance(audio_array, list):
                audio_array = audio_array[0]
            
            # Generate transcription using the working method
            transcription = await generate_transcription_optimized(
                prompt=prompt,
                audio_array=audio_array,
                temperature=temperature,
                task_type="cpu_optimized"
            )
            
            
            # Return the result in streaming format that the client expects
            # Send the complete transcription as a single chunk
            chunk = {
                "text": transcription
            }
            yield f"data: {json.dumps(chunk)}\n\n"
            
            # Send [DONE] marker
            yield f"data: [DONE]\n\n"
            
        except Exception as e:
            logger.error(f"Streaming generation error: {e}")
            logger.error(f"Full traceback:", exc_info=True)
            error_chunk = {
                "error": "An internal error occurred during streaming generation.",
                "done": True
            }
            yield f"data: {json.dumps(error_chunk)}\n\n"
    
    async def generate_chat_stream(
        self,
        prompt: str,
        temperature: float = 0.7,
        max_tokens: int = 1000,
        top_p: float = 0.95
    ) -> AsyncGenerator[str, None]:
        """
        Generate streaming chat completion response.
        
        Yields SSE-formatted chunks compatible with OpenAI API.
        """
        try:
            # Create response ID
            response_id = f"chatcmpl-{uuid.uuid4().hex[:8]}"
            created = int(time.time())
            
            # Tokenize input
            inputs = self.model_manager.tokenizer(
                prompt,
                return_tensors="pt",
                truncation=True,
                max_length=2048
            ).to(self.model_manager.device)
            
            # Set up streamer
            streamer = TextIteratorStreamer(
                self.model_manager.tokenizer,
                skip_prompt=True,
                skip_special_tokens=True
            )
            
            # Generation kwargs
            generation_kwargs = {
                "input_ids": inputs.input_ids,
                "attention_mask": inputs.attention_mask,
                "max_new_tokens": max_tokens,
                "temperature": temperature,
                "do_sample": temperature > 0,
                "top_p": top_p,
                "pad_token_id": self.model_manager.tokenizer.pad_token_id,
                "eos_token_id": self.model_manager.tokenizer.eos_token_id,
                "streamer": streamer,
            }
            
            # Start generation in a thread
            thread = Thread(
                target=self.model_manager.model.generate,
                kwargs=generation_kwargs
            )
            thread.start()
            
            # Stream tokens in OpenAI format
            for new_text in streamer:
                if new_text:
                    chunk = {
                        "id": response_id,
                        "object": "chat.completion.chunk",
                        "created": created,
                        "model": self.model_manager.model_id,
                        "choices": [
                            {
                                "index": 0,
                                "delta": {
                                    "content": new_text
                                },
                                "finish_reason": None
                            }
                        ]
                    }
                    yield f"data: {json.dumps(chunk)}\n\n"
            
            # Send final chunk with finish_reason
            final_chunk = {
                "id": response_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": self.model_manager.model_id,
                "choices": [
                    {
                        "index": 0,
                        "delta": {},
                        "finish_reason": "stop"
                    }
                ]
            }
            yield f"data: {json.dumps(final_chunk)}\n\n"
            
            # Send [DONE] marker
            yield "data: [DONE]\n\n"
            
            # Ensure thread completes
            thread.join()
            
        except Exception as e:
            logger.error(f"Chat streaming error: {e}")
            logger.error(f"Full traceback:", exc_info=True)
            error_chunk = {
                "error": {
                    "message": "An internal error occurred during chat streaming generation.",
                    "type": "generation_error",
                    "code": 500
                }
            }
            yield f"data: {json.dumps(error_chunk)}\n\n"
            yield "data: [DONE]\n\n"