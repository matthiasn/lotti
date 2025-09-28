"""Legacy transcription engine functions"""

import sys
from pathlib import Path
from typing import List, Dict, Any, Optional
import numpy as np
from numpy.typing import NDArray

# Import from the main module temporarily
# In a full refactor, these functions would be properly extracted


async def generate_transcription_with_chat_context(
    messages: List[Dict[str, Any]],
    audio_array: NDArray[np.float32],
    request_id: Optional[str] = None,
    model_manager: Any = None,
) -> str:
    """Generate transcription using chat context for better understanding."""
    # Import the actual function from main.py
    # This is a temporary bridge
    sys.path.append(str(Path(__file__).parent.parent.parent))
    from main import generate_transcription_with_chat_context as legacy_func

    return await legacy_func(messages, audio_array, request_id)


async def process_audio_chunks_with_continuation(
    chunks: List[np.ndarray],
    initial_messages: List[Dict[str, Any]],
    request_id: Optional[str] = None,
    model_manager: Any = None,
) -> str:
    """Process multiple audio chunks with smart continuation."""
    # Import the actual function from main.py
    sys.path.append(str(Path(__file__).parent.parent.parent))
    from main import process_audio_chunks_with_continuation as legacy_func

    return await legacy_func(chunks, initial_messages, request_id)
