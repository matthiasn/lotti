"""Core constants for the matrix provisioning service"""

# Service names for dependency injection
SERVICE_PROVISIONING_REPOSITORY = "provisioning_repository"
SERVICE_BUNDLE_SERVICE = "bundle_service"
SERVICE_ADMIN_CLIENT = "admin_client"
SERVICE_REDEMPTION_POLLER = "redemption_poller"

# Default SQLite location, mirroring the credits-service convention of a
# `data/` directory mounted as a volume in Docker.
DEFAULT_DB_PATH = "data/provisioning.db"

# Redemption polling
DEFAULT_POLL_INTERVAL_SECONDS = 300
DEFAULT_POLL_BATCH_SIZE = 50

# History retention. A reconnecting device catches up by walking the room
# timeline first, and only escalates still-missing counters to peer-to-peer
# backfill. So this window is the bound on how long a device can be offline and
# still resynchronise from the room alone; beyond it, repair depends on a peer
# still holding the payload.
DEFAULT_RETENTION_DAYS = 30
# Floor chosen to stay clear of the 7-day backfill amnesty, so a gap never ages
# out of peer repair in the same window that room replay stops covering it.
MIN_RETENTION_DAYS = 7

# Pagination
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

# Synapse localpart rules: lowercase alphanumerics plus ._=-/+ — we deliberately
# apply a stricter subset so provisioned usernames stay readable and shell-safe.
USERNAME_PATTERN = r"^[a-z0-9][a-z0-9._-]{2,63}$"
