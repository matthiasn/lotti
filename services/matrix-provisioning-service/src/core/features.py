"""Environment feature flags for the paid sync channels."""

from __future__ import annotations

import os

_TRUE = ("1", "true", "yes")


def play_subscriptions_enabled() -> bool:
    """Google Play Billing purchases are accepted."""
    return os.getenv("ENABLE_PLAY_SUBSCRIPTIONS", "false").lower() in _TRUE


def web_subscriptions_enabled() -> bool:
    """Paddle web checkout is accepted."""
    return os.getenv("ENABLE_WEB_SUBSCRIPTIONS", "false").lower() in _TRUE


def paid_sync_enabled() -> bool:
    """Any paid channel is on, so the shared entitlement and escrow routes serve."""
    return play_subscriptions_enabled() or web_subscriptions_enabled()
