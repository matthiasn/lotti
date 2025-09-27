"""Application constants for Gemma Local Service"""

# Default configuration values
DEFAULT_MODEL_ID = "google/gemma-3n-E2B-it"
DEFAULT_MODEL_VARIANT = "E2B"
DEFAULT_MODEL_REVISION = "main"
DEFAULT_CACHE_DIR_NAME = "gemma-local"
DEFAULT_DEVICE = "auto"
DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_HOST = "127.0.0.1"  # Localhost only for security
DEFAULT_PORT = 8000

# Security settings
ALLOWED_MODEL_VARIANTS = ["E2B", "E4B"]
ALLOWED_MODEL_PREFIXES = ["google/"]
SECURE_HOST_LOCALHOST = "127.0.0.1"
# Security: Service should only bind to localhost. For production deployments,
# use a reverse proxy (nginx, etc.) or specify a specific interface IP address

# Environment variable names
ENV_GEMMA_MODEL_ID = "GEMMA_MODEL_ID"
ENV_GEMMA_MODEL_VARIANT = "GEMMA_MODEL_VARIANT"
ENV_GEMMA_MODEL_REVISION = "GEMMA_MODEL_REVISION"
ENV_GEMMA_CACHE_DIR = "GEMMA_CACHE_DIR"
ENV_GEMMA_DEVICE = "GEMMA_DEVICE"
ENV_HOST = "HOST"
ENV_PORT = "PORT"
ENV_LOG_LEVEL = "LOG_LEVEL"

# HuggingFace token environment variables
ENV_HUGGINGFACE_TOKEN = "HUGGINGFACE_TOKEN"
ENV_HF_TOKEN = "HF_TOKEN"
ENV_HUGGING_FACE_HUB_TOKEN = "HUGGING_FACE_HUB_TOKEN"

# API constants
API_VERSION = "2.0.0"
API_TITLE = "Gemma Local Service"
API_DESCRIPTION = "Local Gemma model service with OpenAI-compatible API - Modular Architecture"

# CORS settings
CORS_ALLOW_ORIGINS = ["*"]
CORS_ALLOW_METHODS = ["*"]
CORS_ALLOW_HEADERS = ["*"]

# File extensions and paths
MODEL_FILE_EXTENSION = "*.safetensors"
ENV_FILE_NAME = ".env"
CACHE_SUBDIR_MODELS = "models"
PATH_SEPARATOR_REPLACEMENT = "--"

# Logging format
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# HTTP status messages
STATUS_HEALTHY = "healthy"
STATUS_SUCCESS = "success"
STATUS_ERROR = "error"

# Default model configuration errors
ERROR_EMPTY_MODEL_ID = "Model ID cannot be empty"
ERROR_INVALID_PORT = "Invalid PORT value"
ERROR_INVALID_MODEL_FORMAT = "Invalid model ID format"
ERROR_INVALID_VARIANT = "Invalid model variant"

# Server startup messages
MSG_MODEL_FILES_FOUND = "Model files found. Ready to load on first request."
MSG_MODEL_NOT_DOWNLOADED = "Model not downloaded. Use /v1/models/pull to download."
MSG_STARTING_SERVICE = "Starting Gemma Local Service (Modular) with model"
MSG_LOADED_ENV = "Loaded environment from"

# Service type identifiers
SERVICE_CONFIG_MANAGER = "config_manager"
SERVICE_MODEL_MANAGER = "model_manager"
SERVICE_AUDIO_PROCESSOR = "audio_processor"
SERVICE_MODEL_VALIDATOR = "model_validator"
SERVICE_MODEL_DOWNLOADER = "model_downloader"
SERVICE_TRANSCRIPTION_SERVICE = "transcription_service"
SERVICE_CHAT_SERVICE = "chat_service"

# Default timeout and retry values
DEFAULT_REQUEST_TIMEOUT = 600
DEFAULT_MAX_CONCURRENT_REQUESTS = 2
DEFAULT_MAX_TOKENS = 2000

# Error messages
ERROR_MODEL_NOT_DOWNLOADED = "Model not downloaded. Use /v1/models/pull to download first."
ERROR_FAILED_TO_LOAD_MODEL = "Failed to load model"
ERROR_MODEL_LOADING_FAILED = "Model loading failed"
ERROR_MODEL_DOWNLOAD_FAILED = "Model download failed"
ERROR_TRANSCRIPTION_FAILED = "Transcription failed"
ERROR_CHAT_COMPLETION_FAILED = "Chat completion failed"
ERROR_INTERNAL_ERROR = "An internal error occurred."
ERROR_DOWNLOAD_FAILED = "Download failed"
ERROR_FAILED_LOAD_FOR_TRANSCRIPTION = "Failed to load model for transcription"
ERROR_FAILED_PROCESS_AUDIO = "Failed to process audio"
ERROR_EMPTY_MODEL_NAME = "Model name cannot be empty"
ERROR_SERVICE_NOT_FOUND = "Service not found"