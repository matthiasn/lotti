# Matrix provisioning platform — architecture and plan

**Status:** Phase 1 implemented, Phases 2–3 partially implemented, Phase 4 research only
**Date:** 2026-08-07

Extends the existing `tools/matrix_provisioner` CLI into a web application that
tracks who has been provisioned, whether their bundle was used, and what they
cost to host.

---

## 1. Findings that changed the brief

These came from reading the existing code, not from assumptions. Each one
invalidates something in the original request.

| Assumption in the brief | What the code actually does |
|---|---|
| Bundle is base64 `username:password` | Base64url (no padding) of a **JSON v2 object**: `{v, kind, homeServer, user, password, roomId}` (`provision.py:225-235`). Emitting `username:password` would be rejected by every shipped client. |
| Password rotation needs building | **Already implemented client-side** in Dart (`provisioning_controller.dart:142,209-223`), driven by `kind: "provisioned"`. |
| Provisioning creates a user | It also creates an **encrypted, non-federated sync room** and writes three state events. The room ID is part of the bundle. |
| CLI language unknown | Python 3.10+, `httpx` async, `pytest` + `MockTransport`, 29 existing tests. |

**The real Phase 2 gap** is therefore not rotation — it is that rotation happens
entirely on the client and *the server never finds out*. Everything below is
built around closing that observability gap rather than reimplementing rotation.

---

## 2. Architecture

The stack is not a green-field choice: `services/` already contains two FastAPI
services and a React SPA. This follows them exactly.

```
services/
├── shared/
│   ├── auth/                        # existing API-key middleware
│   └── matrix/                      # NEW — provisioning core, shared by CLI + service
│       ├── bundle.py                #   v2 bundle codec (the client contract)
│       ├── provisioner.py           #   account + sync room creation
│       └── admin_client.py          #   activity, media, purge queries
├── matrix-provisioning-service/     # NEW — FastAPI, port 8003, SQLite
└── matrix-admin/                    # NEW — React + Vite SPA, port 5174
tools/matrix_provisioner/            # now a thin CLI over shared/matrix
```

**Decisions**

| Area | Choice | Why |
|---|---|---|
| Backend | FastAPI + Pydantic + uvicorn | Matches `credits-service` exactly |
| Database | SQLite via `asyncio.to_thread` | Matches `credits-service`; a community server is nowhere near needing Postgres |
| Frontend | Separate Vite SPA (port 5174) | Your call — isolated deploy from the credits dashboard |
| Auth | Shared `APIKeyAuthMiddleware` | Admin key for provisioning; regular key for the client callback |
| Admin creds | Token preferred, password fallback | Your call — `MATRIX_ADMIN_TOKEN`, else user/password |
| CLI | Kept, sharing the core | Your call — break-glass path if the service is down |

### The one-way dependency rule

`tools/matrix_provisioner/provision.py` bootstraps `services/` onto `sys.path`
and imports the shared core. Nothing in `services/` imports from `tools/`. All
29 pre-existing CLI tests pass unchanged against the extracted core, which is
the evidence that the refactor preserved behaviour.

---

## 3. Persistence schema

`provisioned_users` — one row per provisioning event (bundle and account are 1:1,
because every run creates a fresh account):

| Column | Notes |
|---|---|
| `bundle_id` | UUID4, primary key |
| `username`, `user_mxid`, `home_server`, `server_name`, `room_id` | Identity; unique index on `(username, server_name)` |
| `status` | `unused` → `redeemed` → `rotated`, or `revoked` |
| `payment_status` | `unknown` / `paying` / `non_paying` / `complimentary` |
| `bundle_fingerprint` | SHA-256 of the encoded bundle — **not** the bundle |
| `created_at`, `first_login_at`, `rotated_at`, `revoked_at` | Lifecycle timestamps |
| `last_seen_at`, `last_polled_at` | Poller bookkeeping |
| `notes` | Free-form admin text |

Plus `bundle_events` (audit trail) and `purge_runs` (retention jobs).

### The bundle is never stored

The bundle contains a live password. It is returned **once** at creation and
discarded; only its SHA-256 fingerprint is persisted. A database compromise
therefore yields no usable credentials, and the fingerprint still lets you match
a bundle a user quotes in a support thread to its record.

The cost: losing the bundle before it reaches the user means revoking the record
and provisioning again. The UI states this and requires an explicit
acknowledgement before the bundle disappears.

---

## 4. Phase 2 — one-time rotation, end to end

Rotation already works. What follows is how the server learns about it.

```
Admin                Service              Synapse             Lotti client
  │  POST /bundles      │                    │                     │
  ├────────────────────►│  create user ─────►│                     │
  │                     │  mint 10-min token►│                     │
  │                     │  create room ─────►│                     │
  │  bundle (once)   ◄──┤  store record      │                     │
  │                     │  (fingerprint only)│                     │
  │─────────── bundle handed to user ──────────────────────────────►│
  │                     │                    │◄── /login (temp pw) ─┤
  │                     │                    │◄── join room ────────┤
  │                     │                    │◄── /account/password ┤  rotate
  │                     │◄─ POST /client/bundles/{id}/rotated ──────┤  (fast path)
  │                     │  status → rotated  │                     │
  │                     │                    │                     │
  │                     ├─ poll devices ────►│  (fallback, 5 min)  │
  │                     │  last_seen_ts set → status = redeemed    │
```

**Two detection paths, as you chose:**

- **Polling (works today, no client change).** Every 5 minutes the service asks
  Synapse for each non-terminal account's devices. A freshly provisioned account
  has exactly one device — the provisioner's own short-lived session — and no
  `last_seen_ts`. Once any device reports `last_seen_ts`, the bundle is marked
  `redeemed`.
- **Client callback — specified and served, but not yet called by any client.**
  `POST /api/v1/client/bundles/{id}/rotated` moves the record straight to
  `rotated`. Idempotent, and deliberately outside the admin path prefix so the
  app never needs an admin credential.

  ⚠️ **No Dart code was written for this, and the endpoint is not usable as it
  stands.** The route is implemented and tested server-side, but it addresses
  records by `bundle_id` — and **the v2 bundle carries no bundle ID**
  (`{v, kind, homeServer, user, password, roomId}`). A client has no way to
  learn it, so nothing can call this endpoint today.

  Two ways to close that, when the client work is actually scheduled:

  1. **Address by MXID instead** — `POST /api/v1/client/rotations` with
     `{"user": "@lotti_sync_user42:example.com"}`, and let the server map MXID →
     record. **Recommended:** it works with the *existing* bundle schema, so no
     bundle version bump and no coordinated release.
  2. **Add `bundleId` to a v3 bundle** — cleaner addressing, but it is a schema
     change to a contract the shipped client validates strictly, and v2 clients
     would have to keep working throughout.

  Until one of these lands, **polling is the only live detection path** and
  `rotated` is reachable only by an admin acting manually. The `redeemed` state
  is what the roster will actually show for real users.

**Why `redeemed` and `rotated` are separate:** the gap between them is the
partial-rotation window — the account is live but the bundle password still
works. A record sitting in `redeemed` for a long time is the signal that
rotation failed, and it is exactly what an admin should act on.

**Failure cases**

| Case | Handling |
|---|---|
| Bundle never redeemed | Stays `unused`; revoke with `deactivate_account=true` |
| Login succeeded, rotation failed | Sits in `redeemed`; visible in the roster |
| Provisioning fails mid-way | The core deactivates the orphan account (inherited from the CLI) |
| Record write fails after account creation | Service deactivates the account — an untracked live account is the worst outcome |
| Callback retried | Idempotent; `rotated_at` is stable |
| Bundle leaked | Revoke; optionally deactivate |

---

## 5. Phase 3 — tracking and stats

- **Active time** — `active_days`, counted from `first_login_at`, not
  `created_at`, so an unredeemed bundle does not read as an active user.
- **Per-user usage** — `GET /bundles/{id}/usage` reads device count, last seen
  and media bytes live from the Synapse admin API.
- **Dashboard** — `GET /stats` returns status counts, payment counts and
  sign-ups grouped by day.
- **Payment status** — a closed enum set manually today, designed so a provider
  webhook or Substack sync can drive the same field later with no schema change.

⚠️ **Not yet implemented:** per-user *message/event counts*. Synapse has no
first-class admin endpoint for this; it needs either a `/_synapse/admin/v1/rooms/{id}/messages`
walk or direct database access. Media usage and activity are done. Flagging
rather than silently omitting.

---

## 6. Retention and purging (30 days)

Implemented with a floor of 7 days, a **scheduled sweep that is on by default**,
and per-user overrides.

**Reclaiming disk needs two operations.** `purge_history` removes events from the
database; the uploaded files live in Synapse's separate media store and survive
it. On a journalling app the files are the bulk, so an events-only purge frees
almost nothing. Both run by default, and the API reports `bytes_freed` measured
before and after rather than a file count.

Media is recoverable on the same terms as events: a missing blob triggers a
broadcast repair request that any peer still holding the file may answer.

**Per-user control:** `retention_days` (null follows the service default) and
`retention_exempt` (skip the sweep entirely), both on `provisioned_users` with a
migration for existing databases.

⚠️ **The sweep is on by default**, so the first run after deploy trims every
redeemed, non-exempt user to the window. Guardrails: the 7-day floor applies to
every resolved window, the first sweep is delayed 5 minutes after startup, and
startup logs a warning. `ENABLE_RETENTION_SWEEP=false` disables it.

**Why 30 days is a real choice, not a free one.** A reconnecting device catches
up by walking the *room timeline* first — `BridgeCoordinator`'s anchored forward
walk over `/context` then `/messages?dir=f`, or a timestamp-bounded backward
walk. Only counters still missing after that walk are marked `missing` and
escalated to peer-to-peer repair via `BackfillRequestService.nudge()`. Room
replay is primary; backfill is the gap-repair fallback.

So the retention window is precisely **the bound on how long a device can be
offline and still resynchronise from the room alone**. Past it, repair depends on
a peer that still holds the payload. Usually fine — peers keep their own
database — but it is a dependency. The 7-day floor keeps the window clear of the
backfill amnesty period.

**The gotcha that would have made this a silent no-op:** sync rooms are created
with `m.federate: False` (`provision.py:166`), so every event in them is a
*local* event. Synapse's purge API defaults to `delete_local_events: false`,
under which purging these rooms reports success and frees **nothing**. The admin
client always sends the flag as true.

Failures are visible, not silent: an unrepairable entry retires to
`unresolvable` (reopenable) or `deleted`, never to silent data loss.

**Where retention can be set in Matrix, for reference:**

1. Per-room `m.room.retention` state event (MSC1763) — could be added to
   `createRoom`'s `initial_state`.
2. Synapse `homeserver.yaml` → `retention:` block. **Disabled by default** — with
   `enabled: false`, per-room retention events are stored but ignored.
3. `media_retention:` is separate and does *not* follow message retention — which
   matters, since media is the storage cost driver.

This service uses the Admin API purge directly, which is an operation rather
than a policy, and therefore controllable per user from the UI.

---

## 7. Payment providers

### ⛔ Digital River is not an option — it is insolvent

This is the headline finding, and it inverts the brief's framing.

Digital River stopped paying merchants in **July 2024** while continuing to
trade, declared bankruptcy for MyCommerce in **January 2025**, laid off 100+
staff, and **ceased most operations on 28 January 2025**, filing insolvency
proceedings for its German subsidiaries at the Cologne Insolvency Court. Some
merchants had six-figure sums trapped with no recovery path.

Do not evaluate it further. The comparison below is among the survivors.

### Comparison

| | **Stripe Managed Payments** (ex-Lemon Squeezy) | **Paddle** | **Stripe (direct)** | **Polar** |
|---|---|---|---|---|
| Merchant of record | ✅ Yes | ✅ Yes | ❌ **No — you are** | ✅ Yes |
| Headline fee | 5% + $0.50 | 5% + $0.50 | 2.9% + $0.30 | ~4% + $0.40 |
| EU VAT registration | Provider's | Provider's | **Yours** (OSS/IOSS) | Provider's |
| VAT remittance & liability | Provider | Provider | **You** | Provider |
| Tax coverage | US, EU, UK, AU + growing | Broadest; B2B reverse charge | Calculation only (Stripe Tax) | Good, narrower |
| Subscriptions | ✅ | ✅ (most mature) | ✅ | ✅ |
| Integration effort | Low | Low–medium | Medium (billing) + **high** (tax ops) | Low |
| Risk | Stripe-backed | Established, independent | Stripe-backed | Smallest vendor |

Lemon Squeezy was acquired by Stripe in July 2024; its technology is now the
foundation of **Stripe Managed Payments**, at the same 5% + $0.50, with a
migration path for existing Lemon Squeezy users.

### Recommendation: Stripe Managed Payments, billed annually

**Use a merchant of record.** You operate a German GmbH taking recurring
payments from EU consumers. Doing that as your own merchant means OSS
registration, per-country VAT rates, returns and audit exposure. Stripe direct
is only cheaper if you value your compliance time at zero — for a community
server this is the dominant cost, not the 2% fee delta.

**Then bill annually, not monthly.** This matters more than the provider choice:

| Contribution | Monthly billing | Annual billing |
|---|---|---|
| €3/mo | €0.65/mo fee → **21.7%** | €2.66/yr → **7.4%** |
| €5/mo | €0.75/mo → **15.0%** | €3.50/yr → **5.8%** |

The **$0.50 fixed component dominates** at community-contribution amounts.
Monthly billing at €3 loses over a fifth of every payment to fees. Annual
billing roughly cuts that by two thirds and reduces failed-payment churn.
If monthly is a hard requirement, price at €5+ rather than €3.

Paddle is the reasonable alternative if you later need B2B reverse-charge
invoicing. Polar is cheaper but the smallest vendor — and Digital River is
exactly the lesson about vendor solvency risk.

---

## 8. Substack integration — feasibility

**Substack has no public API and no webhooks.** That is the whole constraint.

| Approach | Verdict |
|---|---|
| Manual CSV export → mark `paying` | ✅ **Viable now.** Subscribers page → ⋯ → Export. Fits the existing manual payment field exactly. |
| Zapier bridge | ⚠️ Partial. Can trigger on new subscribers; not a reliable source of truth for *lapsed* paid status. |
| Official API | ❌ Does not exist. |
| Scraping | ❌ Fragile and against terms. |

⚠️ **A trap worth knowing:** since Substack's August 2025 iOS in-app purchase
rollout, subscribers acquired through IAP are tied to the platform — if you ever
leave Substack, their email exports but the paid relationship does not. Do not
build Substack into the critical path for sync access.

**Recommended:** a periodic CSV import that sets `payment_status` in bulk,
reusing the existing manual field. Treat Substack as a *perk source*, not the
system of record.

---

## 9. What is built vs. what is not

**Built and tested (213 backend + 46 frontend + 33 CLI tests passing):**
shared provisioning core; bundle codec; SQLite persistence and state machine;
bundle creation, listing, update, revocation; redemption poller; stats; usage;
retention/purge; admin SPA with provision, roster and overview pages;
Docker + compose.

**Not built — no Dart/Flutter code was touched in this change at all:**

- **Client rotation callback wiring.** The server route exists but is
  unaddressable (see §4); no client calls it. Documented only.
- Per-user message counts — needs a Synapse room walk or DB access.
- Substack CSV import; payment provider integration.
- Self-service portal (Phase 4); session-based admin auth.

---

## 10. Security notes

- The bundle is never persisted — only a SHA-256 fingerprint.
- Admin token preferred over password; a blank env var falls back rather than
  authenticating as an empty string.
- MXIDs and room IDs are percent-encoded in every path (inherited from the CLI).
- The client rotation callback is on the regular API key, not the admin key.
- Auth is **default-deny by path**: the middleware is configured with the client
  prefix rather than a list of admin prefixes, so a route added later requires an
  admin key until someone deliberately opens it.
- Auth sits *inside* CORS, so preflight `OPTIONS` (sent without an
  `Authorization` header) is answered rather than 401'd — otherwise
  `CORS_ALLOWED_ORIGINS` could never work.
- Provisioning refuses to write over an account that already exists on the
  homeserver. `PUT /_synapse/admin/v2/users/{mxid}` is an upsert, so without the
  check a name collision would reset a live user's password.
- Neither API key has a default anywhere — compose, Dockerfile or SPA. A
  checked-in default in a public repository is a published credential.
- ⚠️ **`VITE_ADMIN_API_KEY` is embedded in the SPA bundle**, exactly as
  `services/dashboard` does. It grants account provisioning. This app must sit
  behind a reverse proxy with its own authentication, or move to session-based
  auth, before any untrusted network path exists.

### Bug found in shared code

`services/shared/auth/middleware.py` raised `HTTPException` from inside a
`BaseHTTPMiddleware`, which sits *above* Starlette's `ExceptionMiddleware` — so
auth failures returned **500 instead of 401/403**. This affected
`credits-service` and `ai-proxy-service` too. Fixed to return a `JSONResponse`.
Neither service asserted on auth status codes, so no tests broke; all 38
credits-service unit tests still pass.
