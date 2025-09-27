"""Legacy streaming generator bridge"""

import sys
from pathlib import Path
from typing import AsyncGenerator

# Temporary bridge to existing streaming functionality


class StreamGenerator:
    """Bridge to legacy StreamGenerator"""

    def __init__(self, model_manager, audio_processor):
        sys.path.append(str(Path(__file__).parent.parent.parent))
        from streaming import StreamGenerator as LegacyStreamGenerator

        self.legacy_generator = LegacyStreamGenerator(model_manager, audio_processor)

    async def generate_chat_stream(
        self,
        prompt: str,
        temperature: float,
        max_tokens: int,
        top_p: float
    ) -> AsyncGenerator[str, None]:
        """Generate streaming chat completion"""
        async for chunk in self.legacy_generator.generate_chat_stream(
            prompt=prompt,
            temperature=temperature,
            max_tokens=max_tokens,
            top_p=top_p
        ):
            yield chunk