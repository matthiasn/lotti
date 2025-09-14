#!/usr/bin/env python3
"""Example client for testing Gemma Local Service."""

import asyncio
import base64
import httpx
import json
from pathlib import Path


async def test_health():
    """Test health endpoint."""
    async with httpx.AsyncClient() as client:
        response = await client.get("http://localhost:11343/health")
        print("Health Check:", response.json())


async def test_model_list():
    """Test listing models."""
    async with httpx.AsyncClient() as client:
        response = await client.get("http://localhost:11343/v1/models")
        print("Available Models:", json.dumps(response.json(), indent=2))


async def test_model_download():
    """Test model download with progress tracking."""
    async with httpx.AsyncClient(timeout=600.0) as client:
        request_data = {
            "model_name": "gemma-3n-E2B-it",
            "stream": True
        }
        
        print("Starting model download...")
        
        async with client.stream(
            "POST",
            "http://localhost:11343/v1/models/pull",
            json=request_data
        ) as response:
            async for chunk in response.aiter_lines():
                if chunk.startswith("data: "):
                    data_str = chunk[6:]  # Remove "data: " prefix
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        if "progress" in data:
                            print(f"\rProgress: {data['progress']:.1f}% - {data['status']}", end="", flush=True)
                    except json.JSONDecodeError:
                        pass
        print("\nDownload complete!")


async def test_transcription():
    """Test audio transcription."""
    # Create a simple test audio file (1 second of sine wave)
    import numpy as np
    import soundfile as sf
    
    # Generate test audio
    sample_rate = 16000
    duration = 2.0  # 2 seconds
    frequency = 440  # A4 note
    
    t = np.linspace(0, duration, int(sample_rate * duration))
    audio_data = 0.3 * np.sin(2 * np.pi * frequency * t).astype(np.float32)
    
    # Save to temporary file
    test_file = Path("/tmp/test_audio.wav")
    sf.write(test_file, audio_data, sample_rate)
    
    # Read and encode as base64
    with open(test_file, "rb") as f:
        audio_base64 = base64.b64encode(f.read()).decode()
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            "http://localhost:11343/v1/chat/completions",
            json={
                "model": "gemma-3n-E2B-it",
                "messages": [{"role": "user", "content": "Context: This is a test audio file containing a tone.\n\nTranscribe this audio"}],
                "audio": audio_base64,
                "temperature": 0.1
            }
        )
        
        if response.status_code == 200:
            result = response.json()
            transcription = result["choices"][0]["message"]["content"]
            print("Transcription:", transcription)
        else:
            print("Error:", response.status_code, response.text)
    
    # Cleanup
    test_file.unlink(missing_ok=True)


async def test_chat():
    """Test chat completion."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://localhost:11343/v1/chat/completions",
            json={
                "model": "gemma-3n-E2B-it",
                "messages": [
                    {"role": "system", "content": "You are a helpful assistant."},
                    {"role": "user", "content": "What is the capital of France?"}
                ],
                "temperature": 0.7,
                "max_tokens": 100,
                "stream": False
            }
        )
        
        if response.status_code == 200:
            result = response.json()
            print("Chat Response:", result["choices"][0]["message"]["content"])
        else:
            print("Error:", response.status_code, response.text)


async def test_streaming_chat():
    """Test streaming chat completion."""
    async with httpx.AsyncClient() as client:
        request_data = {
            "model": "gemma-3n-E2B-it",
            "messages": [
                {"role": "user", "content": "Tell me a short joke"}
            ],
            "temperature": 0.7,
            "stream": True
        }
        
        print("Streaming chat response:")
        print("Assistant: ", end="", flush=True)
        
        async with client.stream(
            "POST",
            "http://localhost:11343/v1/chat/completions",
            json=request_data
        ) as response:
            async for chunk in response.aiter_lines():
                if chunk.startswith("data: "):
                    data_str = chunk[6:]  # Remove "data: " prefix
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        if "choices" in data and data["choices"]:
                            delta = data["choices"][0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                print(content, end="", flush=True)
                    except json.JSONDecodeError:
                        pass
        print("\n")


async def main():
    """Run all tests."""
    print("🤖 Testing Gemma Local Service")
    print("=" * 40)
    
    try:
        # Test basic connectivity
        await test_health()
        print()
        
        # Test model listing
        await test_model_list()
        print()
        
        # Uncomment to test model download (takes time)
        # await test_model_download()
        # print()
        
        # Test chat completion
        print("Testing chat completion...")
        await test_chat()
        print()
        
        # Test streaming
        print("Testing streaming chat...")
        await test_streaming_chat()
        print()
        
        # Test transcription
        print("Testing audio transcription...")
        await test_transcription()
        
    except httpx.ConnectError:
        print("❌ Could not connect to Gemma service. Make sure it's running on localhost:11343")
    except Exception as e:
        print(f"❌ Test failed: {e}")


if __name__ == "__main__":
    asyncio.run(main())