#!/usr/bin/env python3
"""Test with minimal audio to isolate the issue."""

import requests
import base64
import numpy as np
import soundfile as sf
import io

# Create a tiny test audio (1 second of silence)
print("Creating 1-second test audio...")
sample_rate = 16000
duration = 1  # 1 second
samples = np.zeros(int(sample_rate * duration))

# Convert to WAV bytes
wav_buffer = io.BytesIO()
sf.write(wav_buffer, samples, sample_rate, format='WAV')
wav_bytes = wav_buffer.getvalue()
audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')

print(f"Test audio size: {len(wav_bytes)} bytes")
print(f"Base64 size: {len(audio_base64)} bytes")

# Test the server
print("\n1. Testing health endpoint...")
try:
    response = requests.get('http://localhost:11343/health', timeout=5)
    print(f"Health check: {response.json()}")
except Exception as e:
    print(f"Health check failed: {e}")
    exit(1)

print("\n2. Testing transcription with tiny audio...")
try:
    response = requests.post(
        'http://localhost:11343/v1/chat/completions',
        json={
            'model': 'gemma-3n-E2B-it',
            'messages': [{'role': 'user', 'content': 'Transcribe this audio'}],
            'audio': audio_base64,
            'temperature': 0.1,
            'max_tokens': 50
        },
        timeout=60  # 1 minute timeout for tiny audio
    )
    
    if response.status_code == 200:
        result = response.json()
        print(f"✅ SUCCESS! Response: {result['choices'][0]['message']['content']}")
    else:
        print(f"❌ Failed: {response.status_code}")
        print(f"Error: {response.text}")
except requests.exceptions.Timeout:
    print("❌ Request timed out after 60 seconds")
except Exception as e:
    print(f"❌ Error: {e}")