"""Core constants for the matrix provisioning service"""

# Service names for dependency injection
SERVICE_PROVISIONING_REPOSITORY = "provisioning_repository"
SERVICE_PROVISIONER = "provisioner"
SERVICE_BUNDLE_SERVICE = "bundle_service"
SERVICE_ADMIN_CLIENT = "admin_client"
SERVICE_REDEMPTION_POLLER = "redemption_poller"
SERVICE_RETENTION_SERVICE = "retention_service"
SERVICE_RETENTION_SCHEDULER = "retention_scheduler"
SERVICE_SUBSCRIPTION_REPOSITORY = "subscription_repository"
SERVICE_SECRET_CIPHER = "secret_cipher"  # noqa: S105 - dependency-injection name
SERVICE_GOOGLE_PLAY_CLIENT = "google_play_client"
SERVICE_SUBSCRIPTION_IDENTITY = "subscription_identity"
SERVICE_SUBSCRIPTION_SERVICE = "subscription_service"
SERVICE_PAID_BUNDLE_SERVICE = "paid_bundle_service"
SERVICE_BUNDLE_ROTATION_SERVICE = "bundle_rotation_service"
SERVICE_SUBSCRIPTION_ACCESS_SERVICE = "subscription_access_service"
SERVICE_GOOGLE_PLAY_NOTIFICATIONS = "google_play_notifications"
SERVICE_SUBSCRIPTION_RECONCILER = "subscription_reconciler"
SERVICE_BUNDLE_CLAIM_REAPER = "bundle_claim_reaper"

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

# Subscription reconciliation catches missed RTDNs and enforces exact stored
# deadlines. It is intentionally much more frequent than bundle redemption.
DEFAULT_SUBSCRIPTION_RECONCILE_INTERVAL_SECONDS = 60
DEFAULT_SUBSCRIPTION_RECONCILE_BATCH_SIZE = 50

# Anonymous entitlement issuance must remain possible for a fresh install, but
# an unauthenticated caller must not be able to grow the SQLite database without
# bound. The HMAC-keyed quota is shared by every worker using the database.
DEFAULT_ENTITLEMENT_ISSUANCE_LIMIT = 5
DEFAULT_ENTITLEMENT_ISSUANCE_WINDOW_SECONDS = 3600

# Attempts are counted before entitlement-secret verification. Keeping the
# default aligned with the post-authentication issuance quota means requests
# beyond the normal Billing-launch allowance never reach scrypt.
DEFAULT_PURCHASE_INTENT_ATTEMPT_LIMIT = 10
DEFAULT_PURCHASE_INTENT_ATTEMPT_WINDOW_SECONDS = 900
# An authenticated entitlement can issue only a small number of one-time
# Billing authorizations per window. Expired intents are pruned while this
# durable quota is consumed, bounding both expensive secret hashing and SQLite
# growth even when a valid app credential is abused.
DEFAULT_PURCHASE_INTENT_ISSUANCE_LIMIT = 10
DEFAULT_PURCHASE_INTENT_ISSUANCE_WINDOW_SECONDS = 900

# Paid provisioning and cleanup both cross the SQLite/Synapse boundary. The
# reservation survives process boundaries; the request wait is deliberately
# shorter so a dead worker produces a retryable conflict instead of pinning an
# HTTP connection until the stale lease can be recovered.
DEFAULT_PAID_PROVISIONING_WAIT_SECONDS = 30.0
DEFAULT_PAID_PROVISIONING_POLL_SECONDS = 0.1
PAID_PROVISIONING_OPERATION_TIMEOUT_SECONDS = 300.0
BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS = 60.0

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

# How long an in-flight provisioning claim blocks another run for the same
# localpart. Provisioning takes seconds; this is long enough to cover a slow
# homeserver and short enough that a process killed midway does not strand the
# name until someone edits the database by hand.
PROVISIONING_CLAIM_TTL_SECONDS = 300.0

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

# Google Play product contract. Prices remain Play Console configuration; the
# backend authorizes stable identifiers only.
PLAY_PACKAGE_NAME = "com.matthiasn.lotti"
PLAY_SUBSCRIPTION_PRODUCT_ID = "lotti_sync"
DEFAULT_PLAY_BASE_PLAN_IDS = frozenset({"monthly", "annual"})
