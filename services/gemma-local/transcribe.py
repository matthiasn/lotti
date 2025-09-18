#!/usr/bin/env python3
"""Direct transcription script with automatic server startup."""

import subprocess
import time
import base64
import sys
import os
import json
from transcribe_utils import prepare_audio_for_transcription, transcribe_audio


def download_model_if_needed(server_url: str):
    """Check if model is available and download if needed."""
    import requests

    # Check model status
    try:
        response = requests.get(f'{server_url}/health', timeout=5)
        if response.status_code == 200:
            health = response.json()
            if not health.get('model_available', False):
                print("\n📥 Model not found locally. Downloading Gemma 3N model...")
                print("This is a one-time download of ~2.6GB and may take several minutes...")

                # Pull the model
                pull_response = requests.post(
                    f'{server_url}/v1/models/pull',
                    json={'model_name': 'gemma-3n-E2B-it', 'stream': False},
                    timeout=1800  # 30 minutes for download
                )

                if pull_response.status_code == 200:
                    result = pull_response.json()
                    if result.get('status') == 'success':
                        print("✅ Model downloaded successfully!")
                        return True
                    else:
                        print(f"❌ Download failed: {result}")
                        return False
                else:
                    print(f"❌ Download request failed: {pull_response.status_code}")
                    print(f"Response: {pull_response.text}")
                    return False
            else:
                print("✅ Model already available locally")
                return True
    except Exception as e:
        print(f"❌ Error checking model status: {e}")
        return False


def transcribe_with_auto_server(audio_path: str):
    """Transcribe audio, starting server if needed."""

    # Prepare audio
    wav_bytes, duration_seconds = prepare_audio_for_transcription(audio_path, max_duration_seconds=240)
    audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')

    # Start server
    print("\nStarting Gemma service on port 11343...")
    env = os.environ.copy()
    env['PORT'] = '11343'
    # Ensure HF_TOKEN is passed through
    if 'HF_TOKEN' in os.environ:
        env['HF_TOKEN'] = os.environ['HF_TOKEN']
        print(f"✅ Using HF_TOKEN from environment (length: {len(os.environ['HF_TOKEN'])})")
    # Use virtual environment Python if available
    venv_python = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'venv', 'bin', 'python')
    python_executable = venv_python if os.path.exists(venv_python) else sys.executable

    server = subprocess.Popen(
        [python_executable, 'main.py'],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=os.path.dirname(os.path.abspath(__file__))
    )

    # Wait for server
    server_url = 'http://localhost:11343'
    for i in range(30):
        try:
            r = requests.get(f'{server_url}/health', timeout=1)
            if r.status_code == 200:
                print("Server ready!")
                break
        except:
            pass
        time.sleep(1)
    
    try:
        # Check and download model if needed
        if not download_model_if_needed(server_url):
            print("❌ Failed to download model. Cannot proceed with transcription.")
            return

        # Transcribe
        print(f"\n🎯 Transcribing {duration_seconds:.1f}s audio...")
        print("This may take 5-15 minutes on CPU...")

        text = transcribe_audio(
            audio_base64,
            base_url=server_url,
            timeout=1200
        )
        
        if text:
            print("\n✅ Transcription complete!")
            print("-" * 50)
            print(text)
            print("-" * 50)
        else:
            print("❌ Transcription failed")
            
    finally:
        print("\nStopping server...")
        server.terminate()
        server.wait()


if __name__ == '__main__':
    import requests
    if len(sys.argv) != 2:
        print("Usage: python transcribe.py <audio_file>")
        sys.exit(1)
    
    transcribe_with_auto_server(sys.argv[1])