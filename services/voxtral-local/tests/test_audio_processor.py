"""Tests for audio processor module."""

import base64
import sys
from pathlib import Path
from unittest.mock import patch

import numpy as np
import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from audio_processor import AudioProcessor


class TestAudioProcessor:
    """Tests for AudioProcessor class."""

    @pytest.fixture
    def processor(self):
        """Create an AudioProcessor instance."""
        return AudioProcessor()

    def test_init_default_values(self, processor):
        """Test processor initializes with correct defaults."""
        assert processor.sample_rate == 16000
        assert processor.max_duration == 1800  # 30 minutes
        assert processor.chunk_duration == 60  # Default chunk size

    def test_detect_audio_format_wav(self, processor):
        """Test WAV format detection."""
        wav_header = b"RIFF\x00\x00\x00\x00WAVEfmt "
        assert processor._detect_audio_format(wav_header) == "wav"

    def test_detect_audio_format_mp3_id3(self, processor):
        """Test MP3 format detection with ID3 header."""
        mp3_header = b"ID3\x04\x00\x00\x00\x00\x00\x00"
        assert processor._detect_audio_format(mp3_header) == "mp3"

    def test_detect_audio_format_mp3_sync(self, processor):
        """Test MP3 format detection with sync bytes."""
        mp3_header = b"\xff\xfb\x90\x00\x00\x00\x00\x00"
        assert processor._detect_audio_format(mp3_header) == "mp3"

    def test_detect_audio_format_flac(self, processor):
        """Test FLAC format detection."""
        flac_header = b"fLaC\x00\x00\x00\x22"
        assert processor._detect_audio_format(flac_header) == "flac"

    def test_detect_audio_format_ogg(self, processor):
        """Test OGG format detection."""
        ogg_header = b"OggS\x00\x02\x00\x00"
        assert processor._detect_audio_format(ogg_header) == "ogg"

    def test_detect_audio_format_unknown(self, processor):
        """Test unknown format returns 'unknown'."""
        unknown_header = b"\x00\x01\x02\x03\x04\x05"
        assert processor._detect_audio_format(unknown_header) == "unknown"

    def test_normalize_audio_removes_dc_offset(self, processor):
        """Test normalization removes DC offset."""
        # Audio with DC offset of 0.5
        audio = np.array([0.5, 0.6, 0.4, 0.55, 0.45], dtype=np.float32)
        normalized = processor._normalize_audio(audio)
        # Mean should be close to 0 after normalization
        assert abs(np.mean(normalized)) < 0.01

    def test_normalize_audio_scales_to_range(self, processor):
        """Test normalization scales audio to [-0.95, 0.95]."""
        audio = np.array([0.0, 2.0, -2.0, 1.0, -1.0], dtype=np.float32)
        normalized = processor._normalize_audio(audio)
        assert np.max(np.abs(normalized)) <= 0.95

    def test_normalize_audio_handles_silence(self, processor):
        """Test normalization handles silent audio."""
        audio = np.zeros(1000, dtype=np.float32)
        normalized = processor._normalize_audio(audio)
        assert np.allclose(normalized, 0.0)

    def test_chunk_audio_optimized_short_audio(self, processor):
        """Test chunking returns single chunk for short audio."""
        # 10 seconds of audio at 16kHz
        audio = np.random.randn(16000 * 10).astype(np.float32)
        chunks = processor.chunk_audio_optimized(audio)
        assert len(chunks) == 1

    def test_chunk_audio_optimized_long_audio(self, processor):
        """Test chunking splits long audio into multiple chunks."""
        # 3 minutes of audio at 16kHz (longer than 60s chunk)
        audio = np.random.randn(16000 * 180).astype(np.float32)
        chunks = processor.chunk_audio_optimized(audio, chunk_duration=60)
        assert len(chunks) > 1

    def test_chunk_audio_optimized_overlap(self, processor):
        """Test chunks have overlap."""
        # 2 minutes of audio
        audio = np.random.randn(16000 * 120).astype(np.float32)
        chunks = processor.chunk_audio_optimized(
            audio, chunk_duration=60, overlap=1.0
        )
        # With 60s chunks and 1s overlap on 120s audio, expect ~2 chunks
        assert len(chunks) >= 2

    def test_build_prompt_without_context(self, processor):
        """Test prompt building without context."""
        prompt = processor._build_prompt(None, is_chunked=False)
        assert "Transcribe" in prompt
        assert "Context" not in prompt

    def test_build_prompt_with_context(self, processor):
        """Test prompt building with context."""
        prompt = processor._build_prompt("Meeting about Flutter", is_chunked=False)
        assert "Context" in prompt
        assert "Flutter" in prompt

    def test_build_prompt_chunked(self, processor):
        """Test prompt building for chunked audio."""
        prompt = processor._build_prompt(None, is_chunked=True)
        assert "chunk" in prompt.lower()

    def test_get_audio_hash_consistent(self, processor):
        """Test audio hash is consistent for same input."""
        audio = np.random.randn(16000).astype(np.float32)
        hash1 = processor._get_audio_hash(audio)
        hash2 = processor._get_audio_hash(audio)
        assert hash1 == hash2

    def test_get_audio_hash_different_for_different_input(self, processor):
        """Test audio hash differs for different input."""
        audio1 = np.random.randn(16000).astype(np.float32)
        audio2 = np.random.randn(16000).astype(np.float32)
        hash1 = processor._get_audio_hash(audio1)
        hash2 = processor._get_audio_hash(audio2)
        assert hash1 != hash2

    def test_cache_audio_features(self, processor):
        """Test caching audio features."""
        audio = np.random.randn(16000).astype(np.float32)
        features = {"test": "data"}

        audio_hash = processor.cache_audio_features(audio, features)
        assert audio_hash is not None

        cached = processor.get_cached_features(audio)
        assert cached == features

    def test_get_cache_stats(self, processor):
        """Test cache statistics."""
        stats = processor.get_cache_stats()
        assert "cache_size" in stats
        assert "max_size" in stats
        assert "max_age_seconds" in stats

    @pytest.mark.asyncio
    async def test_process_audio_base64_empty_raises(self, processor):
        """Test processing empty base64 raises error."""
        with pytest.raises(ValueError, match="Empty"):
            await processor.process_audio_base64("", request_id="test")

    @pytest.mark.asyncio
    async def test_process_audio_base64_invalid_raises(self, processor):
        """Test processing invalid base64 raises error."""
        with pytest.raises(Exception):
            await processor.process_audio_base64("not-valid-base64!", request_id="test")
