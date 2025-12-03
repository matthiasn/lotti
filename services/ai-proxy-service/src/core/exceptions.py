"""Custom exceptions for the AI proxy service"""


class AIProxyException(Exception):
    """Base exception for all AI proxy errors"""

    pass


class InvalidModelException(AIProxyException):
    """Raised when an invalid or unsupported model is requested"""

    pass


class AIProviderException(AIProxyException):
    """Raised when the AI provider (Gemini) returns an error"""

    pass


class InvalidRequestException(AIProxyException):
    """Raised when the request is invalid or malformed"""

    pass


class BillingException(AIProxyException):
    """Raised when billing operations fail"""

    pass
