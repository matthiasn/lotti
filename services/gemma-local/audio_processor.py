"""Audio processing utilities for Gemma Local Service."""

import base64
import io
import logging
from typing import Optional, Tuple, Union
import numpy as np

import soundfile as sf
import librosa
import torch
import torchaudio

from config import ServiceConfig

logger = logging.getLogger(__name__)


class AudioProcessor:
    """Handles audio processing and preparation for model input."""
    
    def __init__(self):
        self.sample_rate = ServiceConfig.AUDIO_SAMPLE_RATE
        self.max_size_mb = ServiceConfig.MAX_AUDIO_SIZE_MB
        self.device = ServiceConfig.DEFAULT_DEVICE
        
    async def process_audio_base64(
        self,
        audio_base64: str,
        prompt: Optional[str] = None
    ) -> Tuple[np.ndarray, str]:
        """
        Process base64-encoded audio data.
        
        Args:
            audio_base64: Base64-encoded audio data
            prompt: Optional context prompt
            
        Returns:
            Tuple of (audio_array, combined_prompt)
        """
        try:
            # Decode base64
            audio_bytes = base64.b64decode(audio_base64)
            
            # Check size
            size_mb = len(audio_bytes) / (1024 * 1024)
            if size_mb > self.max_size_mb:
                raise ValueError(f"Audio file too large: {size_mb:.1f}MB (max: {self.max_size_mb}MB)")
            
            # Load audio from bytes
            audio_array, original_sr = self._load_audio_from_bytes(audio_bytes)
            
            # Resample if necessary
            if original_sr != self.sample_rate:
                logger.info(f"Resampling audio from {original_sr}Hz to {self.sample_rate}Hz")
                audio_array = librosa.resample(
                    audio_array,
                    orig_sr=original_sr,
                    target_sr=self.sample_rate
                )
            
            # Normalize audio
            audio_array = self._normalize_audio(audio_array)
            
            # Create prompt with audio placeholder
            if prompt:
                combined_prompt = f"<audio>\n\nContext: {prompt}"
            else:
                combined_prompt = "<audio>\n\nPlease transcribe the above audio."
            
            return audio_array, combined_prompt
            
        except Exception as e:
            logger.error(f"Error processing audio: {e}")
            raise
    
    async def process_audio_file(
        self,
        file_path: str,
        prompt: Optional[str] = None
    ) -> Tuple[np.ndarray, str]:
        """
        Process audio from file path.
        
        Args:
            file_path: Path to audio file
            prompt: Optional context prompt
            
        Returns:
            Tuple of (audio_array, combined_prompt)
        """
        try:
            # Load audio file
            audio_array, original_sr = librosa.load(file_path, sr=None, mono=True)
            
            # Resample if necessary
            if original_sr != self.sample_rate:
                logger.info(f"Resampling audio from {original_sr}Hz to {self.sample_rate}Hz")
                audio_array = librosa.resample(
                    audio_array,
                    orig_sr=original_sr,
                    target_sr=self.sample_rate
                )
            
            # Normalize audio
            audio_array = self._normalize_audio(audio_array)
            
            # Create prompt with audio placeholder
            if prompt:
                combined_prompt = f"<audio>\n\nContext: {prompt}"
            else:
                combined_prompt = "<audio>\n\nPlease transcribe the above audio."
            
            return audio_array, combined_prompt
            
        except Exception as e:
            logger.error(f"Error processing audio file: {e}")
            raise
    
    def _load_audio_from_bytes(self, audio_bytes: bytes) -> Tuple[np.ndarray, int]:
        """
        Load audio from bytes.
        
        Args:
            audio_bytes: Raw audio bytes
            
        Returns:
            Tuple of (audio_array, sample_rate)
        """
        # Try soundfile first (handles most formats)
        try:
            with io.BytesIO(audio_bytes) as audio_io:
                audio_array, sample_rate = sf.read(audio_io)
                if len(audio_array.shape) > 1:
                    # Convert to mono
                    audio_array = np.mean(audio_array, axis=1)
                return audio_array, sample_rate
        except Exception as e:
            logger.debug(f"Soundfile failed, trying torchaudio: {e}")
        
        # Fallback to torchaudio
        try:
            with io.BytesIO(audio_bytes) as audio_io:
                waveform, sample_rate = torchaudio.load(audio_io)
                # Convert to numpy and mono
                audio_array = waveform.mean(dim=0).numpy()
                return audio_array, sample_rate
        except Exception as e:
            logger.debug(f"Torchaudio failed, trying librosa: {e}")
        
        # Final fallback to librosa
        with io.BytesIO(audio_bytes) as audio_io:
            audio_array, sample_rate = librosa.load(audio_io, sr=None, mono=True)
            return audio_array, sample_rate
    
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
    
    def chunk_audio(
        self,
        audio_array: np.ndarray,
        chunk_duration: float = 30.0,
        overlap: float = 2.0
    ) -> list:
        """
        Split audio into overlapping chunks for processing.
        
        Args:
            audio_array: Input audio array
            chunk_duration: Duration of each chunk in seconds
            overlap: Overlap between chunks in seconds
            
        Returns:
            List of audio chunks
        """
        chunk_samples = int(chunk_duration * self.sample_rate)
        overlap_samples = int(overlap * self.sample_rate)
        step_samples = chunk_samples - overlap_samples
        
        chunks = []
        for i in range(0, len(audio_array), step_samples):
            chunk = audio_array[i:i + chunk_samples]
            # Pad last chunk if necessary
            if len(chunk) < chunk_samples and len(chunk) > self.sample_rate:  # At least 1 second
                chunk = np.pad(chunk, (0, chunk_samples - len(chunk)), mode='constant')
            if len(chunk) >= self.sample_rate:  # Skip very short chunks
                chunks.append(chunk)
        
        return chunks if chunks else [audio_array]  # Return original if no valid chunks


# Global instance
audio_processor = AudioProcessor()