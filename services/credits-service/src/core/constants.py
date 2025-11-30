"""Core constants for the credits service"""

# Service names for dependency injection
SERVICE_TIGERBEETLE_CLIENT = "tigerbeetle_client"
SERVICE_ACCOUNT_SERVICE = "account_service"
SERVICE_BALANCE_SERVICE = "balance_service"
SERVICE_BILLING_SERVICE = "billing_service"

# TigerBeetle constants
LEDGER_ID = 1  # USD ledger
TRANSFER_FLAGS_NONE = 0
TRANSFER_FLAGS_LINKED = 1
TRANSFER_FLAGS_PENDING = 2
TRANSFER_FLAGS_POST_PENDING = 4
TRANSFER_FLAGS_VOIDING = 8
TRANSFER_FLAGS_BALANCING = 16

# Account codes
ACCOUNT_CODE_USER = 1
ACCOUNT_CODE_SYSTEM = 2

# Currency precision (cents)
CURRENCY_PRECISION = 100  # 1 USD = 100 cents
