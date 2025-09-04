#!/usr/bin/env python3
"""
Performance benchmark script for Gemma Local Service optimizations.

Tests various audio lengths and measures generation speed.
"""

import asyncio
import time
import logging
import numpy as np
from pathlib import Path
import json
from typing import Dict, List, Any

# Add the service directory to the Python path
import sys
sys.path.append(str(Path(__file__).parent))

from config import ServiceConfig
from model_manager import model_manager
from audio_processor import audio_processor

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PerformanceBenchmark:
    """Performance benchmark for audio transcription."""
    
    def __init__(self):
        self.results: List[Dict[str, Any]] = []
        
    def generate_test_audio(self, duration_seconds: float, sample_rate: int = 16000) -> np.ndarray:
        """Generate synthetic test audio (sine wave)."""
        samples = int(duration_seconds * sample_rate)
        t = np.linspace(0, duration_seconds, samples, False)
        # Generate a simple sine wave (440 Hz - A note)
        frequency = 440.0
        audio = 0.3 * np.sin(2 * np.pi * frequency * t)
        return audio.astype(np.float32)
    
    async def benchmark_single_generation(
        self, 
        audio_duration: float, 
        task_type: str = "transcription"
    ) -> Dict[str, Any]:
        """Benchmark a single audio transcription."""
        logger.info(f"Benchmarking {audio_duration}s audio with task_type='{task_type}'")
        
        # Generate test audio
        audio_array = self.generate_test_audio(audio_duration)
        
        # Create test prompt
        prompt = "Transcribe the following audio:"
        
        # Time the processing
        start_time = time.time()
        
        try:
            # Use the processor to prepare inputs
            if audio_array.ndim == 1:
                audio_array = audio_array.reshape(1, -1)
                
            inputs = model_manager.processor(
                audio=audio_array,
                text=prompt,
                sampling_rate=ServiceConfig.AUDIO_SAMPLE_RATE,
                return_tensors="pt"
            )
            
            # Move to device
            inputs = {k: v.to(model_manager.device) if hasattr(v, 'to') else v 
                     for k, v in inputs.items()}
            
            # Get generation config
            gen_config = ServiceConfig.get_generation_config(task_type)
            gen_config.update({
                'pad_token_id': model_manager.tokenizer.pad_token_id or model_manager.tokenizer.eos_token_id,
                'eos_token_id': model_manager.tokenizer.eos_token_id,
            })
            
            # Generate
            generation_start = time.time()
            if model_manager.device == "cpu":
                import torch
                with torch.inference_mode():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
            else:
                import torch
                with torch.no_grad():
                    outputs = model_manager.model.generate(**inputs, **gen_config)
                    
            generation_time = time.time() - generation_start
            
            # Decode output
            input_length = inputs['input_ids'].shape[1] if 'input_ids' in inputs else 0
            response = model_manager.tokenizer.decode(
                outputs[0][input_length:],
                skip_special_tokens=True
            )
            
            total_time = time.time() - start_time
            
            # Calculate metrics
            tokens_generated = len(outputs[0]) - input_length
            tokens_per_second = tokens_generated / generation_time if generation_time > 0 else 0
            audio_processing_ratio = audio_duration / total_time if total_time > 0 else 0
            
            result = {
                'audio_duration_s': audio_duration,
                'task_type': task_type,
                'total_time_s': round(total_time, 3),
                'generation_time_s': round(generation_time, 3),
                'tokens_generated': tokens_generated,
                'tokens_per_second': round(tokens_per_second, 2),
                'audio_processing_ratio': round(audio_processing_ratio, 3),
                'response_length': len(response),
                'response_preview': response[:100] + '...' if len(response) > 100 else response,
                'success': True
            }
            
            logger.info(f"Benchmark result: {tokens_per_second:.2f} tokens/sec, "
                       f"{audio_processing_ratio:.3f}x realtime")
            
        except Exception as e:
            logger.error(f"Benchmark failed: {e}")
            result = {
                'audio_duration_s': audio_duration,
                'task_type': task_type,
                'total_time_s': time.time() - start_time,
                'error': str(e),
                'success': False
            }
        
        return result
    
    async def run_benchmark_suite(self):
        """Run a full benchmark suite."""
        logger.info("Starting performance benchmark suite")
        
        # Ensure model is loaded
        if not model_manager.is_model_loaded():
            logger.info("Loading model...")
            success = await model_manager.load_model()
            if not success:
                logger.error("Failed to load model")
                return
            
            # Warm up model
            logger.info("Warming up model...")
            await model_manager.warm_up()
        
        # Test different audio durations
        test_durations = [5, 15, 30, 60]  # seconds
        task_types = ["transcription", "cpu_optimized", "general"]
        
        for duration in test_durations:
            for task_type in task_types:
                result = await self.benchmark_single_generation(duration, task_type)
                self.results.append(result)
                
                # Small delay between tests
                await asyncio.sleep(1)
        
        # Test chunked processing
        logger.info("Testing chunked audio processing...")
        long_audio = self.generate_test_audio(120)  # 2 minutes
        
        start_time = time.time()
        try:
            chunks = audio_processor.chunk_audio_optimized(long_audio)
            chunk_time = time.time() - start_time
            
            chunk_result = {
                'test_type': 'chunking',
                'original_duration_s': 120,
                'num_chunks': len(chunks),
                'chunk_duration_s': ServiceConfig.AUDIO_CHUNK_SIZE_SECONDS,
                'chunking_time_s': round(chunk_time, 3),
                'success': True
            }
            
            logger.info(f"Chunking test: {len(chunks)} chunks created in {chunk_time:.3f}s")
            
        except Exception as e:
            chunk_result = {
                'test_type': 'chunking',
                'error': str(e),
                'success': False
            }
            
        self.results.append(chunk_result)
        
        # Print summary
        self.print_benchmark_summary()
        
        # Save results
        self.save_results()
    
    def print_benchmark_summary(self):
        """Print benchmark summary."""
        logger.info("\n" + "="*60)
        logger.info("BENCHMARK SUMMARY")
        logger.info("="*60)
        
        successful_results = [r for r in self.results if r.get('success', False)]
        
        if not successful_results:
            logger.info("No successful benchmark results")
            return
        
        # Filter generation results
        gen_results = [r for r in successful_results if 'tokens_per_second' in r]
        
        if gen_results:
            avg_tokens_per_sec = np.mean([r['tokens_per_second'] for r in gen_results])
            avg_processing_ratio = np.mean([r['audio_processing_ratio'] for r in gen_results])
            
            logger.info(f"Average generation speed: {avg_tokens_per_sec:.2f} tokens/second")
            logger.info(f"Average processing ratio: {avg_processing_ratio:.3f}x realtime")
            logger.info(f"Total successful tests: {len(gen_results)}")
            
            # Best performance
            best_result = max(gen_results, key=lambda x: x['tokens_per_second'])
            logger.info(f"\nBest performance:")
            logger.info(f"  Duration: {best_result['audio_duration_s']}s")
            logger.info(f"  Task type: {best_result['task_type']}")
            logger.info(f"  Speed: {best_result['tokens_per_second']:.2f} tokens/sec")
        
        # Chunking results
        chunk_results = [r for r in successful_results if r.get('test_type') == 'chunking']
        if chunk_results:
            chunk_result = chunk_results[0]
            logger.info(f"\nChunking performance:")
            logger.info(f"  120s audio -> {chunk_result['num_chunks']} chunks")
            logger.info(f"  Chunking time: {chunk_result['chunking_time_s']:.3f}s")
    
    def save_results(self):
        """Save benchmark results to file."""
        timestamp = int(time.time())
        filename = f"benchmark_results_{timestamp}.json"
        filepath = Path(__file__).parent / filename
        
        with open(filepath, 'w') as f:
            json.dump({
                'timestamp': timestamp,
                'config': {
                    'model_id': ServiceConfig.MODEL_ID,
                    'device': ServiceConfig.DEFAULT_DEVICE,
                    'torch_dtype': str(ServiceConfig.TORCH_DTYPE),
                    'quantization_enabled': ServiceConfig.ENABLE_CPU_QUANTIZATION,
                    'torch_compile_enabled': ServiceConfig.ENABLE_TORCH_COMPILE,
                },
                'results': self.results
            }, f, indent=2)
        
        logger.info(f"Results saved to: {filepath}")


async def main():
    """Run the benchmark."""
    benchmark = PerformanceBenchmark()
    await benchmark.run_benchmark_suite()


if __name__ == "__main__":
    asyncio.run(main())