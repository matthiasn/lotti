#!/usr/bin/env python3
"""Fast transcription using Faster Whisper - production ready solution."""

import sys
import base64
from faster_whisper import WhisperModel
from pydub import AudioSegment
import tempfile
import os

def transcribe_with_faster_whisper(audio_path: str):
    """Transcribe audio using Faster Whisper - much faster than Gemma 3N."""
    
    print(f"Loading {audio_path}...")
    
    # Load audio
    audio = AudioSegment.from_file(audio_path)
    duration_seconds = len(audio) / 1000
    print(f"Audio duration: {duration_seconds:.1f} seconds")
    
    # Convert to mono and standard sample rate
    audio = audio.set_channels(1)
    audio = audio.set_frame_rate(16000)
    
    # Save as temporary WAV file
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
        audio.export(temp_file.name, format='wav')
        temp_path = temp_file.name
    
    try:
        print("Loading Faster Whisper model...")
        # Use CPU-optimized model - much faster than Gemma 3N
        model = WhisperModel("base", device="cpu", compute_type="int8")
        
        print(f"🎯 Transcribing {duration_seconds:.1f}s audio...")
        
        # Transcribe with automatic chunking and speaker detection
        segments, info = model.transcribe(
            temp_path,
            beam_size=5,
            language="en",
            condition_on_previous_text=True,  # This handles continuation between chunks
            vad_filter=True,  # Voice activity detection
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        
        print(f"Detected language: {info.language} (probability: {info.language_probability:.2f})")
        
        # Combine all segments
        full_transcription = []
        for segment in segments:
            print(f"[{segment.start:.1f}s -> {segment.end:.1f}s] {segment.text}")
            full_transcription.append(segment.text.strip())
        
        final_text = " ".join(full_transcription)
        
        print("\n✅ Transcription complete!")
        print("-" * 50)
        print(final_text)
        print("-" * 50)
        
        return final_text
        
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.unlink(temp_path)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python whisper_transcribe.py <audio_file>")
        sys.exit(1)
    
    result = transcribe_with_faster_whisper(sys.argv[1])
    sys.exit(0 if result else 1)