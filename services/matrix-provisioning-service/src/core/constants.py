"""Core constants for the matrix provisioning service"""

# Service names for dependency injection
SERVICE_PROVISIONING_REPOSITORY = "provisioning_repository"
SERVICE_PROVISIONER = "provisioner"
SERVICE_BUNDLE_SERVICE = "bundle_service"
SERVICE_ADMIN_CLIENT = "admin_client"
SERVICE_REDEMPTION_POLLER = "redemption_poller"
SERVICE_RETENTION_SERVICE = "retention_service"
SERVICE_RETENTION_SCHEDULER = "retention_scheduler"

# Default SQLite location, mirroring the credits-service convention of a
# `data/` directory mounted as a volume in Docker.
DEFAULT_DB_PATH = "data/provisioning.db"

# How long a writer waits for the lock before giving up. Generous because the
# competing writes are a retention sweep and a polling batch, both of which run
# unattended: queueing behind one for a few seconds is always better than
# failing an admin's request with "database is locked".
BUSY_TIMEOUT_SECONDS = 15.0

# Redemption polling
DEFAULT_POLL_INTERVAL_SECONDS = 300
DEFAULT_POLL_BATCH_SIZE = 50

# History retention. A reconnecting device catches up by walking the room
# timeline first, and only escalates still-missing counters to peer-to-peer
# backfill. So this window is the bound on how long a device can be offline and
# still resynchronise from the room alone; beyond it, repair depends on a peer
# still holding the payload.
DEFAULT_RETENTION_DAYS = 30

# The sweep runs daily and is ON by default, so disk does not grow until an
# admin remembers to press a button. The startup delay means a misconfigured
# deploy can be stopped before it deletes anything.
DEFAULT_RETENTION_SWEEP_HOURS = 24.0
RETENTION_SWEEP_STARTUP_DELAY_SECONDS = 300.0
# Floor chosen to stay clear of the 7-day backfill amnesty, so a gap never ages
# out of peer repair in the same window that room replay stops covering it.
MIN_RETENTION_DAYS = 7
# Ten years. Not a storage policy so much as a typo guard: anything past this is
# a slipped digit, and a window the sweep can never reach is indistinguishable
# from having no retention at all.
MAX_RETENTION_DAYS = 3650

# Pagination
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

# Audit trail. The poller appends to it on its own schedule, so reads are capped
# to keep a long-running bundle's response size predictable.
DEFAULT_EVENT_LIMIT = 200
MAX_EVENT_LIMIT = 1000

# Synapse localpart rules: lowercase alphanumerics plus ._=-/+ — we deliberately
# apply a stricter subset so provisioned usernames stay readable and shell-safe.
USERNAME_PATTERN = r"^[a-z0-9][a-z0-9._-]{2,63}$"
