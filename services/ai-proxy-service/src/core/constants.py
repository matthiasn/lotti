"""Core constants for the AI proxy service"""

# Service names for dependency injection
SERVICE_GEMINI_CLIENT = "gemini_client"
SERVICE_BILLING_SERVICE = "billing_service"

# Model pricing (USD per 1K tokens)
# Based on Gemini pricing as of 2024
# Each model has input_price and output_price per 1K tokens
MODEL_PRICING = {
    "gemini-2.5-pro": {
        "input_price_per_1k": 0.00025,  # $0.00025 per 1K input tokens
        "output_price_per_1k": 0.0005,  # $0.0005 per 1K output tokens
    },
    "gemini-2.5-flash": {
        "input_price_per_1k": 0.000075,  # $0.000075 per 1K input tokens
        "output_price_per_1k": 0.0003,  # $0.0003 per 1K output tokens
    },
}

# Default pricing for unknown models (use Pro pricing as fallback)
DEFAULT_MODEL_PRICING = {
    "input_price_per_1k": 0.00025,
    "output_price_per_1k": 0.0005,
}

# Legacy constants (deprecated - use MODEL_PRICING instead)
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
