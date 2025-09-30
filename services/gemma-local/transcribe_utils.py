"""Common utilities for transcription scripts."""

import requests
from typing import Optional, Tuple
from pydub import AudioSegment


def prepare_audio_for_transcription(
    audio_path: str, max_duration_seconds: int = 240, target_sample_rate: int = 16000
) -> Tuple[bytes, float]:
    """
    Load and prepare audio file for transcription.

    Args:
        audio_path: Path to the audio file
        max_duration_seconds: Maximum duration to process (default 240s/4min)
        target_sample_rate: Target sample rate (default 16000 Hz)

    Returns:
        Tuple of (wav_bytes, duration_seconds)
    """
    # Load audio file
    audio = AudioSegment.from_file(audio_path)
    duration_seconds = len(audio) / 1000

    # Trim if too long
    if duration_seconds > max_duration_seconds:
        print(f"Trimming to {max_duration_seconds} seconds...")
        audio = audio[: max_duration_seconds * 1000]
        duration_seconds = max_duration_seconds

    # Convert to mono and standard sample rate
    audio = audio.set_channels(1)
    audio = audio.set_frame_rate(target_sample_rate)

    # Convert to WAV
    wav_bytes = audio.export(format="wav").read()

    return wav_bytes, duration_seconds


def check_server_health(base_url: str = "http://localhost:11343") -> bool:
    """
    Check if the transcription server is healthy.

    Args:
        base_url: Server URL

    Returns:
        True if server is healthy, False otherwise
    """
    print(f"\nChecking server at {base_url}...")
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        health = response.json()
        print(f"Server status: {health}")
        return health.get("status") == "healthy"
    except Exception as e:
        print(f"❌ Server not accessible: {e}")
        return False


def transcribe_audio(
    audio_base64: str,
    base_url: str = "http://localhost:11343",
    model: str = "gemma-3n-E2B-it",
    context: Optional[str] = None,
    temperature: float = 0.1,
    max_tokens: int = 2000,
    timeout: int = 1200,
) -> Optional[str]:
    """
    Send audio to transcription server.

    Args:
        audio_base64: Base64 encoded audio data
        base_url: Server URL
        model: Model name
        context: Optional context for transcription
        temperature: Generation temperature
        max_tokens: Maximum tokens to generate
        timeout: Request timeout in seconds

    Returns:
        Transcribed text or None on error
    """
    prompt = "Transcribe this audio"
    if context:
        prompt = f"{context}\n\n{prompt}"

    response = requests.post(
        f"{base_url}/v1/chat/completions",
        json={
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "audio": audio_base64,
            "temperature": temperature,
            "max_tokens": max_tokens,
        },
        timeout=timeout,
    )

    if response.status_code == 200:
        result = response.json()
        return result["choices"][0]["message"]["content"]
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.text)
        return None
