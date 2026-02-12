"""Tests for image generator module."""

import io
import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from PIL import Image

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from image_generator import ImageGenerator


class TestImageGenerator:
    """Tests for ImageGenerator class."""

    def test_init_stores_model_manager(self):
        """Test initialization stores model manager reference."""
        manager = MagicMock()
        generator = ImageGenerator(manager)
        assert generator._model_manager is manager

    @pytest.mark.asyncio
    async def test_generate_raises_when_model_not_loaded(self):
        """Test generate raises RuntimeError when model not loaded."""
        manager = MagicMock()
        manager.is_model_loaded.return_value = False

        generator = ImageGenerator(manager)

        with pytest.raises(RuntimeError, match="Model not loaded"):
            await generator.generate(prompt="test prompt")

    @pytest.mark.asyncio
    async def test_generate_raises_on_invalid_dimensions(self):
        """Test generate raises ValueError on out-of-range dimensions."""
        manager = MagicMock()
        manager.is_model_loaded.return_value = True

        generator = ImageGenerator(manager)

        with pytest.raises(ValueError, match="out of range"):
            await generator.generate(
                prompt="test prompt",
                width=100,  # Below MIN_DIMENSION
                height=100,
            )

    def test_image_to_png_bytes_returns_bytes(self):
        """Test image_to_png_bytes returns valid PNG bytes."""
        # Create a small test image
        image = Image.new("RGB", (64, 64), color="red")

        png_bytes = ImageGenerator.image_to_png_bytes(image)

        assert isinstance(png_bytes, bytes)
        assert len(png_bytes) > 0
        # Verify it's valid PNG (starts with PNG signature)
        assert png_bytes[:4] == b"\x89PNG"

    def test_image_to_png_bytes_roundtrip(self):
        """Test PNG bytes can be loaded back as an image."""
        original = Image.new("RGB", (64, 64), color="blue")

        png_bytes = ImageGenerator.image_to_png_bytes(original)
        loaded = Image.open(io.BytesIO(png_bytes))

        assert loaded.size == original.size
        assert loaded.mode == original.mode
