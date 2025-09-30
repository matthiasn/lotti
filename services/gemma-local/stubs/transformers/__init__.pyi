"""Type stubs for HuggingFace Transformers library.

These stubs provide type hints for the transformers library to help MyPy
understand the structure of dynamically loaded classes.
"""

from typing import Any, Dict, List, Optional, Union, Tuple
import torch
from pathlib import Path


class AutoProcessor:
    """Type stub for AutoProcessor from transformers."""

    def __call__(
        self,
        text: Optional[Union[str, List[str]]] = None,
        images: Optional[Any] = None,
        audio: Optional[Any] = None,
        sampling_rate: Optional[int] = None,
        return_tensors: Optional[str] = None,
        padding: Optional[Union[bool, str]] = None,
        truncation: Optional[bool] = None,
        max_length: Optional[int] = None,
        **kwargs: Any
    ) -> Dict[str, Any]: ...

    def apply_chat_template(
        self,
        conversation: List[Dict[str, str]],
        tokenize: bool = False,
        add_generation_prompt: bool = False,
        **kwargs: Any
    ) -> str: ...

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path: Union[str, Path],
        **kwargs: Any
    ) -> "AutoProcessor": ...

    def save_pretrained(self, save_directory: Union[str, Path]) -> None: ...

    @property
    def feature_extractor(self) -> Optional[Any]: ...

    @property
    def tokenizer(self) -> Optional["AutoTokenizer"]: ...


class AutoTokenizer:
    """Type stub for AutoTokenizer from transformers."""

    pad_token_id: Optional[int]
    eos_token_id: Optional[int]
    bos_token_id: Optional[int]
    unk_token_id: Optional[int]
    pad_token: Optional[str]
    eos_token: Optional[str]
    bos_token: Optional[str]
    unk_token: Optional[str]
    model_max_length: int
    padding_side: str

    def __call__(
        self,
        text: Union[str, List[str]],
        padding: Optional[Union[bool, str]] = None,
        truncation: Optional[bool] = None,
        max_length: Optional[int] = None,
        return_tensors: Optional[str] = None,
        add_special_tokens: bool = True,
        **kwargs: Any
    ) -> Dict[str, Any]: ...

    def decode(
        self,
        token_ids: Union[int, List[int], torch.Tensor],
        skip_special_tokens: bool = True,
        clean_up_tokenization_spaces: bool = True,
        **kwargs: Any
    ) -> str: ...

    def batch_decode(
        self,
        sequences: Union[List[int], List[List[int]], torch.Tensor],
        skip_special_tokens: bool = True,
        clean_up_tokenization_spaces: bool = True,
        **kwargs: Any
    ) -> List[str]: ...

    def encode(
        self,
        text: Union[str, List[str]],
        add_special_tokens: bool = True,
        padding: Optional[Union[bool, str]] = None,
        truncation: Optional[bool] = None,
        max_length: Optional[int] = None,
        return_tensors: Optional[str] = None,
        **kwargs: Any
    ) -> Union[List[int], torch.Tensor]: ...

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path: Union[str, Path],
        **kwargs: Any
    ) -> "AutoTokenizer": ...

    def save_pretrained(self, save_directory: Union[str, Path]) -> None: ...

    def apply_chat_template(
        self,
        conversation: List[Dict[str, str]],
        tokenize: bool = False,
        add_generation_prompt: bool = False,
        **kwargs: Any
    ) -> str: ...


class AutoModelForImageTextToText:
    """Type stub for AutoModelForImageTextToText from transformers."""

    config: Any
    device: torch.device
    dtype: torch.dtype

    def generate(
        self,
        input_ids: Optional[torch.Tensor] = None,
        inputs_embeds: Optional[torch.Tensor] = None,
        attention_mask: Optional[torch.Tensor] = None,
        pixel_values: Optional[torch.Tensor] = None,
        max_length: Optional[int] = None,
        max_new_tokens: Optional[int] = None,
        min_length: Optional[int] = None,
        do_sample: Optional[bool] = None,
        temperature: Optional[float] = None,
        top_k: Optional[int] = None,
        top_p: Optional[float] = None,
        repetition_penalty: Optional[float] = None,
        bad_words_ids: Optional[List[List[int]]] = None,
        pad_token_id: Optional[int] = None,
        eos_token_id: Optional[Union[int, List[int]]] = None,
        use_cache: Optional[bool] = None,
        num_beams: Optional[int] = None,
        streamer: Optional[Any] = None,
        **kwargs: Any
    ) -> torch.Tensor: ...

    def forward(
        self,
        input_ids: Optional[torch.Tensor] = None,
        attention_mask: Optional[torch.Tensor] = None,
        pixel_values: Optional[torch.Tensor] = None,
        **kwargs: Any
    ) -> Any: ...

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path: Union[str, Path],
        torch_dtype: Optional[torch.dtype] = None,
        device_map: Optional[Union[str, Dict[str, Any]]] = None,
        **kwargs: Any
    ) -> "AutoModelForImageTextToText": ...

    def save_pretrained(self, save_directory: Union[str, Path]) -> None: ...

    def to(self, device: Union[str, torch.device]) -> "AutoModelForImageTextToText": ...

    def eval(self) -> "AutoModelForImageTextToText": ...

    def train(self, mode: bool = True) -> "AutoModelForImageTextToText": ...

    def half(self) -> "AutoModelForImageTextToText": ...

    def float(self) -> "AutoModelForImageTextToText": ...

    def cpu(self) -> "AutoModelForImageTextToText": ...

    def cuda(self, device: Optional[int] = None) -> "AutoModelForImageTextToText": ...


class TextStreamer:
    """Type stub for TextStreamer from transformers."""

    def __init__(
        self,
        tokenizer: AutoTokenizer,
        skip_prompt: bool = False,
        skip_special_tokens: bool = True,
        **kwargs: Any
    ) -> None: ...

    def put(self, value: torch.Tensor) -> None: ...

    def end(self) -> None: ...


class TextIteratorStreamer(TextStreamer):
    """Type stub for TextIteratorStreamer from transformers."""

    def __init__(
        self,
        tokenizer: AutoTokenizer,
        skip_prompt: bool = False,
        skip_special_tokens: bool = True,
        timeout: Optional[float] = None,
        **kwargs: Any
    ) -> None: ...

    def __iter__(self) -> Any: ...

    def __next__(self) -> str: ...


class GenerationConfig:
    """Type stub for GenerationConfig from transformers."""

    max_length: Optional[int]
    max_new_tokens: Optional[int]
    min_length: Optional[int]
    do_sample: bool
    temperature: float
    top_k: int
    top_p: float
    repetition_penalty: float
    pad_token_id: Optional[int]
    eos_token_id: Optional[Union[int, List[int]]]

    def __init__(self, **kwargs: Any) -> None: ...

    @classmethod
    def from_pretrained(
        cls,
        pretrained_model_name_or_path: Union[str, Path],
        **kwargs: Any
    ) -> "GenerationConfig": ...

    def save_pretrained(self, save_directory: Union[str, Path]) -> None: ...


class BitsAndBytesConfig:
    """Type stub for BitsAndBytesConfig from transformers."""

    load_in_8bit: bool
    load_in_4bit: bool
    llm_int8_threshold: float
    llm_int8_skip_modules: Optional[List[str]]
    llm_int8_enable_fp32_cpu_offload: bool
    llm_int8_has_fp16_weight: bool
    bnb_4bit_compute_dtype: Optional[torch.dtype]
    bnb_4bit_quant_type: str
    bnb_4bit_use_double_quant: bool

    def __init__(
        self,
        load_in_8bit: bool = False,
        load_in_4bit: bool = False,
        llm_int8_threshold: float = 6.0,
        llm_int8_skip_modules: Optional[List[str]] = None,
        llm_int8_enable_fp32_cpu_offload: bool = False,
        llm_int8_has_fp16_weight: bool = False,
        bnb_4bit_compute_dtype: Optional[torch.dtype] = None,
        bnb_4bit_quant_type: str = "fp4",
        bnb_4bit_use_double_quant: bool = False,
        **kwargs: Any
    ) -> None: ...


__all__ = [
    "AutoProcessor",
    "AutoTokenizer",
    "AutoModelForImageTextToText",
    "TextStreamer",
    "TextIteratorStreamer",
    "GenerationConfig",
    "BitsAndBytesConfig"
]