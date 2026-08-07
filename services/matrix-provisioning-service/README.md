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
│   └── exceptions.py   # Domain exceptions
├── services/
│   ├── provisioning_repository.py  # SQLite persistence (data/provisioning.db)
│   ├── bundle_service.py           # Provision + persist, with rollback
│   ├── redemption_poller.py        # Infers redemption from Synapse activity
│   └── retention_service.py        # Sync-room history purging
├── api/routes.py       # FastAPI routes
├── container.py        # Dependency injection
└── main.py             # Application entry point
```

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
| `CORS_ALLOWED_ORIGINS` | No | `http://localhost:5174` | Comma-separated origins |
| `PORT` | No | `8003` | Listen port |

Prefer `MATRIX_ADMIN_TOKEN`: it keeps no password at rest, is revocable
independently, and skips the login round trip. A blank value falls back to
password login rather than authenticating with an empty string.

## API

All paths are prefixed `/api/v1`. Everything requires an **admin** key except
`/client/*`, which takes a regular key. `/health` is unauthenticated.

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/bundles` | Provision an account; returns the bundle **once** |
| `GET` | `/bundles` | List records (filter by `status`, `payment_status`) |
| `GET` | `/bundles/{id}` | Fetch one record |
| `PATCH` | `/bundles/{id}` | Update payment status and/or notes |
| `GET` | `/bundles/{id}/events` | Audit trail |
| `GET` | `/bundles/{id}/usage` | Live device/media figures from Synapse |
| `POST` | `/bundles/{id}/revoke` | Revoke; optionally deactivate the account |
| `POST` | `/client/bundles/{id}/rotated` | Client confirms rotation (regular key) |
| `GET` | `/stats` | Dashboard aggregates |
| `POST` | `/bundles/{id}/purge` | Purge one room's old history |
| `POST` | `/purges` | Purge every redeemed, non-revoked room |
| `GET` | `/purges`, `/purges/{purge_id}` | List / poll purge runs |

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
