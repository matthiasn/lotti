"""Legacy text generation bridge"""

import sys
from pathlib import Path


async def generate_text(prompt: str, temperature: float, max_tokens: int, top_p: float, model_manager=None) -> str:
    """Generate text completion"""
    # Import the actual function from main.py
    sys.path.append(str(Path(__file__).parent.parent.parent))
    from main import generate_text as legacy_func

    return await legacy_func(prompt, temperature, max_tokens, top_p)
