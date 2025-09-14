#!/usr/bin/env python3
"""
Comprehensive test suite for Gemma Audio Transcription Service.

Usage:
    python test_transcription.py --model e2b --audio sample.wav
    python test_transcription.py --run-all
"""

import argparse
import asyncio
import base64
import json
import logging
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from unittest.mock import patch

import numpy as np
import requests
import soundfile as sf
from pydub import AudioSegment

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class GemmaServiceTester:
    """Test suite for Gemma transcription service."""
    
    def __init__(self, host: str = "localhost", port: int = 11343, model_variant: str = "E2B"):
        self.host = host
        self.port = port
        self.base_url = f"http://{host}:{port}"
        self.model_variant = model_variant.upper()
        self.server_process = None
        
    def create_test_audio(self, duration: float = 3.0, sample_rate: int = 16000) -> Tuple[np.ndarray, bytes]:
        """Create a test audio signal (sine wave)."""
        t = np.linspace(0, duration, int(sample_rate * duration))
        frequency = 440  # A4 note
        audio = np.sin(2 * np.pi * frequency * t) * 0.5
        
        # Save to temporary WAV file and read back as bytes
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            sf.write(tmp_file.name, audio, sample_rate)
            tmp_file.flush()
            with open(tmp_file.name, 'rb') as f:
                audio_bytes = f.read()
            os.unlink(tmp_file.name)
            
        return audio, audio_bytes
    
    def start_server(self) -> bool:
        """Start the Gemma service server."""
        logger.info(f"Starting Gemma service with model variant: {self.model_variant}")
        
        env = os.environ.copy()
        env['GEMMA_MODEL_VARIANT'] = self.model_variant
        env['PORT'] = str(self.port)
        env['LOG_LEVEL'] = 'INFO'
        
        try:
            # Start the server process
            self.server_process = subprocess.Popen(
                [sys.executable, 'main.py'],
                cwd=Path(__file__).parent,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            
            # Wait for server to be ready
            max_retries = 30
            for i in range(max_retries):
                try:
                    response = requests.get(f"{self.base_url}/health", timeout=1)
                    if response.status_code == 200:
                        logger.info("Server is ready!")
                        return True
                except requests.exceptions.RequestException:
                    pass
                
                time.sleep(1)
                
                # Check if process has terminated
                if self.server_process.poll() is not None:
                    stdout, _ = self.server_process.communicate()
                    logger.error(f"Server process terminated unexpectedly:\n{stdout}")
                    return False
            
            logger.error("Server failed to start within timeout")
            return False
            
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            return False
    
    def stop_server(self):
        """Stop the Gemma service server."""
        if self.server_process:
            logger.info("Stopping server...")
            self.server_process.terminate()
            try:
                self.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.server_process.kill()
                self.server_process.wait()
            self.server_process = None
    
    def test_health_check(self) -> bool:
        """Test the health check endpoint."""
        logger.info("Testing health check endpoint...")
        try:
            response = requests.get(f"{self.base_url}/health")
            assert response.status_code == 200
            data = response.json()
            assert 'status' in data
            assert data['status'] == 'healthy'
            logger.info("✓ Health check passed")
            return True
        except Exception as e:
            logger.error(f"✗ Health check failed: {e}")
            return False
    
    def test_model_download(self) -> bool:
        """Test automatic model downloading."""
        logger.info("Testing model download...")
        try:
            # Check if model is available
            response = requests.get(f"{self.base_url}/v1/models")
            models = response.json()
            
            if not models['data']:
                logger.info("Model not available, triggering download...")
                
                # Trigger model download
                response = requests.post(
                    f"{self.base_url}/v1/models/pull",
                    json={"model_name": f"gemma-3n-{self.model_variant}-it", "stream": False}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get('status') == 'complete':
                        logger.info("✓ Model download completed")
                        return True
                    else:
                        logger.error(f"✗ Model download failed: {result}")
                        return False
            else:
                logger.info("✓ Model already available")
                return True
                
        except Exception as e:
            logger.error(f"✗ Model download test failed: {e}")
            return False
    
    def test_audio_transcription(self, audio_file: Optional[str] = None) -> bool:
        """Test audio transcription."""
        logger.info("Testing audio transcription...")
        try:
            # Use provided audio file or create test audio
            if audio_file and Path(audio_file).exists():
                with open(audio_file, 'rb') as f:
                    audio_bytes = f.read()
                logger.info(f"Using audio file: {audio_file}")
            else:
                logger.info("Creating test audio...")
                _, audio_bytes = self.create_test_audio()
            
            # Encode audio to base64
            audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
            
            # Send transcription request
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json={
                    "model": f"gemma-3n-{self.model_variant}-it",
                    "messages": [
                        {
                            "role": "user",
                            "content": "Transcribe this audio"
                        }
                    ],
                    "audio": audio_base64,
                    "temperature": 0.1
                },
                timeout=600  # 10 minutes for CPU transcription
            )
            
            assert response.status_code == 200
            result = response.json()
            assert 'choices' in result
            assert len(result['choices']) > 0
            transcription = result['choices'][0]['message']['content']
            logger.info(f"✓ Transcription successful: {transcription[:100]}...")
            return True
            
        except Exception as e:
            logger.error(f"✗ Audio transcription failed: {e}")
            return False
    
    def test_context_aware_transcription(self, audio_file: Optional[str] = None) -> bool:
        """Test context-aware transcription."""
        logger.info("Testing context-aware transcription...")
        try:
            # Use provided audio file or create test audio
            if audio_file and Path(audio_file).exists():
                with open(audio_file, 'rb') as f:
                    audio_bytes = f.read()
            else:
                _, audio_bytes = self.create_test_audio()
            
            audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
            
            # Send request with context
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json={
                    "model": f"gemma-3n-{self.model_variant}-it",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are transcribing a technical discussion about AI models."
                        },
                        {
                            "role": "user",
                            "content": "Context: This is a discussion about neural networks.\n\nTranscribe this audio"
                        }
                    ],
                    "audio": audio_base64,
                    "temperature": 0.1,
                    "language": "en"
                },
                timeout=600  # 10 minutes for CPU transcription
            )
            
            assert response.status_code == 200
            result = response.json()
            transcription = result['choices'][0]['message']['content']
            logger.info(f"✓ Context-aware transcription successful: {transcription[:100]}...")
            return True
            
        except Exception as e:
            logger.error(f"✗ Context-aware transcription failed: {e}")
            return False
    
    def test_multiple_formats(self) -> bool:
        """Test transcription with different audio formats."""
        logger.info("Testing multiple audio formats...")
        formats = ['wav', 'mp3', 'm4a']
        success = True
        
        for fmt in formats:
            try:
                logger.info(f"Testing {fmt} format...")
                
                # Create test audio in specific format
                audio, _ = self.create_test_audio()
                
                with tempfile.NamedTemporaryFile(suffix=f'.{fmt}', delete=False) as tmp_file:
                    if fmt == 'wav':
                        sf.write(tmp_file.name, audio, 16000)
                    else:
                        # Use pydub for other formats
                        audio_segment = AudioSegment(
                            audio.tobytes(),
                            frame_rate=16000,
                            sample_width=audio.dtype.itemsize,
                            channels=1
                        )
                        audio_segment.export(tmp_file.name, format=fmt)
                    
                    tmp_file.flush()
                    
                    # Test transcription
                    if self.test_audio_transcription(tmp_file.name):
                        logger.info(f"✓ {fmt} format supported")
                    else:
                        logger.error(f"✗ {fmt} format failed")
                        success = False
                    
                    os.unlink(tmp_file.name)
                    
            except Exception as e:
                logger.error(f"✗ Failed to test {fmt} format: {e}")
                success = False
        
        return success
    
    def test_error_handling(self) -> bool:
        """Test error handling for invalid inputs."""
        logger.info("Testing error handling...")
        tests_passed = True
        
        # Test 1: Invalid audio data
        try:
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json={
                    "model": f"gemma-3n-{self.model_variant}-it",
                    "messages": [{"role": "user", "content": "Test"}],
                    "audio": "invalid_base64_data"
                }
            )
            if response.status_code >= 400:
                logger.info("✓ Invalid audio data handled correctly")
            else:
                logger.error("✗ Invalid audio data not rejected")
                tests_passed = False
        except Exception as e:
            logger.error(f"✗ Error handling test 1 failed: {e}")
            tests_passed = False
        
        # Test 2: Too large file
        try:
            # Create large audio (simulate)
            large_audio = np.zeros(16000 * 600)  # 10 minutes
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
                sf.write(tmp_file.name, large_audio, 16000)
                tmp_file.flush()
                
                # Check file size
                file_size_mb = os.path.getsize(tmp_file.name) / (1024 * 1024)
                
                if file_size_mb > 50:  # Assuming 50MB limit
                    with open(tmp_file.name, 'rb') as f:
                        audio_bytes = f.read()
                    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
                    
                    response = requests.post(
                        f"{self.base_url}/v1/chat/completions",
                        json={
                            "model": f"gemma-3n-{self.model_variant}-it",
                            "messages": [{"role": "user", "content": "Test"}],
                            "audio": audio_base64
                        }
                    )
                    
                    if response.status_code >= 400:
                        logger.info("✓ Large file rejected correctly")
                    else:
                        logger.error("✗ Large file not rejected")
                        tests_passed = False
                
                os.unlink(tmp_file.name)
                
        except Exception as e:
            logger.error(f"✗ Error handling test 2 failed: {e}")
            tests_passed = False
        
        return tests_passed
    
    def test_streaming_response(self) -> bool:
        """Test streaming response for chat completions."""
        logger.info("Testing streaming response...")
        try:
            response = requests.post(
                f"{self.base_url}/v1/chat/completions",
                json={
                    "model": f"gemma-3n-{self.model_variant}-it",
                    "messages": [
                        {"role": "user", "content": "Say hello"}
                    ],
                    "stream": True
                },
                stream=True,
                timeout=30
            )
            
            assert response.status_code == 200
            
            # Read streaming response
            chunks = []
            for line in response.iter_lines():
                if line:
                    line_str = line.decode('utf-8')
                    if line_str.startswith('data: '):
                        data_str = line_str[6:]
                        if data_str != '[DONE]':
                            chunks.append(json.loads(data_str))
            
            assert len(chunks) > 0
            logger.info(f"✓ Streaming response successful, received {len(chunks)} chunks")
            return True
            
        except Exception as e:
            logger.error(f"✗ Streaming response failed: {e}")
            return False
    
    def run_all_tests(self, audio_file: Optional[str] = None) -> Dict[str, bool]:
        """Run all tests and return results."""
        results = {}
        
        # Start server
        if not self.start_server():
            logger.error("Failed to start server, aborting tests")
            return {"server_start": False}
        
        try:
            # Run tests
            results['health_check'] = self.test_health_check()
            results['model_download'] = self.test_model_download()
            results['audio_transcription'] = self.test_audio_transcription(audio_file)
            results['context_aware'] = self.test_context_aware_transcription(audio_file)
            results['streaming'] = self.test_streaming_response()
            results['error_handling'] = self.test_error_handling()
            
            # Only test multiple formats if no specific audio file provided
            if not audio_file:
                results['multiple_formats'] = self.test_multiple_formats()
            
        finally:
            self.stop_server()
        
        return results


def main():
    """Main entry point for test suite."""
    parser = argparse.ArgumentParser(description='Test Gemma Audio Transcription Service')
    parser.add_argument('--model', choices=['e2b', 'e4b', 'E2B', 'E4B'], 
                       default='E2B', help='Model variant to use')
    parser.add_argument('--audio', type=str, help='Path to audio file for testing')
    parser.add_argument('--host', default='localhost', help='Server host')
    parser.add_argument('--port', type=int, default=11343, help='Server port')
    parser.add_argument('--run-all', action='store_true', help='Run all tests')
    parser.add_argument('--test', choices=['health', 'download', 'transcribe', 'context', 
                                          'streaming', 'errors', 'formats'],
                       help='Run specific test')
    
    args = parser.parse_args()
    
    # Initialize tester
    tester = GemmaServiceTester(
        host=args.host,
        port=args.port,
        model_variant=args.model.upper()
    )
    
    # Run tests
    if args.run_all:
        logger.info("Running all tests...")
        results = tester.run_all_tests(args.audio)
        
        # Print summary
        print("\n" + "="*50)
        print("TEST RESULTS SUMMARY")
        print("="*50)
        
        total = len(results)
        passed = sum(1 for v in results.values() if v)
        
        for test_name, result in results.items():
            status = "✓ PASSED" if result else "✗ FAILED"
            print(f"{test_name:.<30} {status}")
        
        print("="*50)
        print(f"Total: {passed}/{total} tests passed")
        
        sys.exit(0 if passed == total else 1)
        
    elif args.test:
        # Run specific test
        if not tester.start_server():
            logger.error("Failed to start server")
            sys.exit(1)
        
        try:
            test_map = {
                'health': tester.test_health_check,
                'download': tester.test_model_download,
                'transcribe': lambda: tester.test_audio_transcription(args.audio),
                'context': lambda: tester.test_context_aware_transcription(args.audio),
                'streaming': tester.test_streaming_response,
                'errors': tester.test_error_handling,
                'formats': tester.test_multiple_formats
            }
            
            result = test_map[args.test]()
            sys.exit(0 if result else 1)
            
        finally:
            tester.stop_server()
    
    else:
        # Default: test transcription with provided audio
        if args.audio:
            if not tester.start_server():
                logger.error("Failed to start server")
                sys.exit(1)
            
            try:
                result = tester.test_audio_transcription(args.audio)
                sys.exit(0 if result else 1)
            finally:
                tester.stop_server()
        else:
            logger.error("Please provide --audio file or use --run-all")
            sys.exit(1)


if __name__ == "__main__":
    main()