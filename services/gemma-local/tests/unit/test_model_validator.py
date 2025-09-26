"""Unit tests for ModelValidator"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch

from src.services.model_validator import ModelValidator
from src.core.exceptions import ModelNotFoundError, ValidationError


@pytest.mark.unit
class TestModelValidator:
    """Test ModelValidator functionality"""

    def test_validate_model_request_empty_name_raises_error(self, mock_config_manager, mock_model_manager):
        """Test that empty model name raises ValidationError"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)

        with pytest.raises(ValidationError, match="Model name cannot be empty"):
            validator.validate_model_request("")

    def test_validate_model_request_model_exists(self, mock_config_manager, mock_model_manager):
        """Test validation when model files exist"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)

        # Mock cache dir and model path
        cache_dir = Path("/tmp/test-cache")
        mock_config_manager.get_cache_dir.return_value = cache_dir

        with patch.object(validator, '_get_model_path') as mock_get_path:
            mock_path = Mock()
            mock_path.exists.return_value = True
            mock_path.glob.return_value = ["model.safetensors"]  # Non-empty iterator
            mock_get_path.return_value = mock_path

            result = validator.validate_model_request("gemma-3n-E2B-it")
            assert result is True

    def test_validate_model_request_model_missing(self, mock_config_manager, mock_model_manager):
        """Test validation when model files don't exist"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)

        with patch.object(validator, '_get_model_path') as mock_get_path:
            mock_path = Mock()
            mock_path.exists.return_value = False
            mock_get_path.return_value = mock_path

            result = validator.validate_model_request("gemma-3n-E2B-it")
            assert result is False

    @pytest.mark.asyncio
    async def test_ensure_model_available_missing_model(self, mock_config_manager, mock_model_manager):
        """Test ensure_model_available with missing model"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)

        with patch.object(validator, 'validate_model_request', return_value=False):
            with pytest.raises(ModelNotFoundError, match="not downloaded"):
                await validator.ensure_model_available("gemma-3n-E4B-it")

    @pytest.mark.asyncio
    async def test_ensure_model_available_same_model(self, mock_config_manager, mock_model_manager):
        """Test ensure_model_available when model is already configured"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        mock_config_manager.get_model_id.return_value = "google/gemma-3n-E2B-it"

        with patch.object(validator, 'validate_model_request', return_value=True):
            # Should not call _switch_model_config
            with patch.object(validator, '_switch_model_config') as mock_switch:
                await validator.ensure_model_available("gemma-3n-E2B-it")
                mock_switch.assert_not_called()

    @pytest.mark.asyncio
    async def test_ensure_model_available_different_model(self, mock_config_manager, mock_model_manager):
        """Test ensure_model_available when switching models"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        mock_config_manager.get_model_id.return_value = "google/gemma-3n-E2B-it"

        with patch.object(validator, 'validate_model_request', return_value=True):
            with patch.object(validator, '_switch_model_config') as mock_switch:
                await validator.ensure_model_available("gemma-3n-E4B-it")
                mock_switch.assert_called_once_with("gemma-3n-E4B-it")

    @pytest.mark.asyncio
    async def test_switch_model_config_e4b(self, mock_config_manager, mock_model_manager):
        """Test switching to E4B model configuration"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        mock_model_manager.is_model_loaded.return_value = True

        await validator._switch_model_config("gemma-3n-E4B-it")

        mock_config_manager.set_model_id.assert_called_with("google/gemma-3n-E4B-it")
        mock_config_manager.set_model_variant.assert_called_with("E4B")
        mock_model_manager.unload_model.assert_called_once()
        mock_model_manager.refresh_config.assert_called_once()

    @pytest.mark.asyncio
    async def test_switch_model_config_e2b(self, mock_config_manager, mock_model_manager):
        """Test switching to E2B model configuration"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        mock_model_manager.is_model_loaded.return_value = False

        await validator._switch_model_config("gemma-3n-E2B-it")

        mock_config_manager.set_model_id.assert_called_with("google/gemma-3n-E2B-it")
        mock_config_manager.set_model_variant.assert_called_with("E2B")
        mock_model_manager.unload_model.assert_not_called()  # Not loaded
        mock_model_manager.refresh_config.assert_called_once()

    def test_get_model_path_without_prefix(self, mock_config_manager, mock_model_manager):
        """Test getting model path without google/ prefix"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        cache_dir = Path("/tmp/test-cache")
        mock_config_manager.get_cache_dir.return_value = cache_dir

        path = validator._get_model_path("gemma-3n-E2B-it")
        expected = cache_dir / "models" / "google--gemma-3n-E2B-it"
        assert path == expected

    def test_get_model_path_with_prefix(self, mock_config_manager, mock_model_manager):
        """Test getting model path with google/ prefix"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        cache_dir = Path("/tmp/test-cache")
        mock_config_manager.get_cache_dir.return_value = cache_dir

        path = validator._get_model_path("google/gemma-3n-E2B-it")
        expected = cache_dir / "models" / "google--gemma-3n-E2B-it"
        assert path == expected

    def test_get_available_models_no_models_dir(self, mock_config_manager, mock_model_manager):
        """Test getting available models when models directory doesn't exist"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        cache_dir = Path("/tmp/test-cache")
        mock_config_manager.get_cache_dir.return_value = cache_dir

        models = validator.get_available_models()
        assert models == []

    def test_get_available_models_with_models(self, mock_config_manager, mock_model_manager):
        """Test getting available models when models exist"""
        validator = ModelValidator(mock_config_manager, mock_model_manager)
        cache_dir = Path("/tmp/test-cache")
        mock_config_manager.get_cache_dir.return_value = cache_dir

        # Mock models directory structure
        with patch('pathlib.Path.exists', return_value=True), \
             patch('pathlib.Path.iterdir') as mock_iterdir:

            # Create mock model directories
            mock_e2b_dir = Mock()
            mock_e2b_dir.is_dir.return_value = True
            mock_e2b_dir.name = "google--gemma-3n-E2B-it"
            mock_e2b_dir.glob.return_value = ["model.safetensors"]

            mock_e4b_dir = Mock()
            mock_e4b_dir.is_dir.return_value = True
            mock_e4b_dir.name = "google--gemma-3n-E4B-it"
            mock_e4b_dir.glob.return_value = ["model.safetensors"]

            mock_empty_dir = Mock()
            mock_empty_dir.is_dir.return_value = True
            mock_empty_dir.name = "empty-model"
            mock_empty_dir.glob.return_value = []  # No safetensors files

            mock_iterdir.return_value = [mock_e2b_dir, mock_e4b_dir, mock_empty_dir]

            models = validator.get_available_models()

            # Should only include directories with safetensors files
            expected = ["google/gemma-3n-E2B-it", "google/gemma-3n-E4B-it"]
            assert sorted(models) == sorted(expected)