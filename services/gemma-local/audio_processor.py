"""Audio processing utilities for Gemma Local Service."""

import base64
import io
import logging
import hashlib
import time
import tempfile
import os
from pathlib import Path
from typing import Optional, Tuple, Union, List, Dict, Any
import numpy as np

import soundfile as sf
import librosa
import warnings
import torch
import torchaudio
import shutil
import subprocess

from config import ServiceConfig

logger = logging.getLogger(__name__)


class AudioProcessor:
    """Handles audio processing and preparation for model input."""
    
    def __init__(self):
        self.sample_rate = ServiceConfig.AUDIO_SAMPLE_RATE
        self.max_size_mb = ServiceConfig.MAX_AUDIO_SIZE_MB
        self.device = ServiceConfig.DEFAULT_DEVICE
        self.chunk_duration = ServiceConfig.AUDIO_CHUNK_SIZE_SECONDS
        self.overlap = ServiceConfig.AUDIO_OVERLAP_SECONDS
        self.max_duration = ServiceConfig.MAX_AUDIO_DURATION_SECONDS
        
        # Simple in-memory cache for processed audio features
        self._feature_cache: Dict[str, Dict[str, Any]] = {}
        self._cache_max_size = 10  # Keep last 10 processed audio files
        self._cache_max_age = 300  # 5 minutes
        
    async def process_audio_base64(
        self,
        audio_base64: str,
        prompt: Optional[str] = None,
        use_chunking: bool = True,
        request_id: Optional[str] = None
    ) -> Union[Tuple[np.ndarray, str], Tuple[List[np.ndarray], str]]:
        """
        Process base64-encoded audio data.
        
        Args:
            audio_base64: Base64-encoded audio data
            prompt: Optional context prompt
            
        Returns:
            Tuple of (audio_array, combined_prompt)
        """
        try:
            prefix = f"[REQ {request_id}] " if request_id else ""
            t0 = time.perf_counter()
            # Validate base64 format
            if not audio_base64 or len(audio_base64) == 0:
                raise ValueError("Empty audio_base64 data provided")
            
            # Decode base64
            audio_bytes = base64.b64decode(audio_base64)
            t1 = time.perf_counter()
            detected_fmt = self._detect_audio_format(audio_bytes)
            
            # Check size
            size_mb = len(audio_bytes) / (1024 * 1024)
            if size_mb > self.max_size_mb:
                raise ValueError(f"Audio file too large: {size_mb:.1f}MB (max: {self.max_size_mb}MB)")
            
            
            # Load audio from bytes
            audio_array, original_sr = self._load_audio_from_bytes(audio_bytes)
            t2 = time.perf_counter()
            
            # Resample if necessary (prefer torchaudio for speed; fallback to librosa)
            resample_time = 0.0
            if original_sr != self.sample_rate:
                audio_array, resample_time = self._resample_audio(audio_array, original_sr)
            
            # Check duration and apply chunking if needed
            duration = len(audio_array) / self.sample_rate
            
            if duration > self.max_duration:
                raise ValueError(f"Audio too long: {duration:.1f}s (max: {self.max_duration}s)")
            
            # Normalize audio
            t_norm0 = time.perf_counter()
            audio_array = self._normalize_audio(audio_array)
            t_norm1 = time.perf_counter()

            # Use chunking for long audio or if explicitly requested
            chunk_time = 0.0
            is_chunked = use_chunking and duration > self.chunk_duration
            num_chunks = 1
            chunks = None
            if is_chunked:
                t_ck0 = time.perf_counter()
                chunks = self.chunk_audio_optimized(audio_array)
                chunk_time = time.perf_counter() - t_ck0
                num_chunks = len(chunks)

            # Create prompt with audio token
            if prompt:
                combined_prompt = (
                    f"<audio_soft_token>\n\nContext: {prompt}\n\nTranscribe the above audio chunk:" if is_chunked
                    else f"<audio_soft_token>\n\nContext: {prompt}\n\nTranscribe the above audio."
                )
            else:
                combined_prompt = (
                    "<audio_soft_token>\n\nTranscribe the above audio chunk:" if is_chunked
                    else "<audio_soft_token>\n\nTranscribe the above audio."
                )

            logger.info(
                f"{prefix}Audio decoded. bytes={len(audio_bytes)} ({size_mb:.2f}MB) fmt={detected_fmt} sr={original_sr}->{self.sample_rate} "
                f"dur={duration:.1f}s; decode={(t1 - t0):.3f}s load={(t2 - t1):.3f}s resample={resample_time:.3f}s "
                f"normalize={(t_norm1 - t_norm0):.3f}s chunk={chunk_time:.3f}s chunks={num_chunks}"
            )

            if is_chunked:
                return chunks, combined_prompt
            return audio_array, combined_prompt
            
        except Exception as e:
            logger.error(f"Error processing audio: {e}")
            raise
    
    async def process_audio_file(
        self,
        file_path: str,
        prompt: Optional[str] = None,
        use_chunking: bool = True,
        request_id: Optional[str] = None
    ) -> Union[Tuple[np.ndarray, str], Tuple[List[np.ndarray], str]]:
        """
        Process audio from file path.
        
        Args:
            file_path: Path to audio file
            prompt: Optional context prompt
            
        Returns:
            Tuple of (audio_array, combined_prompt)
        """
        try:
            prefix = f"[REQ {request_id}] " if request_id else ""
            t0 = time.perf_counter()
            # Load audio file
            audio_array, original_sr = librosa.load(file_path, sr=None, mono=True)
            t1 = time.perf_counter()
            
            # Resample if necessary (prefer torchaudio for speed; fallback to librosa)
            resample_time = 0.0
            if original_sr != self.sample_rate:
                audio_array, resample_time = self._resample_audio(audio_array, original_sr)
            
            # Check duration and apply chunking if needed
            duration = len(audio_array) / self.sample_rate
            
            if duration > self.max_duration:
                raise ValueError(f"Audio too long: {duration:.1f}s (max: {self.max_duration}s)")
            
            # Normalize audio
            t_norm0 = time.perf_counter()
            audio_array = self._normalize_audio(audio_array)
            t_norm1 = time.perf_counter()
            
            # Use chunking for long audio or if explicitly requested
            chunk_time = 0.0
            is_chunked = use_chunking and duration > self.chunk_duration
            num_chunks = 1
            chunks = None
            if is_chunked:
                t_ck0 = time.perf_counter()
                chunks = self.chunk_audio_optimized(audio_array)
                chunk_time = time.perf_counter() - t_ck0
                num_chunks = len(chunks)

            # Create prompt with audio token
            if prompt:
                combined_prompt = (
                    f"<audio_soft_token>\n\nContext: {prompt}\n\nTranscribe the above audio chunk:" if is_chunked
                    else f"<audio_soft_token>\n\nContext: {prompt}\n\nTranscribe the above audio."
                )
            else:
                combined_prompt = (
                    "<audio_soft_token>\n\nTranscribe the above audio chunk:" if is_chunked
                    else "<audio_soft_token>\n\nTranscribe the above audio."
                )

            logger.info(
                f"{prefix}Loaded file. sr={original_sr}->{self.sample_rate} dur={duration:.1f}s; load={(t1 - t0):.3f}s "
                f"resample={resample_time:.3f}s normalize={(t_norm1 - t_norm0):.3f}s chunk={chunk_time:.3f}s chunks={num_chunks}"
            )

            if is_chunked:
                return chunks, combined_prompt
            return audio_array, combined_prompt
            
        except Exception as e:
            logger.error(f"Error processing audio file: {e}")
            raise
    
    def _detect_audio_format(self, audio_bytes: bytes) -> str:
        """Detect audio format from bytes header."""
        if audio_bytes.startswith(b'RIFF') and b'WAVE' in audio_bytes[:12]:
            return 'wav'
        elif audio_bytes.startswith(b'\x00\x00\x00') and b'ftyp' in audio_bytes[:20]:
            if b'M4A' in audio_bytes[:30] or b'mp4' in audio_bytes[:30]:
                return 'm4a'
        elif audio_bytes.startswith(b'ID3') or audio_bytes.startswith(b'\xff\xfb'):
            return 'mp3'
        elif audio_bytes.startswith(b'fLaC'):
            return 'flac'
        return 'unknown'

    def _load_audio_from_bytes(self, audio_bytes: bytes) -> Tuple[np.ndarray, int]:
        """
        Load audio from bytes.
        
        Args:
            audio_bytes: Raw audio bytes
            
        Returns:
            Tuple of (audio_array, sample_rate)
        """
        
        # Detect format
        format_type = self._detect_audio_format(audio_bytes)
        
        # For M4A/AAC files, we need to write to a temporary file
        if format_type in ['m4a', 'unknown']:
            return self._load_from_temp_file(audio_bytes)
        
        # Try soundfile first (handles WAV, FLAC, etc.)
        try:
            audio_io = io.BytesIO(audio_bytes)
            audio_io.seek(0)  # Ensure we're at the beginning
            audio_array, sample_rate = sf.read(audio_io)
            if len(audio_array.shape) > 1:
                # Convert to mono
                audio_array = np.mean(audio_array, axis=1)
            return audio_array, sample_rate
        except Exception as e:
            pass
        
        # Fallback to torchaudio
        try:
            audio_io = io.BytesIO(audio_bytes)
            audio_io.seek(0)  # Ensure we're at the beginning
            waveform, sample_rate = torchaudio.load(audio_io)
            # Convert to numpy and mono
            audio_array = waveform.mean(dim=0).numpy()
            return audio_array, sample_rate
        except Exception as e:
            pass
        
        # Final fallback: write to temp file and try librosa
        return self._load_from_temp_file(audio_bytes)
    
    def _load_from_temp_file(self, audio_bytes: bytes) -> Tuple[np.ndarray, int]:
        """Load audio using temporary file (for M4A, MP3, etc.)."""
        temp_file_path = None
        temp_wav_path = None
        try:
            # Create temporary file with appropriate extension
            format_type = self._detect_audio_format(audio_bytes)
            suffix = '.m4a' if format_type == 'm4a' else '.audio'
            
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
                temp_file.write(audio_bytes)
                temp_file_path = temp_file.name
            
            # Prefer ffmpeg decode for formats librosa/soundfile struggle with (e.g., m4a)
            try:
                ffmpeg_bin = shutil.which('ffmpeg')
                if ffmpeg_bin and format_type in ('m4a', 'unknown'):
                    with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as wav_out:
                        temp_wav_path = wav_out.name
                    # Decode to 16k mono WAV for consistency
                    cmd = [
                        ffmpeg_bin,
                        '-y', '-hide_banner', '-loglevel', 'error',
                        '-i', temp_file_path,
                        '-ar', str(self.sample_rate),
                        '-ac', '1',
                        temp_wav_path,
                    ]
                    subprocess.run(cmd, check=True)
                    # Read decoded wav via soundfile
                    audio_array, sample_rate = sf.read(temp_wav_path)
                    if len(audio_array.shape) > 1:
                        audio_array = audio_array.mean(axis=1)
                    return audio_array.astype('float32'), sample_rate
            except Exception as e:
                # Fall back to librosa below
                logger.warning(f"ffmpeg decoding failed, falling back to librosa. Error: {e}")

            # Fallback: use librosa with warnings suppressed
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                audio_array, sample_rate = librosa.load(temp_file_path, sr=None, mono=True)
            return audio_array, sample_rate
            
        except Exception as e:
            logger.error(f"Temp file loading failed: {type(e).__name__}: {e}")
            raise ValueError(f"Unable to load audio from bytes. Temp file method failed: {e}")
        finally:
            # Clean up temp file
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.unlink(temp_file_path)
                except Exception as e:
                    logger.warning(f"Failed to clean up temp file: {e}")
            if temp_wav_path and os.path.exists(temp_wav_path):
                try:
                    os.unlink(temp_wav_path)
                except Exception as e:
                    logger.warning(f"Failed to clean up temp wav file: {e}")
    
    def _normalize_audio(self, audio_array: np.ndarray) -> np.ndarray:
        """
        Normalize audio to [-1, 1] range.
        
        Args:
            audio_array: Input audio array
            
        Returns:
            Normalized audio array
        """
        # Remove DC offset
        audio_array = audio_array - np.mean(audio_array)
        
        # Normalize to [-1, 1]
        max_val = np.max(np.abs(audio_array))
        if max_val > 0:
            audio_array = audio_array / max_val * 0.95  # Leave some headroom
        
        return audio_array

    def _resample_audio(self, audio_array: np.ndarray, original_sr: int) -> Tuple[np.ndarray, float]:
        """Resample to target sample rate, return (array, seconds)."""
        if original_sr == self.sample_rate:
            return audio_array, 0.0
        t_rs0 = time.perf_counter()
        try:
            _tensor = torch.from_numpy(audio_array).float()
            _res = torchaudio.functional.resample(_tensor, orig_freq=original_sr, new_freq=self.sample_rate)
            resampled = _res.numpy()
        except Exception:
            resampled = librosa.resample(
                audio_array,
                orig_sr=original_sr,
                target_sr=self.sample_rate
            )
        return resampled, (time.perf_counter() - t_rs0)
    
    def prepare_for_model(
        self,
        audio_array: np.ndarray,
        processor=None
    ) -> Union[torch.Tensor, dict]:
        """
        Prepare audio for model input.
        
        Args:
            audio_array: Normalized audio array
            processor: Model processor (if available)
            
        Returns:
            Model-ready input tensor or dict
        """
        if processor and hasattr(processor, 'feature_extractor'):
            # Use processor's feature extractor if available
            inputs = processor(
                audio=audio_array,
                sampling_rate=self.sample_rate,
                return_tensors="pt"
            )
            return inputs
        else:
            # Convert to tensor
            audio_tensor = torch.from_numpy(audio_array).float()
            if audio_tensor.dim() == 1:
                audio_tensor = audio_tensor.unsqueeze(0)  # Add batch dimension
            return audio_tensor
    
    def chunk_audio_optimized(
        self,
        audio_array: np.ndarray,
        chunk_duration: Optional[float] = None,
        overlap: Optional[float] = None
    ) -> List[np.ndarray]:
        """Split audio into optimized overlapping chunks for CPU processing.
        
        Args:
            audio_array: Input audio array
            chunk_duration: Duration of each chunk in seconds (uses config default)
            overlap: Overlap between chunks in seconds (uses config default)
            
        Returns:
            List of optimized audio chunks
        """
        chunk_duration = chunk_duration or self.chunk_duration
        overlap = overlap or self.overlap
        
        # Respect the model's 30s limit for Gemma 3N
        chunk_duration = min(chunk_duration, 30)  # Max 30s chunks for Gemma 3N
            
        chunk_samples = int(chunk_duration * self.sample_rate)
        overlap_samples = int(overlap * self.sample_rate)
        step_samples = chunk_samples - overlap_samples
        
        chunks = []
        total_duration = len(audio_array) / self.sample_rate
        
        
        for i in range(0, len(audio_array), step_samples):
            chunk = audio_array[i:i + chunk_samples]
            
            # Handle last chunk
            if len(chunk) < chunk_samples:
                if len(chunk) < self.sample_rate * 2:  # Skip chunks shorter than 2 seconds
                    # Merge with previous chunk if it exists
                    if chunks:
                        chunks[-1] = np.concatenate([chunks[-1][:-overlap_samples], chunk])
                    continue
                # Pad to minimum processing size (but don't over-pad)
                min_samples = min(chunk_samples, len(chunk) + overlap_samples)
                chunk = np.pad(chunk, (0, min_samples - len(chunk)), mode='constant')
            
            chunks.append(chunk)
            
        return chunks if chunks else [audio_array]  # Return original if no valid chunks
    
    # Legacy method for backwards compatibility
    def chunk_audio(
        self,
        audio_array: np.ndarray,
        chunk_duration: float = 30.0,
        overlap: float = 2.0
    ) -> List[np.ndarray]:
        """Legacy chunk_audio method - use chunk_audio_optimized instead."""
        return self.chunk_audio_optimized(audio_array, chunk_duration, overlap)


    def _get_audio_hash(self, audio_array: np.ndarray) -> str:
        """Generate hash for audio array for caching."""
        return hashlib.md5(audio_array.tobytes()).hexdigest()[:16]
    
    def _clean_cache(self):
        """Clean old cache entries."""
        current_time = time.time()
        to_remove = []
        
        for key, cache_entry in self._feature_cache.items():
            if current_time - cache_entry['timestamp'] > self._cache_max_age:
                to_remove.append(key)
                
        for key in to_remove:
            del self._feature_cache[key]
            
        # Also limit cache size
        if len(self._feature_cache) > self._cache_max_size:
            # Remove oldest entries
            sorted_items = sorted(
                self._feature_cache.items(), 
                key=lambda x: x[1]['timestamp']
            )
            for key, _ in sorted_items[:-self._cache_max_size]:
                del self._feature_cache[key]
    
    def cache_audio_features(self, audio_array: np.ndarray, features: Any) -> str:
        """Cache processed audio features."""
        self._clean_cache()
        audio_hash = self._get_audio_hash(audio_array)
        
        self._feature_cache[audio_hash] = {
            'features': features,
            'timestamp': time.time(),
            'duration': len(audio_array) / self.sample_rate
        }
        
        return audio_hash
    
    def get_cached_features(self, audio_array: np.ndarray) -> Optional[Any]:
        """Get cached features for audio array."""
        audio_hash = self._get_audio_hash(audio_array)
        cache_entry = self._feature_cache.get(audio_hash)
        
        if cache_entry:
            return cache_entry['features']
            
        return None
    
    def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        self._clean_cache()
        return {
            'cache_size': len(self._feature_cache),
            'max_size': self._cache_max_size,
            'max_age_seconds': self._cache_max_age,
            'total_cached_duration': sum(
                entry['duration'] for entry in self._feature_cache.values()
            )
        }


# Global instance
audio_processor = AudioProcessor()
