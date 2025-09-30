"""Model downloading service"""

import asyncio
import logging
from pathlib import Path
from typing import AsyncIterator
from huggingface_hub import snapshot_download

from ..core.interfaces import IModelDownloader, IConfigManager
from ..core.models import DownloadProgress, ModelStatus
from ..core.exceptions import ModelDownloadError


logger = logging.getLogger(__name__)


class ModelDownloader(IModelDownloader):
    """Downloads models from HuggingFace with progress tracking"""

    def __init__(self, config_manager: IConfigManager):
        self.config_manager = config_manager

    async def download_model(self, model_name: str, stream: bool = True) -> AsyncIterator[DownloadProgress]:
        """Download model with progress tracking"""
        try:
            # Normalize model name and determine variant
            requested_model = model_name.replace("google/", "")
            model_id, variant = self._determine_model_details(requested_model)

            yield DownloadProgress(
                status=ModelStatus.CHECKING,
                message="Checking if model exists locally...",
                progress=0.0,
            )

            # Check if already downloaded
            if self.is_model_downloaded(model_name):
                # Update configuration to use this model
                self.config_manager.set_model_id(model_id)
                self.config_manager.set_model_variant(variant)

                yield DownloadProgress(status=ModelStatus.COMPLETE, message="Model already downloaded", progress=100.0)
                return

            yield DownloadProgress(status=ModelStatus.PREPARING, message="Preparing to download model...", progress=0.0)

            # Start download
            yield DownloadProgress(status=ModelStatus.DOWNLOADING, message=f"Downloading {model_id}...", progress=0.0)

            # Get HuggingFace token
            hf_token = self.config_manager.get_huggingface_token()
            if not hf_token:
                logger.warning("No HuggingFace token found. Attempting download without authentication.")

            # Get revision for secure download (prevents model substitution attacks)
            revision = self.config_manager.get_model_revision(model_id)
            logger.info(f"Downloading model {model_id} at revision: {revision}")

            # Download model in executor to avoid blocking
            download_path = self._get_download_path(model_id)
            loop = asyncio.get_event_loop()

            await loop.run_in_executor(
                None,
                lambda: snapshot_download(  # nosec B615 - revision pinned via config
                    repo_id=model_id,
                    revision=revision,  # Pin to specific revision for security
                    cache_dir=self.config_manager.get_cache_dir() / "models",
                    local_dir=download_path,
                    local_dir_use_symlinks=False,
                    resume_download=True,
                    token=hf_token,
                ),
            )

            # Update configuration
            self.config_manager.set_model_id(model_id)
            self.config_manager.set_model_variant(variant)

            yield DownloadProgress(
                status=ModelStatus.COMPLETE,
                message=f"Model downloaded successfully to {download_path}",
                progress=100.0,
            )

            logger.info(f"Configuration updated to use {model_id}")

        except Exception as e:
            logger.error(f"Model download failed: {e}", exc_info=True)
            yield DownloadProgress(
                status=ModelStatus.ERROR,
                message="Download failed",
                progress=0.0,
                error="Download failed",
            )
            raise ModelDownloadError(model_name, "Download failed")

    def is_model_downloaded(self, model_name: str) -> bool:
        """Check if model is already downloaded"""
        # Normalize model name
        requested_model = model_name.replace("google/", "")
        model_id, _ = self._determine_model_details(requested_model)

        model_path = self._get_download_path(model_id)
        return model_path.exists() and any(model_path.glob("*.safetensors"))

    def _determine_model_details(self, requested_model: str) -> tuple[str, str]:
        """Determine full model ID and variant from requested model name"""
        if "E4B" in requested_model.upper():
            model_id = "google/gemma-3n-E4B-it"
            variant = "E4B"
        elif "E2B" in requested_model.upper():
            model_id = "google/gemma-3n-E2B-it"
            variant = "E2B"
        else:
            # Default to E2B if not specified
            model_id = "google/gemma-3n-E2B-it"
            variant = "E2B"

        return model_id, variant

    def _get_download_path(self, model_id: str) -> Path:
        """Get download path for model"""
        cache_dir = self.config_manager.get_cache_dir()
        return cache_dir / "models" / model_id.replace("/", "--")
