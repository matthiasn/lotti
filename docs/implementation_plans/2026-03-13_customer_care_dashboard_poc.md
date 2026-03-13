# Customer Care Dashboard — Proof of Concept

## Goal

Build a management dashboard for customer care agents to view user details,
token usage, account balances, and transactions. The dashboard is a lightweight
web frontend backed by new API endpoints on the existing `credits-service` and
`ai-proxy-service`. Initial scope is Gemini-only; architecture reviews happen
after a usable version is ready.

## Hard Facts

### What exists today

- **credits-service** (FastAPI + TigerBeetle):
  - `POST /api/v1/accounts` — create account
  - `POST /api/v1/balance` — get balance for one user
  - `POST /api/v1/topup` — add credits
  - `POST /api/v1/bill` — deduct credits
  - `GET /api/v1/health` — health check
  - All amounts stored in cents (USD × 100)
  - User IDs hashed to 128-bit TigerBeetle account IDs via SHA-256
  - System account (ID=1) for minting; user accounts enforce no-overdraft

- **ai-proxy-service** (FastAPI + Gemini):
  - `POST /v1/chat/completions` — OpenAI-compatible Gemini proxy
  - `GET /metrics` — in-memory aggregate metrics (not per-user, not persistent)
  - Billing service calculates cost and optionally calls credits-service
  - Model pricing hardcoded in `constants.py`

- **No web frontend exists** — backend-only microservices
- **No user listing endpoint** — can create/query individual users only
- **No transaction history** — TigerBeetle stores transfers but no query API
- **No per-user usage tracking** — only system-wide in-memory counters
- **No persistent request log** — usage data lost on service restart

### Current limitations

- Inference providers limited to Gemini (acceptable for PoC)
- Payments can be stubbed / added via CLI for now
- No authentication beyond API key (no role-based access)

## Scope

### In scope

1. Backend: new API endpoints for listing users, transaction history,
   per-user token usage, and model pricing CRUD
2. Persistent usage logging (per-request, per-user)
3. Web frontend: user list, user detail page, token usage charts, balance view
4. Model pricing management UI
5. Tests for all new backend endpoints and frontend components
6. CHANGELOG + metainfo update at the end

### Out of scope

- User authentication / RBAC (API key auth is sufficient for PoC)
- Real payment gateway integration (CLI top-ups are fine)
- Multi-provider support beyond Gemini
- Mobile-optimized UI
- Real-time WebSocket updates
- Deployment / CI pipeline changes

---

## Architecture

```
┌─────────────────────┐
│  Dashboard Frontend  │  (React + Vite, runs on :5173)
│  services/dashboard/ │
└────────┬────────────┘
         │ REST calls
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────────┐
│credits │ │ai-proxy    │
│service │ │service     │
│ :8001  │ │ :8002      │
└───┬────┘ └─────┬──────┘
    │            │
    ▼            ▼
┌────────┐ ┌──────────┐
│Tiger-  │ │usage_log │
│Beetle  │ │(SQLite)  │
└────────┘ └──────────┘
```

The dashboard frontend talks directly to both services. A lightweight SQLite
database in ai-proxy-service persists per-request usage logs (model, tokens,
cost, user_id, timestamp) so they survive restarts and are queryable.

---

## Implementation Plan

### Phase 1 — Backend: Credits Service Extensions

#### Step 1.1: Add user registry table and list endpoint

TigerBeetle accounts are identified by 128-bit hashes — there is no way to
reverse-lookup user IDs. We need a lightweight user registry.

**Files to create/modify:**

- `services/credits-service/src/core/models.py` — add `UserListResponse`,
  `UserInfo` models
- `services/credits-service/src/core/interfaces.py` — add
  `IUserRegistryService` interface
- `services/credits-service/src/services/user_registry_service.py` — **new**,
  SQLite-backed user registry (stores `user_id`, `created_at`, `display_name`)
- `services/credits-service/src/services/account_service.py` — on account
  creation, also register user in registry
- `services/credits-service/src/api/routes.py` — add
  `GET /api/v1/users` (list all users, paginated) and
  `GET /api/v1/users/{user_id}` (single user details with balance)
- `services/credits-service/src/container.py` — wire up new service

**Tests:**

- `services/credits-service/tests/unit/test_user_registry_service.py` — **new**
  - register user, list users, get single user, pagination, duplicate handling
- `services/credits-service/tests/unit/test_routes_users.py` — **new**
  - endpoint response shapes, 404 for unknown user, pagination params
- Update `services/credits-service/tests/integration/test_e2e_flow.py` —
  verify account creation also registers user

#### Step 1.2: Add transaction history endpoint

TigerBeetle transfers are immutable but the Python SDK does not expose a
"list transfers for account" query. We log transactions in a local SQLite
table alongside TigerBeetle writes.

**Files to create/modify:**

- `services/credits-service/src/core/models.py` — add
  `TransactionRecord`, `TransactionListResponse`
- `services/credits-service/src/core/interfaces.py` — add
  `ITransactionLogService`
- `services/credits-service/src/services/transaction_log_service.py` — **new**,
  SQLite table: `id`, `user_id`, `type` (topup/bill), `amount_cents`,
  `description`, `balance_after_cents`, `created_at`
- `services/credits-service/src/services/billing_service.py` — after
  successful topup/bill, write to transaction log
- `services/credits-service/src/api/routes.py` — add
  `GET /api/v1/users/{user_id}/transactions` (paginated, newest-first)
- `services/credits-service/src/container.py` — wire up

**Tests:**

- `services/credits-service/tests/unit/test_transaction_log_service.py` —
  **new**, insert, query, pagination, ordering, filtering by type
- `services/credits-service/tests/unit/test_routes_transactions.py` — **new**,
  endpoint response shapes, empty history, pagination
- Update integration test to verify transactions appear after topup/bill

---

### Phase 2 — Backend: AI Proxy Service Extensions

#### Step 2.1: Persistent per-request usage logging

Replace the in-memory-only metrics with a persistent SQLite usage log.

**Files to create/modify:**

- `services/ai-proxy-service/src/core/models.py` — add `UsageLogEntry`,
  `UsageQueryResponse`, `UserUsageSummary`
- `services/ai-proxy-service/src/core/interfaces.py` — add
  `IUsageLogService`
- `services/ai-proxy-service/src/services/usage_log_service.py` — **new**,
  SQLite table: `id`, `user_id`, `model`, `prompt_tokens`, `completion_tokens`,
  `total_tokens`, `cost_usd`, `request_id`, `created_at`
- `services/ai-proxy-service/src/api/routes.py` — after billing, write to
  usage log; add new endpoints:
  - `GET /api/v1/usage/user/{user_id}` — per-user usage history (paginated)
  - `GET /api/v1/usage/summary` — system-wide summary (total tokens, cost,
    breakdown by model)
  - `GET /api/v1/usage/user/{user_id}/summary` — per-user summary
- `services/ai-proxy-service/src/container.py` — wire up

**Tests:**

- `services/ai-proxy-service/tests/unit/test_usage_log_service.py` — **new**,
  insert, query by user, summary aggregation, date range filtering
- `services/ai-proxy-service/tests/unit/test_routes_usage.py` — **new**,
  endpoint response shapes, empty results, pagination

#### Step 2.2: Model pricing management API

Move pricing from hardcoded constants to a configurable SQLite-backed store
with CRUD endpoints.

**Files to create/modify:**

- `services/ai-proxy-service/src/core/models.py` — add `ModelPricing`,
  `ModelPricingListResponse`, `ModelPricingUpdateRequest`
- `services/ai-proxy-service/src/core/interfaces.py` — add
  `IPricingService`
- `services/ai-proxy-service/src/services/pricing_service.py` — **new**,
  SQLite table: `model_id`, `display_name`, `input_price_per_1k`,
  `output_price_per_1k`, `updated_at`. Seed from current `MODEL_PRICING`
  constants on first run.
- `services/ai-proxy-service/src/services/billing_service.py` — read pricing
  from `PricingService` instead of `MODEL_PRICING` constant dict
- `services/ai-proxy-service/src/api/routes.py` — add:
  - `GET /api/v1/pricing` — list all model pricing
  - `PUT /api/v1/pricing/{model_id}` — update pricing for a model
  - `POST /api/v1/pricing` — add new model pricing
- `services/ai-proxy-service/src/core/constants.py` — keep as seed data only

**Tests:**

- `services/ai-proxy-service/tests/unit/test_pricing_service.py` — **new**,
  seed data loaded, CRUD operations, billing reads from service
- `services/ai-proxy-service/tests/unit/test_routes_pricing.py` — **new**,
  list, update, create, validation errors

---

### Phase 3 — Web Frontend: Dashboard

Technology choice: **React + TypeScript + Vite** — lightweight, fast to
prototype, good charting ecosystem (recharts).

#### Step 3.1: Project scaffolding

**Files to create:**

- `services/dashboard/package.json` — React 18, TypeScript, Vite, recharts,
  axios
- `services/dashboard/tsconfig.json`
- `services/dashboard/vite.config.ts` — proxy `/api` to credits-service,
  `/v1` to ai-proxy-service
- `services/dashboard/index.html`
- `services/dashboard/src/main.tsx` — entry point
- `services/dashboard/src/App.tsx` — router setup (react-router-dom)
- `services/dashboard/src/api/client.ts` — axios instance with API key header
- `services/dashboard/src/api/credits.ts` — typed API calls to credits-service
- `services/dashboard/src/api/proxy.ts` — typed API calls to ai-proxy-service
- `services/dashboard/src/types/index.ts` — shared TypeScript types matching
  backend models

#### Step 3.2: User list page

**Files to create:**

- `services/dashboard/src/pages/UserListPage.tsx` — table of users with
  columns: user ID, display name, created date, balance. Click row → detail.
- `services/dashboard/src/components/UserTable.tsx` — sortable, paginated table
- `services/dashboard/src/components/Layout.tsx` — nav bar, page wrapper

**Tests:**

- `services/dashboard/src/__tests__/UserListPage.test.tsx` — renders table,
  pagination, loading state, error state
- `services/dashboard/src/__tests__/UserTable.test.tsx` — sorting, row click

#### Step 3.3: User detail page

**Files to create:**

- `services/dashboard/src/pages/UserDetailPage.tsx` — header (name, balance),
  tabs for: transactions, token usage, usage by model
- `services/dashboard/src/components/BalanceCard.tsx` — current balance display
- `services/dashboard/src/components/TransactionList.tsx` — paginated
  transaction history (date, type, amount, description, balance after)
- `services/dashboard/src/components/TokenUsageChart.tsx` — recharts bar/line
  chart: input vs output tokens over time
- `services/dashboard/src/components/ModelBreakdownChart.tsx` — pie chart of
  token usage by model
- `services/dashboard/src/components/UsageSummaryCards.tsx` — total tokens,
  total cost, average per request

**Tests:**

- `services/dashboard/src/__tests__/UserDetailPage.test.tsx` — renders all
  sections, handles loading/error, tab switching
- `services/dashboard/src/__tests__/TransactionList.test.tsx` — renders rows,
  pagination, empty state
- `services/dashboard/src/__tests__/TokenUsageChart.test.tsx` — renders with
  data, handles empty data

#### Step 3.4: System overview page

**Files to create:**

- `services/dashboard/src/pages/SystemOverviewPage.tsx` — system-wide stats:
  total users, total tokens, total cost, requests per day
- `services/dashboard/src/components/SystemStatsCards.tsx` — summary cards
- `services/dashboard/src/components/SystemUsageChart.tsx` — daily
  tokens/cost chart

**Tests:**

- `services/dashboard/src/__tests__/SystemOverviewPage.test.tsx` — renders
  stats, handles loading

#### Step 3.5: Model pricing management page

**Files to create:**

- `services/dashboard/src/pages/PricingPage.tsx` — table of model pricing
  with inline edit
- `services/dashboard/src/components/PricingTable.tsx` — editable table with
  save/cancel per row
- `services/dashboard/src/components/AddPricingModal.tsx` — modal for adding
  new model pricing

**Tests:**

- `services/dashboard/src/__tests__/PricingPage.test.tsx` — renders table,
  edit flow, add flow, validation

---

### Phase 4 — Integration, Polish, and Documentation

#### Step 4.1: Docker Compose integration

**Files to modify:**

- `services/credits-service/docker-compose.yml` — add SQLite volume mount
- `services/ai-proxy-service/docker-compose.yml` — add SQLite volume mount

**Files to create:**

- `services/docker-compose.dashboard.yml` — **new**, orchestrates all three
  services (TigerBeetle, credits-service, ai-proxy-service, dashboard) for
  local development

#### Step 4.2: CORS and proxy configuration

**Files to modify:**

- `services/credits-service/src/main.py` — add dashboard origin to CORS
- `services/ai-proxy-service/src/main.py` — add dashboard origin to CORS

#### Step 4.3: End-to-end smoke test

**Files to create:**

- `services/dashboard/e2e/smoke.test.ts` — **new**, basic flow: create user
  via API → see user in list → view detail page → verify balance

#### Step 4.4: Documentation and changelog

**Files to modify:**

- `CHANGELOG.md` — add entry under current version
- `flatpak/com.matthiasn.lotti.metainfo.xml` — matching entry
- `services/credits-service/README.md` — document new endpoints
- `services/ai-proxy-service/README.md` — document new endpoints

**Files to create:**

- `services/dashboard/README.md` — setup, development, architecture overview

---

## Execution Order

```
Phase 1 (credits-service backend)
  ├── Step 1.1: User registry + list endpoint
  └── Step 1.2: Transaction history endpoint

Phase 2 (ai-proxy-service backend)     ← can start in parallel with Phase 1
  ├── Step 2.1: Persistent usage logging
  └── Step 2.2: Model pricing management

Phase 3 (dashboard frontend)           ← depends on Phase 1 + 2 endpoints
  ├── Step 3.1: Project scaffolding
  ├── Step 3.2: User list page
  ├── Step 3.3: User detail page
  ├── Step 3.4: System overview page
  └── Step 3.5: Pricing management page

Phase 4 (integration + docs)           ← depends on Phase 3
  ├── Step 4.1: Docker Compose
  ├── Step 4.2: CORS config
  ├── Step 4.3: E2E smoke test
  └── Step 4.4: CHANGELOG + docs
```

## Test Summary

| Area | Test files | Coverage target |
|------|-----------|-----------------|
| User registry service | `test_user_registry_service.py` | CRUD, pagination, duplicates |
| User routes | `test_routes_users.py` | All response codes, pagination |
| Transaction log service | `test_transaction_log_service.py` | Insert, query, filter, order |
| Transaction routes | `test_routes_transactions.py` | Response shapes, empty/paginated |
| Usage log service | `test_usage_log_service.py` | Insert, query, aggregation |
| Usage routes | `test_routes_usage.py` | Response shapes, pagination |
| Pricing service | `test_pricing_service.py` | Seed, CRUD, billing integration |
| Pricing routes | `test_routes_pricing.py` | List, update, create, validation |
| Integration (credits) | `test_e2e_flow.py` (update) | Full user lifecycle |
| Frontend: UserList | `UserListPage.test.tsx` | Render, pagination, states |
| Frontend: UserDetail | `UserDetailPage.test.tsx` | Tabs, data display, states |
| Frontend: Transactions | `TransactionList.test.tsx` | Rows, pagination, empty |
| Frontend: Charts | `TokenUsageChart.test.tsx` | Data rendering, empty |
| Frontend: System | `SystemOverviewPage.test.tsx` | Stats rendering |
| Frontend: Pricing | `PricingPage.test.tsx` | Edit, add, validation |
| E2E smoke | `smoke.test.ts` | Happy path through full stack |

## Decisions

1. **User ID format** — UUID. Dashboard search and display use UUIDs.
2. **Data retention** — 90 days for usage logs, configurable via env var.
3. **Access control** — reuse existing service API keys for PoC.
4. **Hosting** — local only for PoC (dashboard on :5173, services on
   :8001/:8002).
