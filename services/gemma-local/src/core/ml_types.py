"""Type definitions for ML models and PyTorch/Transformers components"""

from typing import Protocol, Any, Dict, List, Optional, Union, TypeAlias, TYPE_CHECKING
import numpy as np

if TYPE_CHECKING:
    # Only imported during type checking, not runtime
    from transformers import AutoModelForImageTextToText, AutoTokenizer, AutoProcessor
    import torch
else:
    # Runtime - use Any to avoid heavy import overhead
    AutoModelForImageTextToText = Any
    AutoTokenizer = Any
    AutoProcessor = Any
    torch = Any

# Type aliases for common ML types
TensorLike: TypeAlias = Union[Any, "np.ndarray[Any, Any]", List[float]]  # torch.Tensor when torch is available
TokenIds: TypeAlias = List[int]
ModelConfig: TypeAlias = Dict[str, Any]
GenerationOutput: TypeAlias = Union[Any, Dict[str, Any]]  # torch.Tensor or transformers output


class ModelLike(Protocol):
    """Protocol for ML model objects (PyTorch/Transformers)"""

    def generate(self, **kwargs: Any) -> Any:
        """Generate text/tokens from input"""
        ...

    def eval(self) -> Any:
        """Set model to evaluation mode"""
        ...

    def to(self, device: str) -> Any:
        """Move model to device"""
        ...

    def parameters(self) -> Any:
        """Get model parameters"""
        ...

    @property
    def device(self) -> Any:
        """Get current device"""
        ...


class TokenizerLike(Protocol):
    """Protocol for tokenizer objects"""

    def encode(self, text: str, **kwargs: Any) -> TokenIds:
        """Encode text to tokens"""
        ...

    def decode(self, tokens: TokenIds, **kwargs: Any) -> str:
        """Decode tokens to text"""
        ...

    @property
    def eos_token_id(self) -> Optional[int]:
        """End of sequence token ID"""
        ...

    @property
    def pad_token_id(self) -> Optional[int]:
        """Padding token ID"""
        ...


class ProcessorLike(Protocol):
    """Protocol for processor objects (multimodal)"""

    def __call__(self, *args: Any, **kwargs: Any) -> Any:
        """Process inputs (text, images, audio)"""
        ...

    def apply_chat_template(self, messages: List[Dict[str, Any]], **kwargs: Any) -> str:
        """Apply chat template to messages"""
        ...


# Concrete type hints that can be used throughout the codebase
MLModel = Union[ModelLike, AutoModelForImageTextToText]
MLTokenizer = Union[TokenizerLike, AutoTokenizer]
MLProcessor = Union[ProcessorLike, AutoProcessor]

# Optional types for when models might not be loaded
OptionalModel = Optional[MLModel]
OptionalTokenizer = Optional[MLTokenizer]
OptionalProcessor = Optional[MLProcessor]


class AudioArray(Protocol):
    """Protocol for audio array objects"""

    @property
    def shape(self) -> tuple[int, ...]:
        """Array shape"""
        ...

    def __getitem__(self, key: Any) -> Any:
        """Array indexing"""
        ...


# Audio processing types
AudioData: TypeAlias = Union["np.ndarray[Any, Any]", AudioArray]
AudioChunks: TypeAlias = List[AudioData]
SampleRate: TypeAlias = int
AudioDuration: TypeAlias = float

# Processing results
AudioProcessingResult: TypeAlias = Union[tuple[AudioData, str], tuple[AudioChunks, str]]
