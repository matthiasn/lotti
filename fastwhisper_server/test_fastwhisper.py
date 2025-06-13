import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

from faster_whisper import WhisperModel
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def transcribe_audio(audio_path: str, model_name: str = "small"):
    """
    Transcribe an audio file using the specified model.
    
    Args:
        audio_path: Path to the audio file
        model_name: Name of the model to use (tiny, base, small, medium, large-v1, large-v2, large-v3)
    """
    try:
        # Log the model name being used
        logger.info(f"Using model: {model_name}")
        
        # Get the model
        try:
            model = WhisperModel(model_name)
            logger.info("Model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load model: {str(e)}")
            return

        # Transcribe
        try:
            logger.info(f"Starting transcription of {audio_path}")
            segments, info = model.transcribe(
                audio_path,
                language=None,  # Auto-detect language
                beam_size=5
            )
            
            # Print detected language
            logger.info(f"Detected language: {info.language}")
            
            # Print transcription
            print("\nTranscription:")
            print("-" * 50)
            for segment in segments:
                print(f"[{segment.start:.1f}s -> {segment.end:.1f}s] {segment.text}")
            print("-" * 50)
            
        except Exception as e:
            logger.error(f"Transcription failed: {str(e)}")
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_fastwhisper.py <audio_file_path> [model_name]")
        sys.exit(1)
        
    audio_path = sys.argv[1]
    model_name = sys.argv[2] if len(sys.argv) > 2 else "small"
    
    if not os.path.exists(audio_path):
        print(f"Error: Audio file not found at {audio_path}")
        sys.exit(1)
        
    transcribe_audio(audio_path, model_name) 