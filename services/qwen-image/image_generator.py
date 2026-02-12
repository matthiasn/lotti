"""Image generation logic for Qwen Image Service.

Separates the image generation logic from the model management,
making both independently testable.
"""

import asyncio
import io
import logging
import time
from typing import Any, Dict, Optional

import torch
from PIL import Image

from config import ServiceConfig

logger = logging.getLogger(__name__)


class ImageGenerator:
    """Generates images using a loaded diffusion pipeline.

    This class is responsible for the actual image generation logic,
    separate from model loading/downloading concerns.
    """

    def __init__(self, model_manager: Any) -> None:
        self._model_manager = model_manager

    async def generate(
        self,
        prompt: str,
        negative_prompt: str = "",
        width: Optional[int] = None,
        height: Optional[int] = None,
        num_inference_steps: Optional[int] = None,
        cfg_scale: Optional[float] = None,
        seed: Optional[int] = None,
        request_id: str = "",
    ) -> Dict[str, Any]:
        """Generate an image from a text prompt.

        Args:
            prompt: Text description of the image to generate.
            negative_prompt: Text describing what to avoid in the image.
            width: Image width in pixels. Defaults to config value.
            height: Image height in pixels. Defaults to config value.
            num_inference_steps: Number of diffusion steps. Defaults to config value.
            cfg_scale: Classifier-free guidance scale. Defaults to config value.
            seed: Random seed for reproducibility. Random if None.
            request_id: Request ID for logging.

        Returns:
            Dictionary with 'image' (PIL Image), 'seed' (int),
            and 'generation_time' (float seconds).

        Raises:
            RuntimeError: If model is not loaded or generation fails.
            ValueError: If dimensions are invalid.
        """
        if not self._model_manager.is_model_loaded():
            raise RuntimeError("Model not loaded. Load the model first.")

        # Apply defaults
        gen_config = ServiceConfig.get_generation_config()
        width = width or gen_config["width"]
        height = height or gen_config["height"]
        num_inference_steps = num_inference_steps or gen_config["num_inference_steps"]
        cfg_scale = cfg_scale or gen_config["true_cfg_scale"]

        # Validate dimensions
        if not ServiceConfig.validate_dimensions(width, height):
            raise ValueError(
                f"Dimensions {width}x{height} out of range "
                f"({ServiceConfig.MIN_DIMENSION}-{ServiceConfig.MAX_DIMENSION})"
            )

        logger.info(
            f"[REQ {request_id}] Generating image: "
            f"{width}x{height}, steps={num_inference_steps}, "
            f"cfg={cfg_scale}, seed={seed}"
        )

        # Prepare generation kwargs
        device = self._model_manager.device
        if seed is not None:
            generator = torch.Generator(device=device).manual_seed(seed)
        else:
            seed = torch.randint(0, 2**32 - 1, (1,)).item()
            generator = torch.Generator(device=device).manual_seed(seed)

        def _generate_sync() -> Image.Image:
            pipe = self._model_manager.pipe
            with torch.inference_mode():
                result = pipe(
                    prompt=prompt,
                    negative_prompt=negative_prompt,
                    width=width,
                    height=height,
                    num_inference_steps=num_inference_steps,
                    true_cfg_scale=cfg_scale,
                    generator=generator,
                )
            return result.images[0]

        t0 = time.perf_counter()
        try:
            image = await asyncio.wait_for(
                asyncio.to_thread(_generate_sync),
                timeout=ServiceConfig.GENERATION_TIMEOUT,
            )
        except asyncio.TimeoutError:
            logger.error(
                f"[REQ {request_id}] Generation timed out after "
                f"{ServiceConfig.GENERATION_TIMEOUT}s"
            )
            raise RuntimeError(
                f"Image generation timed out after {ServiceConfig.GENERATION_TIMEOUT}s"
            )

        generation_time = time.perf_counter() - t0
        logger.info(
            f"[REQ {request_id}] Image generated in {generation_time:.2f}s "
            f"(seed={seed})"
        )

        return {
            "image": image,
            "seed": seed,
            "generation_time": generation_time,
        }

    @staticmethod
    def image_to_png_bytes(image: Image.Image) -> bytes:
        """Convert a PIL Image to PNG bytes."""
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        return buffer.getvalue()
