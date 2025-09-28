"""Adapter for existing audio_processor.py"""

import sys
from pathlib import Path
from typing import Optional, Any, Tuple

# Add parent directory to path to import legacy modules
sys.path.append(str(Path(__file__).parent.parent.parent))

from audio_processor import audio_processor as legacy_audio_processor
from ..core.interfaces import IAudioProcessor


class AudioProcessorAdapter(IAudioProcessor):
    """Adapts the legacy audio_processor to the new interface"""

    def __init__(self) -> None:
        self.legacy_processor = legacy_audio_processor

    async def process_audio_base64(
        self,
        audio_base64: str,
        context_prompt: Optional[str] = None,
        use_chunking: bool = False,
        request_id: Optional[str] = None,
    ) -> Tuple[Any, ...]:
        """Process base64 audio data"""
        return await self.legacy_processor.process_audio_base64(
            audio_base64=audio_base64,
            prompt=context_prompt,
            use_chunking=use_chunking,
            request_id=request_id,
        )
