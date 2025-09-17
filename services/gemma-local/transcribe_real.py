#!/usr/bin/env python3
"""Transcribe using the existing server on port 11343."""

import base64
import sys
from transcribe_utils import (
    prepare_audio_for_transcription, 
    check_server_health, 
    transcribe_audio
)


def transcribe_with_existing_server(audio_path: str):
    """Transcribe audio using existing server."""
    
    # Check server health first
    if not check_server_health():
        print("❌ Server not available. Please start the server first.")
        return None
    
    # Prepare audio
    wav_bytes, duration_seconds = prepare_audio_for_transcription(audio_path, max_duration_seconds=240)
    audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')
    print(f"Base64 size: {len(audio_base64)} bytes")
    
    # Send transcription request
    print(f"\n🎯 Transcribing {duration_seconds:.1f}s audio...")
    print("This may take 5-15 minutes on CPU...")
    
    context = "Context: This audio may contain speech, music, or other sounds."
    text = transcribe_audio(
        audio_base64,
        context=context,
        max_tokens=2000,
        timeout=1200
    )
    
    if text:
        print("\n✅ Transcription complete!")
        print("-" * 50)
        print(text)
        print("-" * 50)
        return text
    else:
        print("❌ Transcription failed")
        return None


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python transcribe_real.py <audio_file>")
        sys.exit(1)
    
    result = transcribe_with_existing_server(sys.argv[1])
    sys.exit(0 if result else 1)