"""Money conversion helpers for exact internal billing units."""

from __future__ import annotations

from decimal import Decimal

from .exceptions import InvalidAmountException

USD_MICROCENTS_PER_USD = 100_000_000
USD_MICROCENTS_PER_USD_DECIMAL = Decimal(USD_MICROCENTS_PER_USD)


def usd_to_microcents(amount_usd: Decimal) -> int:
    """Convert a USD amount to whole microcents without silent truncation."""
    microcents = amount_usd * USD_MICROCENTS_PER_USD_DECIMAL
    integral_microcents = microcents.to_integral_value()
    if microcents != integral_microcents:
        raise InvalidAmountException(
            "Amounts must not exceed 8 decimal places of USD precision",
        )
    return int(integral_microcents)


def microcents_to_usd(amount_microcents: int) -> Decimal:
    """Convert whole microcents to a USD decimal amount."""
    return Decimal(amount_microcents) / USD_MICROCENTS_PER_USD_DECIMAL
