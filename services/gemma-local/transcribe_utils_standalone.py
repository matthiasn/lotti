#!/usr/bin/env python3
"""Standalone transcription utility using running server."""

import sys
import base64
import requests
import os
from transcribe_utils import prepare_audio_for_transcription


def transcribe_file(audio_path: str, server_url: str = "http://localhost:11343"):
    """Transcribe audio file using running server."""

    print(f"📁 Loading audio: {os.path.basename(audio_path)}")

    try:
        # Prepare audio
        wav_bytes, duration_seconds = prepare_audio_for_transcription(
            audio_path,
            max_duration_seconds=240  # 4 minute limit
        )
        audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')

        print(f"⏱️  Audio duration: {duration_seconds:.1f} seconds")
        print(f"📊 Audio size: {len(wav_bytes):,} bytes")
        print("")
        print("🔄 Sending to Gemma 3N for transcription...")
        print("   (This will take 3-4 minutes per 30-second chunk)")
        print("")

        # Send to server
        response = requests.post(
            f'{server_url}/v1/chat/completions',
            json={
                'model': 'gemma-3n-E2B-it',
                'messages': [{'role': 'user', 'content': 'Transcribe this audio'}],
                'audio': audio_base64,
                'temperature': 0.1,
                'max_tokens': 2000
            },
            timeout=1800  # 30 minute timeout
        )

        if response.status_code == 200:
            result = response.json()
            transcription = result['choices'][0]['message']['content']

            print("=" * 80)
            print("📝 TRANSCRIPTION RESULT")
            print("=" * 80)
            print(transcription)
            print("=" * 80)
            print(f"✅ Transcribed {duration_seconds:.1f}s audio successfully!")

            return transcription
        else:
            print(f"❌ Server error: {response.status_code}")
            print(f"Response: {response.text}")
            return None

    except requests.exceptions.Timeout:
        print("❌ Transcription timed out (over 30 minutes)")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python transcribe_utils_standalone.py <audio_file>")
        sys.exit(1)

    audio_file = os.path.expanduser(sys.argv[1])
    if not os.path.exists(audio_file):
        print(f"Error: File '{audio_file}' not found")
        sys.exit(1)

    transcribe_file(audio_file)