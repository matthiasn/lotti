#!/usr/bin/env python3
"""
FastWhisper ASR Command Line Tool

Automatic speech recognition tool using OpenAI Whisper models.
Supports small, medium, and large model variants with optimized performance for
various hardware configurations.
"""

import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"

import sys
import argparse
import logging
import json
import time
from pathlib import Path
from typing import Dict, Any, Optional

import torch
from transformers import pipeline

logger = logging.getLogger(__name__)

# Supported models - only small, medium, large and their variants
SUPPORTED_MODELS = {
    'small': 'openai/whisper-small',
    'small.en': 'openai/whisper-small.en',
    'medium': 'openai/whisper-medium',
    'medium.en': 'openai/whisper-medium.en', 
    'large': 'openai/whisper-large-v3',
    'large-v2': 'openai/whisper-large-v2',
    'large-v3': 'openai/whisper-large-v3'
}

DEFAULT_MODEL = 'large'

def get_optimal_device() -> str:
    """Determine the best device for Whisper inference.
    
    Returns:
        str: Device identifier ('mps', 'cuda:0', or 'cpu')
    """
    if torch.backends.mps.is_available():
        logger.info("MPS (Metal Performance Shaders) is available - using GPU acceleration")
        return "mps"
    elif torch.cuda.is_available():
        logger.info("CUDA is available - using GPU acceleration")
        return "cuda:0"
    else:
        logger.info("No GPU acceleration available, falling back to CPU")
        return "cpu"

def get_optimal_batch_size(device: str) -> int:
    """Determine optimal batch size based on device.
    
    Args:
        device: Device identifier
        
    Returns:
        int: Optimal batch size for the device
    """
    if device == "mps":
        return 2  # Conservative for Mac MPS backend
    elif device.startswith("cuda"):
        return 8  # Higher batch size for CUDA
    else:
        return 1  # CPU processing

def validate_model_name(model_name: str) -> str:
    """Validate and resolve model name to full HuggingFace identifier.
    
    Args:
        model_name: Short model name or full identifier
        
    Returns:
        str: Full HuggingFace model identifier
        
    Raises:
        ValueError: If model is not supported
    """
    if model_name in SUPPORTED_MODELS:
        return SUPPORTED_MODELS[model_name]
    elif model_name in SUPPORTED_MODELS.values():
        return model_name
    else:
        supported_list = ', '.join(SUPPORTED_MODELS.keys())
        raise ValueError(f"Unsupported model '{model_name}'. Supported models: {supported_list}")


def setup_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level.
    
    Args:
        verbose: Enable verbose logging
    """
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def transcribe_audio(
    audio_path: str, 
    model_name: str = DEFAULT_MODEL,
    output_format: str = 'text',
    output_file: Optional[str] = None,
    timestamps: bool = False
) -> Dict[str, Any]:
    """Transcribe an audio file using Whisper with hardware optimization.
    
    Args:
        audio_path: Path to the audio file
        model_name: Model name (short form or full identifier)
        output_format: Output format ('text', 'json')
        output_file: Optional output file path
        timestamps: Include timestamps in output
        
    Returns:
        Dict containing transcription results
        
    Raises:
        FileNotFoundError: If audio file doesn't exist
        ValueError: If model is not supported
    """
    # Validate inputs
    audio_path_obj = Path(audio_path)
    if not audio_path_obj.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")
    
    # Validate and resolve model name
    full_model_name = validate_model_name(model_name)
    logger.info(f"Using model: {full_model_name}")
    
    total_start_time = time.time()
    results = {
        'model': full_model_name,
        'audio_file': str(audio_path_obj.absolute()),
        'transcription': '',
        'timestamps': [],
        'processing_time': 0,
        'device_used': ''
    }
    
    try:
        # Get optimal device and batch size
        device_start = time.time()
        device = get_optimal_device()
        batch_size = get_optimal_batch_size(device)
        device_time = time.time() - device_start
        logger.debug(f"Device detection took {device_time:.2f}s")
        logger.info(f"Using device: {device}, batch_size: {batch_size}")
        results['device_used'] = device
        
        # Initialize the pipeline with optimized settings
        pipe = None
        try:
            pipeline_start = time.time()
            logger.info(f"Loading model {full_model_name} (this may download the model if not cached)...")
            
            # Configure pipeline based on device capabilities
            if device == "cpu":
                pipe = pipeline(
                    "automatic-speech-recognition",
                    full_model_name,
                    device=device
                )
            else:
                pipe = pipeline(
                    "automatic-speech-recognition",
                    full_model_name,
                    torch_dtype=torch.float16,
                    device=device
                )
                
                # Apply BetterTransformer optimization for supported models
                try:
                    pipe.model = pipe.model.to_bettertransformer()
                    logger.info("BetterTransformer optimization applied")
                except Exception as e:
                    logger.warning(f"BetterTransformer optimization failed: {e}")
            
            pipeline_time = time.time() - pipeline_start
            logger.info(f"Pipeline loaded successfully in {pipeline_time:.2f}s on {device}")
            
        except Exception as e:
            logger.error(f"Failed to load pipeline: {str(e)}")
            # Fallback to CPU with basic settings
            try:
                fallback_start = time.time()
                logger.info(f"Falling back to CPU for model {full_model_name}...")
                pipe = pipeline(
                    "automatic-speech-recognition",
                    full_model_name,
                    device="cpu"
                )
                batch_size = 1
                device = "cpu"
                results['device_used'] = device
                pipeline_time = time.time() - fallback_start
                logger.info(f"Fallback to CPU successful in {pipeline_time:.2f}s")
            except Exception as fallback_e:
                logger.error(f"Fallback also failed: {str(fallback_e)}")
                raise RuntimeError(f"Failed to initialize pipeline: {fallback_e}") from fallback_e

        # Transcribe with optimized settings
        if pipe is None:
            raise RuntimeError("Pipeline not initialized")
            
        logger.info(f"Starting transcription of {audio_path}")
        transcription_start = time.time()
        
        outputs = pipe(
            str(audio_path_obj),
            chunk_length_s=30,
            batch_size=batch_size,
            return_timestamps=timestamps,
            generate_kwargs={
                "temperature": 0.0,
                "do_sample": False,
                "num_beams": 1,
            }
        )
        
        transcription_time = time.time() - transcription_start
        total_time = time.time() - total_start_time
        
        logger.info(f"Transcription completed in {transcription_time:.2f}s")
        logger.info(f"Total processing time: {total_time:.2f}s")
        
        results['processing_time'] = total_time
        
        # Process outputs
        if isinstance(outputs, dict):
            results['transcription'] = outputs.get('text', '')
            if 'chunks' in outputs and outputs['chunks']:
                results['timestamps'] = [
                    {
                        'start': chunk.get('timestamp', [0, 0])[0] if chunk.get('timestamp') else 0,
                        'end': chunk.get('timestamp', [0, 0])[1] if chunk.get('timestamp') else 0,
                        'text': chunk.get('text', '')
                    }
                    for chunk in outputs['chunks']
                ]
        else:
            results['transcription'] = str(outputs)
        
        # Handle output
        if output_format == 'json':
            output_data = json.dumps(results, indent=2, ensure_ascii=False)
        else:
            output_data = results['transcription']
        
        if output_file:
            output_path = Path(output_file)
            output_path.write_text(output_data, encoding='utf-8')
            logger.info(f"Output saved to: {output_path}")
        else:
            print("\n" + "=" * 60)
            print("TRANSCRIPTION RESULTS")
            print("=" * 60)
            if output_format == 'json':
                print(output_data)
            else:
                print(output_data)
                if timestamps and results['timestamps']:
                    print("\n" + "-" * 60)
                    print("TIMESTAMPED SEGMENTS")
                    print("-" * 60)
                    for segment in results['timestamps']:
                        start, end, text = segment['start'], segment['end'], segment['text']
                        if start is not None and end is not None:
                            print(f"[{start:.1f}s -> {end:.1f}s] {text}")
            print("=" * 60)
        
        return results
            
    except Exception as e:
        logger.error(f"Transcription failed: {str(e)}")
        raise

def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser.
    
    Returns:
        argparse.ArgumentParser: Configured parser
    """
    parser = argparse.ArgumentParser(
        description='FastWhisper ASR - Automatic Speech Recognition using OpenAI Whisper models',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Supported Models:
  {', '.join(SUPPORTED_MODELS.keys())}

Examples:
  python {Path(__file__).name} audio.wav
  python {Path(__file__).name} audio.mp3 --model medium --timestamps
  python {Path(__file__).name} audio.wav --model large --output-format json --output results.json
  python {Path(__file__).name} audio.wav --verbose
"""
    )
    
    parser.add_argument(
        'audio_file',
        help='Path to the audio file to transcribe'
    )
    
    parser.add_argument(
        '--model', '-m',
        choices=list(SUPPORTED_MODELS.keys()),
        default=DEFAULT_MODEL,
        help=f'Model to use for transcription (default: {DEFAULT_MODEL})'
    )
    
    parser.add_argument(
        '--output-format', '-f',
        choices=['text', 'json'],
        default='text',
        help='Output format (default: text)'
    )
    
    parser.add_argument(
        '--output', '-o',
        help='Output file path (default: print to stdout)'
    )
    
    parser.add_argument(
        '--timestamps', '-t',
        action='store_true',
        help='Include timestamps in output'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    return parser


def main() -> int:
    """Main entry point.
    
    Returns:
        int: Exit code (0 for success, 1 for error)
    """
    parser = create_parser()
    args = parser.parse_args()
    
    setup_logging(args.verbose)
    
    try:
        results = transcribe_audio(
            audio_path=args.audio_file,
            model_name=args.model,
            output_format=args.output_format,
            output_file=args.output,
            timestamps=args.timestamps
        )
        
        logger.info(f"Transcription completed successfully in {results['processing_time']:.2f}s")
        return 0
        
    except KeyboardInterrupt:
        logger.info("\nTranscription interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
