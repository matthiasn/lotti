#!/usr/bin/env python3
"""
Quick test script to verify the API fix works with JSON requests.
"""

import requests
import json
import base64
import numpy as np
import soundfile as sf
from io import BytesIO

def generate_test_audio():
    """Generate a short test audio file."""
    # Generate 5 seconds of 440Hz sine wave
    duration = 5  # seconds
    sample_rate = 16000
    t = np.linspace(0, duration, duration * sample_rate, False)
    audio = 0.3 * np.sin(2 * np.pi * 440 * t)
    
    # Convert to bytes using soundfile
    buffer = BytesIO()
    sf.write(buffer, audio, sample_rate, format='WAV')
    buffer.seek(0)
    return buffer.getvalue()

def test_json_request():
    """Test the JSON request format that the Dart client uses."""
    print("Testing JSON request format...")
    
    # Generate test audio
    audio_bytes = generate_test_audio()
    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
    
    # Create request body like the Dart client does
    request_body = {
        'audio': audio_base64,
        'model': 'gemma-2b',
        'prompt': 'Test transcription',
        'temperature': 0.7,
        'response_format': 'json',
        'stream': False
    }
    
    try:
        # Send JSON request
        response = requests.post(
            'http://localhost:11343/v1/audio/transcriptions',
            headers={'Content-Type': 'application/json'},
            json=request_body,
            timeout=30
        )
        
        print(f"Response status: {response.status_code}")
        print(f"Response headers: {dict(response.headers)}")
        
        if response.status_code == 200:
            print("SUCCESS: API accepts JSON requests!")
            result = response.json()
            print(f"Response: {result}")
        else:
            print(f"ERROR: {response.status_code}")
            print(f"Error body: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("ERROR: Could not connect to service. Make sure it's running on localhost:11343")
    except Exception as e:
        print(f"ERROR: {e}")

def test_form_request():
    """Test the traditional form request for comparison."""
    print("\nTesting form request format...")
    
    # Generate test audio
    audio_bytes = generate_test_audio()
    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
    
    try:
        # Send form data request
        response = requests.post(
            'http://localhost:11343/v1/audio/transcriptions',
            data={
                'audio': audio_base64,
                'model': 'gemma-2b',
                'prompt': 'Test transcription',
                'temperature': 0.7,
                'response_format': 'json',
                'stream': False
            },
            timeout=30
        )
        
        print(f"Response status: {response.status_code}")
        
        if response.status_code == 200:
            print("SUCCESS: API accepts form requests!")
            result = response.json()
            print(f"Response: {result}")
        else:
            print(f"ERROR: {response.status_code}")
            print(f"Error body: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("ERROR: Could not connect to service. Make sure it's running on localhost:11343")
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    print("API Test Script")
    print("===============")
    print("This script tests both JSON and form request formats")
    print("Make sure the Gemma service is running on localhost:11343")
    print()
    
    test_json_request()
    test_form_request()