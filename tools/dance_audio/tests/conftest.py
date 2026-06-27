"""Pytest configuration and shared fixtures for the dance_audio tool."""

import sys
from pathlib import Path

import numpy as np
import pytest

# Make `import analyze` work from the tool root.
sys.path.insert(0, str(Path(__file__).parent.parent))

import analyze  # noqa: E402  (must follow the sys.path insert above)


@pytest.fixture(autouse=True)
def _guard_real_inference(monkeypatch):
    """Guarantee the suite never runs real Beat This! / torch inference.

    CI installs only the light deps (numpy + librosa, no torch / beat-this), so
    every test must stub the inference. This autouse guard replaces
    ``analyze._run_beat_this`` with a raiser; tests that need beats provide their
    own stub via ``monkeypatch.setattr`` (which overrides this one). A test that
    forgets fails loudly here instead of trying to import torch.
    """

    def _no_real_inference(*args, **kwargs):
        raise AssertionError(
            "Beat This! inference must be mocked in tests "
            "(monkeypatch analyze._run_beat_this); CI has no torch."
        )

    monkeypatch.setattr(analyze, "_run_beat_this", _no_real_inference)


@pytest.fixture
def steady_grid():
    """A clean 4/4 grid: 16 beats at 0.5 s (120 BPM), downbeats every 4 beats.

    Returns (beat_times, downbeat_times) as numpy arrays — the shape
    ``analyze._run_beat_this`` returns, so tests can monkeypatch it directly.
    """
    beats = np.arange(16) * 0.5
    downbeats = beats[::4]
    return beats, downbeats
