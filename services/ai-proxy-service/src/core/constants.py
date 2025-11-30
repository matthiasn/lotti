"""Core constants for the AI proxy service"""

# Service names for dependency injection
SERVICE_GEMINI_CLIENT = "gemini_client"
SERVICE_BILLING_SERVICE = "billing_service"

# Model pricing (USD per 1K tokens)
# Based on Gemini Pro pricing as of 2024
GEMINI_PRO_INPUT_PRICE_PER_1K = 0.00025  # $0.00025 per 1K input tokens
GEMINI_PRO_OUTPUT_PRICE_PER_1K = 0.0005  # $0.0005 per 1K output tokens

# Model mappings (OpenAI model names to Gemini models)
# Using stable Gemini 2.5 models with correct API format
MODEL_MAPPINGS = {
    "gpt-3.5-turbo": "gemini-2.5-flash",
    "gpt-4": "gemini-2.5-pro",
    "gemini-pro": "gemini-2.5-pro",
    "gemini-flash": "gemini-2.5-flash",
}

# Default model if not specified
DEFAULT_MODEL = "gemini-2.5-flash"
