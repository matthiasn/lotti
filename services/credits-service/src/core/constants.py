"""Core constants for the credits service"""

# Service names for dependency injection
SERVICE_TIGERBEETLE_CLIENT = "tigerbeetle_client"
SERVICE_ACCOUNT_SERVICE = "account_service"
SERVICE_BALANCE_SERVICE = "balance_service"
SERVICE_BILLING_SERVICE = "billing_service"

# TigerBeetle constants
LEDGER_ID = 1  # USD ledger
SYSTEM_ACCOUNT_ID = 1  # System account for credits (acts as a bank)
TRANSFER_FLAGS_NONE = 0
TRANSFER_FLAGS_LINKED = 1
TRANSFER_FLAGS_PENDING = 2
TRANSFER_FLAGS_POST_PENDING = 4
TRANSFER_FLAGS_VOIDING = 8
TRANSFER_FLAGS_BALANCING = 16

# Account codes
ACCOUNT_CODE_USER = 1
ACCOUNT_CODE_SYSTEM = 2

SERVICE_USER_REGISTRY = "user_registry"
SERVICE_TRANSACTION_LOG = "transaction_log"

# Internal billing precision (microcents)
# 1 USD = 100,000,000 microcents = 10^-8 USD
USD_MICROCENTS_PER_USD = 100_000_000
