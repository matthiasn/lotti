"""Rate limiting middleware using slowapi"""

import logging
import os
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

logger = logging.getLogger(__name__)


def get_limiter():
    """
    Create and configure rate limiter

    Rate limits are configured via environment variables:
    - RATE_LIMIT_PER_MINUTE: Requests per minute per IP (default: 60)
    - RATE_LIMIT_ENABLED: Enable/disable rate limiting (default: true)
    """
    rate_limit_enabled = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
    rate_limit_per_minute = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

    if not rate_limit_enabled:
        logger.info("ℹ️  Rate limiting disabled")
        # Return a limiter with effectively no limit
        return Limiter(key_func=get_remote_address, default_limits=["999999 per minute"])

    logger.info(f"✓ Rate limiting enabled: {rate_limit_per_minute} requests/minute per IP")

    # Create limiter with configurable rate
    limiter = Limiter(
        key_func=get_remote_address,
        default_limits=[f"{rate_limit_per_minute} per minute"],
        storage_uri="memory://",  # In-memory storage (consider Redis for production with multiple instances)
    )

    return limiter


# Global limiter instance
limiter = get_limiter()
rate_limit_handler = _rate_limit_exceeded_handler
