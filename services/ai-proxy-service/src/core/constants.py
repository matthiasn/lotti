"""Core constants for the AI proxy service"""

# Service names for dependency injection
SERVICE_GEMINI_CLIENT = "gemini_client"
SERVICE_BILLING_SERVICE = "billing_service"

# Model pricing (USD per 1K tokens)
# Based on Gemini pricing as of 2025
# https://ai.google.dev/gemini-api/docs/pricing
MODEL_PRICING = {
    "gemini-2.5-pro": {
        "input_price_per_1k": 0.00125,  # $1.25 per 1M input tokens
        "output_price_per_1k": 0.01,  # $10.00 per 1M output tokens
    },
    "gemini-2.5-flash": {
        "input_price_per_1k": 0.0003,  # $0.30 per 1M input tokens
        "output_price_per_1k": 0.0025,  # $2.50 per 1M output tokens
    },
}

# Default pricing for unknown models (use Pro pricing as fallback)
DEFAULT_MODEL_PRICING = {
    "input_price_per_1k": 0.00125,
    "output_price_per_1k": 0.01,
}

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
