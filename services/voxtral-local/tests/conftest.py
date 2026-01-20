"""Pytest configuration and shared fixtures."""

import sys
from pathlib import Path

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Configure pytest-asyncio
pytest_plugins = ["pytest_asyncio"]


@pytest.fixture
def sample_audio_16khz():
    """Generate sample audio data at 16kHz."""
    import numpy as np

    duration = 1.0  # 1 second
    sample_rate = 16000
    t = np.linspace(0, duration, int(sample_rate * duration), dtype=np.float32)
    # Generate a simple sine wave at 440Hz
    audio = 0.5 * np.sin(2 * np.pi * 440 * t)
    return audio


@pytest.fixture
def sample_audio_base64(sample_audio_16khz):
    """Generate base64-encoded WAV audio."""
    import base64
    import io

    import soundfile as sf

    buffer = io.BytesIO()
    sf.write(buffer, sample_audio_16khz, 16000, format="WAV")
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode()
