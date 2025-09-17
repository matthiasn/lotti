#!/usr/bin/env python3
"""Debug audio chunking logic."""

import asyncio
import base64
from audio_processor import audio_processor
from config import ServiceConfig

async def debug_chunking():
    # Load the same audio file
    audio_path = "/Users/gbjohnson/Desktop/audioTesting.m4a"
    
    print(f"Audio chunk duration: {ServiceConfig.AUDIO_CHUNK_SIZE_SECONDS}s")
    print(f"Audio overlap: {ServiceConfig.AUDIO_OVERLAP_SECONDS}s")
    
    # Read and encode audio
    from pydub import AudioSegment
    audio = AudioSegment.from_file(audio_path)
    duration_seconds = len(audio) / 1000
    print(f"Audio duration: {duration_seconds:.1f} seconds")
    
    wav_bytes = audio.export(format='wav').read()
    audio_base64 = base64.b64encode(wav_bytes).decode('utf-8')
    
    print(f"Audio size: {len(wav_bytes)} bytes")
    print(f"Base64 size: {len(audio_base64)} bytes")
    
    # Test audio processing
    try:
        result = await audio_processor.process_audio_base64(
            audio_base64,
            prompt=None,
            use_chunking=True
        )
        
        if isinstance(result[0], list):
            chunks, combined_prompt = result
            print(f"✅ Chunking enabled - created {len(chunks)} chunks")
            for i, chunk in enumerate(chunks):
                chunk_duration = len(chunk) / ServiceConfig.AUDIO_SAMPLE_RATE
                print(f"  Chunk {i+1}: {chunk_duration:.1f}s ({len(chunk)} samples)")
        else:
            audio_array, combined_prompt = result
            array_duration = len(audio_array) / ServiceConfig.AUDIO_SAMPLE_RATE
            print(f"❌ No chunking - single array: {array_duration:.1f}s")
            
        print(f"Combined prompt: {combined_prompt}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_chunking())