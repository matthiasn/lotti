#!/usr/bin/env python3
"""Direct transcription script that actually works."""

import subprocess
import time
import requests
import base64
import sys
from pydub import AudioSegment

def transcribe_audio(audio_path: str):
    print(f"Loading {audio_path}...")
    
    # Load and convert audio to WAV (avoids M4A issues)
    audio = AudioSegment.from_file(audio_path)
    duration_seconds = len(audio) / 1000
    print(f"Original duration: {duration_seconds:.1f} seconds")
    
    # Trim to 4 minutes if longer than 5 minutes (service limit)
    if duration_seconds > 300:
        print(f"Trimming to 240 seconds (service limit is 300s)...")
        audio = audio[:240000]  # 4 minutes
        duration_seconds = 240
    
    # Convert to WAV
    wav_bytes = audio.export(format='wav').read()
    audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')
    print(f"Converted to WAV: {len(wav_bytes)} bytes")
    
    # Start server
    print("Starting Gemma service...")
    server = subprocess.Popen(
        [sys.executable, 'main.py'],
        env={'PORT': '11350'},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    
    # Wait for server
    for i in range(30):
        try:
            r = requests.get('http://localhost:11350/health', timeout=1)
            if r.status_code == 200:
                print("Server ready!")
                break
        except:
            pass
        time.sleep(1)
    
    try:
        print("Sending transcription request...")
        print("This will take 7-10 minutes on CPU...")
        
        start = time.time()
        response = requests.post(
            'http://localhost:11350/v1/chat/completions',
            json={
                'model': 'gemma-3n-E2B-it',
                'messages': [{'role': 'user', 'content': 'Transcribe this audio'}],
                'audio': audio_base64,
                'temperature': 0.1
            },
            timeout=1200  # 20 minutes
        )
        
        elapsed = time.time() - start
        
        if response.status_code == 200:
            result = response.json()
            transcription = result['choices'][0]['message']['content']
            print("\n" + "="*60)
            print("✅ SUCCESS!")
            print("="*60)
            print(f"Duration: {duration_seconds:.1f}s")
            print(f"Processing time: {elapsed:.1f}s")
            print(f"\nTRANSCRIPTION:\n{transcription}")
            print("="*60)
            return transcription
        else:
            print(f"❌ FAILED: {response.status_code}")
            print(f"Error: {response.text}")
            return None
            
    finally:
        server.terminate()
        server.wait()

if __name__ == "__main__":
    audio_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/night_watch.m4a"
    transcribe_audio(audio_file)