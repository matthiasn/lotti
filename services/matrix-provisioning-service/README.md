# Matrix Provisioning Service

Provisions Lotti sync accounts on a Synapse homeserver and tracks the lifecycle
of the bundles that grant access to them — the persistent memory the
`tools/matrix_provisioner` CLI never had.

The provisioning flow itself lives in `services/shared/matrix` and is shared with
that CLI, so the two cannot drift apart.

## Overview

```text
src/
├── core/
│   ├── models.py       # Pydantic models, bundle/payment state enums
│   ├── constants.py    # DI names, retention and polling defaults
│   ├── subscriptions.py # Google and internal entitlement state models
│   └── exceptions.py   # Domain exceptions
├── services/
│   ├── provisioning_repository.py  # Base SQLite persistence
│   ├── subscription_repository.py  # Play state, lineage, intents and escrow
│   ├── bundle_service.py           # Provision + persist, with rollback
│   ├── subscription_service.py     # Integrity + Publisher verification
│   ├── paid_bundle_service.py      # Idempotent encrypted bundle delivery
│   ├── subscription_reconciler.py  # Missed-RTDN repair and deadline checks
│   ├── redemption_poller.py        # Infers redemption from Synapse activity
│   └── retention_service.py        # Sync-room history purging
├── api/routes.py       # FastAPI routes
├── container.py        # Dependency injection
└── main.py             # Application entry point
```

## Provisioning never writes over an existing account

Synapse's `PUT /_synapse/admin/v2/users/{mxid}` is an **upsert**. On a localpart
that already has an account it resets that account's password and display name,
locking the real owner's devices out — and the orphan-account rollback would
then deactivate a live user. Checking our own database is not the same question,
because accounts created by the CLI (or any ordinary Synapse user) have no
record here at all. So the shared provisioner asks the homeserver first and
refuses on a hit, and a lookup that fails for any other reason is treated as
"unknown", never as "free". Both the web API and the CLI go through it.

That check and the creation are still two separate calls, so the service takes a
row in `provisioning_claims` for the localpart before touching Synapse at all.
Without it two concurrent requests for the same name both see "free" and the
second upserts over the first — leaving the first user holding a bundle whose
password no longer works. The primary key is the lock, so it holds across
processes, not just within one. Claims are released on every exit path, and a
claim older than `PROVISIONING_CLAIM_TTL_SECONDS` (5 minutes) can be taken over,
so a process killed mid-run does not strand the name.

## The bundle is shown once and never stored

`POST /bundles` returns the bundle string exactly once. Only a SHA-256
fingerprint is persisted, so a database compromise yields no usable credentials.
If the bundle is lost before it reaches the user, revoke the record and
provision a new account.

## Bundle lifecycle

```text
unused ──▶ redeemed ──▶ rotated
   │           │
   └───────────┴──────▶ revoked
```

`redeemed` means the homeserver shows a sign-in. `rotated` means the client
confirmed it replaced the temporary password. **The gap between them is the
partial-rotation window** — the account is live but the bundle password still
works — so a record stuck in `redeemed` is the thing to investigate.

Redemption is detected two ways:

- **Polling** (default, every 5 min) — reads each non-terminal account's devices
  from the Synapse admin API. Works against clients already in the field.
- **Client callback** — `POST /client/bundles/{id}/rotated`, exact and immediate.
  Deliberately on the regular API key so the Lotti app never needs admin
  credentials. ⚠️ **Served but not yet reachable in practice:** it addresses
  records by `bundle_id`, and the v2 bundle carries no bundle ID, so no client
  can call it today. Polling is currently the only live detection path. See
  `docs/implementation_plans/2026-08-07_matrix_provisioning_platform.md` §4 for
  the two ways to close this.

## Google Play SYNC subscriptions

The Play subscription backend is present but **disabled by default**. Set
`ENABLE_PLAY_SUBSCRIPTIONS=true` only after the Play Console, Google service
account, Pub/Sub push identity, encryption keys, reverse proxy and Synapse
suspension endpoint have all been configured. Startup resolves every required
security dependency and fails rather than accepting a purchase with partial
configuration.

The paid path does not trust a client purchase status. It creates a stable,
anonymous server entitlement and a one-time purchase intent, validates a fresh
Play Integrity verdict bound to the exact request, then queries
`purchases.subscriptionsv2.get`. Product, base plan, package, release
certificate, account binding, token lineage and production/test status all
have to match before the service stores the subscription or provisions Matrix.
The purchase is acknowledged only after the entitlement and encrypted bundle
claim are durable.

Paid bundle delivery differs deliberately from admin provisioning. A network
failure may retry the same authenticated claim for 24 hours, so the credential
is held in AES-256-GCM escrow instead of being lost after one response. The
server destroys that ciphertext only after it observes both the claim-bound
challenge in the Matrix room and proof that the bootstrap password no longer
authenticates. Expired unconfirmed claims deactivate the abandoned account and
destroy the escrow.

RTDN is a wake-up signal, never entitlement evidence. The push route verifies
Google's OIDC token, resolves only an already-bound purchase token, re-queries
Google, and then converges Matrix access. A periodic reconciler covers missed
or delayed notifications. When Play reports an access-granting state the Matrix
account is unsuspended; otherwise it is suspended reversibly. The service uses
Google's authoritative line-item `expiryTime` as the exact boundary. Configure
the Play Console grace period to **three days**; the service does not add a
second local grace interval.

## Configuration

| Variable | Required | Default | Description |
|---|---|---|---|
| `MATRIX_HOMESERVER` | Yes | — | Homeserver URL |
| `MATRIX_ADMIN_TOKEN` | Preferred | — | Long-lived Synapse admin access token |
| `MATRIX_ADMIN_USER` / `MATRIX_ADMIN_PASSWORD` | Fallback | — | Used only when no token is set |
| `API_KEYS` | Yes | — | Comma-separated client keys (rotation callback) |
| `ADMIN_API_KEYS` | Yes | — | Comma-separated admin keys (everything else) |
| `DB_PATH` | No | `data/provisioning.db` | SQLite location |
| `RETENTION_DAYS` | No | `30` | Default retention window (floor: 7) |
| `ENABLE_RETENTION_SWEEP` | No | `true` | **Scheduled purge, ON by default** — deletes data |
| `RETENTION_SWEEP_HOURS` | No | `24` | Interval between sweeps |
| `RETENTION_SWEEP_MEDIA` | No | `true` | Delete media in the sweep; false trims history only |
| `POLL_INTERVAL_SECONDS` | No | `300` | Redemption poll interval |
| `POLL_BATCH_SIZE` | No | `50` | Accounts checked per sweep |
| `ENABLE_REDEMPTION_POLLING` | No | `true` | Disable for tests or a read-only replica |
| `ENABLE_PLAY_SUBSCRIPTIONS` | No | `false` | Enables purchase routes, reconciliation and claim cleanup |
| `SUBSCRIPTION_ENCRYPTION_KEY_ID` | When enabled | — | Identifier for the active AES-256-GCM write key |
| `SUBSCRIPTION_ENCRYPTION_KEY_BASE64` | When enabled | — | Base64 for exactly 32 random bytes; encrypts tokens and pending bundles |
| `SUBSCRIPTION_DECRYPTION_KEYS_JSON` | No | `{}` | JSON string map of retired key IDs to Base64 keys retained for decryption during rotation |
| `PLAY_ACCOUNT_BINDING_KEY_BASE64` | When enabled | — | Base64 for at least 32 random bytes; HMAC key for stable obfuscated Play account IDs |
| `PLAY_BASE_PLAN_IDS` | No | `monthly,annual` | Comma-separated base plans accepted for `lotti_sync` |
| `PLAY_SIGNING_CERTIFICATE_SHA256` | When enabled | — | Comma-separated Play app signing certificate SHA-256 digests |
| `PLAY_ALLOW_TEST_PURCHASES` | No | `false` | Accept Play license-tester purchases; never enable in production |
| `PLAY_RTDN_AUDIENCE` | When enabled | — | Exact OIDC audience configured on the Pub/Sub push subscription |
| `PLAY_RTDN_SERVICE_ACCOUNT_EMAIL` | When enabled | — | Exact service-account identity allowed to push RTDN |
| `SUBSCRIPTION_RECONCILE_INTERVAL_SECONDS` | No | `60` | Authoritative Google refresh interval |
| `SUBSCRIPTION_RECONCILE_BATCH_SIZE` | No | `50` | Due subscriptions handled per reconciliation pass |
| `BUNDLE_CLAIM_REAPER_INTERVAL_SECONDS` | No | `300` | Expired paid-claim cleanup interval |
| `BUNDLE_CLAIM_REAPER_BATCH_SIZE` | No | `50` | Expired claims handled per cleanup pass |
| `CORS_ALLOWED_ORIGINS` | No | `http://localhost:5174` | Comma-separated origins |
| `PORT` | No | `8003` | Listen port |

Prefer `MATRIX_ADMIN_TOKEN`: it keeps no password at rest, is revocable
independently, and skips the login round trip. A blank value falls back to
password login rather than authenticating with an empty string.

Google authentication uses Application Default Credentials with the Android
Publisher and Play Integrity scopes. Prefer workload identity or a Secret Manager-mounted
credential; if a local JSON credential is unavoidable, point
`GOOGLE_APPLICATION_CREDENTIALS` at the mounted file and never bake it into the
image. Generate the two application secrets independently, for example with
`openssl rand -base64 32`.

For envelope-key rotation, deploy the new ID and key as the active pair and add
the previous pair to `SUBSCRIPTION_DECRYPTION_KEYS_JSON`. New rows immediately
use only the active key; authoritative subscription refreshes lazily re-encrypt
stored tokens, while pending escrow remains readable by its recorded key ID
until rotation or the 24-hour claim expiry destroys it. Remove a retired key
only after no non-null ciphertext refers to it and no backup that may be
restored depends on it.

## API

All paths are prefixed `/api/v1`. Existing `/client/*` paths take a regular API
key and all admin paths take an admin key. Subscription paths use their own
short-lived or entitlement-scoped bearer credentials and therefore never
expose the service-wide client key to the app. The RTDN path uses an
authenticated Pub/Sub OIDC bearer token. `/health` is unauthenticated.

That default is enforced, not just documented: the auth middleware is configured
with the client prefix rather than a list of admin prefixes, so a route added
later is privileged until someone deliberately opens it. The middleware also
sits *inside* CORS, so preflight `OPTIONS` requests — which browsers send with
no `Authorization` header — are answered rather than rejected.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/bundles` | Provision an account; returns the bundle **once** |
| `GET` | `/bundles` | List records (filter by `status`, `payment_status`) |
| `GET` | `/bundles/{id}` | Fetch one record |
| `PATCH` | `/bundles/{id}` | Update payment status and/or notes |
| `GET` | `/bundles/{id}/events` | Audit trail, most recent `limit` entries (default 200) |
| `GET` | `/bundles/{id}/usage` | Live device/media figures from Synapse |
| `POST` | `/bundles/{id}/revoke` | Revoke; optionally deactivate the account |
| `POST` | `/client/bundles/{id}/rotated` | Client confirms rotation (regular key) |
| `POST` | `/client/subscriptions/entitlements` | Create stable anonymous purchase identity |
| `POST` | `/client/subscriptions/purchase-intents` | Authorize one Play Billing launch |
| `POST` | `/client/subscriptions/purchases/verify` | Verify Integrity + Publisher state and provision/deliver |
| `POST` | `/client/subscriptions/bundle-claims/deliver` | Retry an authenticated lost bundle response |
| `POST` | `/client/subscriptions/bundle-claims/confirm-rotation` | Validate Matrix proof and destroy escrow |
| `POST` | `/google-play/rtdn` | Authenticated Pub/Sub notification signal |
| `GET` | `/stats` | Dashboard aggregates |
| `POST` | `/bundles/{id}/purge` | Purge one room's old history |
| `POST` | `/purges` | Purge every redeemed, non-revoked room |
| `GET` | `/purges`, `/purges/{purge_id}` | List / poll purge runs |

Purchase verification returns `bundle_import_required=true` with the
short-lived bundle fields for first provisioning. When a linked replacement
purchase recovers an account whose rotation was already confirmed, it returns
`bundle_import_required=false` with those fields set to `null` and restores the
existing Matrix account before responding. Destroyed bootstrap credentials are
never regenerated.

## Production deployment requirements

- Run exactly one service instance while `DB_PATH` points at SQLite. WAL,
  foreign keys, explicit write transactions and uniqueness constraints protect
  concurrent tasks inside that deployment, but SQLite cannot coordinate
  duplicate RTDN or provisioning work across hosts. Move the repository to a
  shared transactional database before adding replicas.
- Do not expose Uvicorn directly. Terminate TLS at a trusted reverse proxy and
  enforce body-size limits, per-IP/per-entitlement rate limits and request
  timeouts there, especially on entitlement creation and Play verification.
- Configure a dedicated least-privilege Play service account and a dedicated
  Pub/Sub push service account. The latter must match both
  `PLAY_RTDN_AUDIENCE` and `PLAY_RTDN_SERVICE_ACCOUNT_EMAIL` exactly.
- Verify the deployed Synapse exposes `PUT /_synapse/admin/v1/suspend/{user_id}`
  before enabling subscriptions. Suspension is intentionally reversible;
  deactivation would destroy device and encryption state needed after renewal.
- Configure the three-day grace period in Play Console and monitor
  reconciliation errors, unacknowledged purchases, RTDN delivery age, stale
  claims, and failed suspend/unsuspend operations.
- Back up the SQLite subscription and audit data, restrict filesystem access to
  the service user, and test restores with every still-required envelope key.
  Never include ciphertext columns in routine support exports or log raw
  purchase tokens, bearer secrets, Integrity tokens, bundles, or Google
  credentials.

## Retention

⚠️ **The scheduled sweep is ON by default and deletes data.** After the first
run, every redeemed, non-exempt user is trimmed to the retention window. Set
`ENABLE_RETENTION_SWEEP=false` to disable it, or exempt individual users. The
first sweep is delayed 5 minutes after startup so a bad deploy can be stopped.

Reclaiming disk needs **two** operations, because Synapse stores them
separately:

- `purge_history` removes room **events** from the database.
- Deleting the user's **media** removes the uploaded files.

Media is the bulk on a journalling app, so history-only runs free very little.
Both run by default.

Sync rooms are non-federated, so every event in them is *local*. The purge always
sends `delete_local_events: true` — without it Synapse reports success and frees
nothing.

Purging is safe because a device that missed data can still recover, but the
ordering matters. A reconnecting device walks the **room timeline first**; only
counters still missing after that walk escalate to peer-to-peer backfill, and
missing media is repaired by a broadcast any peer holding the blob may answer.
The retention window is therefore the bound on how long a device can be offline
and still resynchronise from the server alone.

A manual purge with no explicit window applies the **user's own** policy, the
same one the sweep would use. Falling back to the service default here would let
one "purge now" click delete far more than a pinned user is meant to keep.

### Purging destroys the record of what a user produced

Media *is* the data on a journalling app, so once a sweep runs the live figures
no longer show that the account ever held it — a two-year heavy user reads as
lighter than someone who joined last week. Each purge therefore records what it
actually reclaimed (`media_deleted`, `bytes_freed` on `purge_runs`), and
`/bundles/{id}/usage` reports:

| Field | Meaning |
|---|---|
| `media_length_bytes` | What the homeserver holds **now** |
| `purged_media_bytes` | Reclaimed by past purges, summed over the runs |
| `lifetime_media_bytes` | The two added together |

Summed from the runs rather than kept as a counter, so the total cannot drift
from the history it comes from. Two limits worth knowing: it counts bytes *at
rest on the server*, not what a device holds, and it only sees deletions this
service performed — media removed out of band is invisible to it. This figure is
also not reconstructible after the fact, which is why it is recorded at purge
time rather than derived later.

For a growth *curve* rather than a running total you would need periodic
sampling; the redemption poller cannot supply it, because it stops visiting an
account once the bundle is `rotated`.

### Per-user overrides

| Field | Meaning |
|---|---|
| `retention_days` | Window for this user; `null` follows the service default |
| `retention_exempt` | Skip this user in the scheduled sweep entirely |

Set both through `PATCH /bundles/{id}`. Clearing an override needs
`clear_retention_override: true`, because `null` already means "unchanged".

## Development

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-test.txt

# Tests run from the service directory; conftest adds services/ to sys.path
# so `shared.*` imports resolve the same way they do in Docker.
pytest tests/ -q
pytest tests/ -q --cov=src --cov=../shared/matrix --cov-report=term-missing
```

Run the whole stack with the SPA:

```bash
cd services && docker compose -f docker-compose.matrix-admin.yml up
```

## Relationship to the CLI

`tools/matrix_provisioner` still works and is the break-glass path if this
service is down. Both import `services/shared/matrix`; nothing in `services/`
depends on `tools/`.

Bundles created by the CLI are **not** tracked here — it writes to a file and
talks to Synapse directly. Use the web UI for anything that should appear in the
roster.
