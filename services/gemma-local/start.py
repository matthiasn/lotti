#!/usr/bin/env python3
"""Startup script for Gemma Local Service."""

import asyncio
import sys
import logging
from pathlib import Path

import uvicorn

from config import ServiceConfig
from model_manager import model_manager


async def check_dependencies():
    """Check if all dependencies are available."""
    try:
        import torch
        import transformers
        import librosa
        import soundfile
        print(f"✓ PyTorch version: {torch.__version__}")
        print(f"✓ Transformers version: {transformers.__version__}")
        print(f"✓ Device: {ServiceConfig.DEFAULT_DEVICE}")
        return True
    except ImportError as e:
        print(f"✗ Missing dependency: {e}")
        return False


async def setup_directories():
    """Ensure all required directories exist."""
    ServiceConfig.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    ServiceConfig.LOG_DIR.mkdir(parents=True, exist_ok=True)
    print(f"✓ Cache directory: {ServiceConfig.CACHE_DIR}")
    print(f"✓ Log directory: {ServiceConfig.LOG_DIR}")


async def check_model():
    """Check model availability and optionally download."""
    print(f"Checking model: {ServiceConfig.MODEL_ID}")
    
    if model_manager.is_model_available():
        print("✓ Model files found locally")
        return True
    else:
        print("⚠ Model not found locally")
        
        # Ask user if they want to download
        try:
            response = input("Download model now? (y/N): ").strip().lower()
            if response in ['y', 'yes']:
                print("Starting model download...")
                async for progress in model_manager.download_model():
                    if progress.get('progress'):
                        print(f"\rProgress: {progress['progress']:.1f}%", end='', flush=True)
                print("\n✓ Model downloaded successfully")
                return True
            else:
                print("⚠ Model will be downloaded on first request")
                return True
        except KeyboardInterrupt:
            print("\n✗ Setup cancelled by user")
            return False


def main():
    """Main startup function."""
    print("🤖 Gemma Local Service Setup")
    print("=" * 40)
    
    # Run async setup
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        # Check dependencies
        if not loop.run_until_complete(check_dependencies()):
            sys.exit(1)
        
        # Setup directories
        loop.run_until_complete(setup_directories())
        
        # Check model
        if not loop.run_until_complete(check_model()):
            sys.exit(1)
        
        print("\n✓ Setup complete!")
        print(f"Starting server on {ServiceConfig.DEFAULT_HOST}:{ServiceConfig.DEFAULT_PORT}")
        print("\nAPI Documentation: http://localhost:11343/docs")
        print("Health Check: http://localhost:11343/health")
        print("\nPress Ctrl+C to stop the server")
        
    except Exception as e:
        print(f"✗ Setup failed: {e}")
        sys.exit(1)
    finally:
        loop.close()
    
    # Start the server
    uvicorn.run(
        "main:app",
        host=ServiceConfig.DEFAULT_HOST,
        port=ServiceConfig.DEFAULT_PORT,
        log_level=ServiceConfig.LOG_LEVEL.lower(),
        reload=False,
    )


if __name__ == "__main__":
    main()