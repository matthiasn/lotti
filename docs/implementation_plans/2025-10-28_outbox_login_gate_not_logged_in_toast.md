# Outbox Login Gate — Pause Processing, One‑Time “Not Logged In” Toast

## Summary

- When sync is configured but the user is not logged in, the outbox still attempts to process and wastes retries. We will pause processing while logged out and show a one‑time red toast to explain why.
- Use a simple guard in `OutboxService.sendNext()` and a StreamBuilder‑driven UI toast. No DB mutations while logged out; pending items resume automatically after login.

## Goals

- Block outbox processing when Matrix is not logged in (regardless of feature flag).
- Do not mutate outbox rows while logged out; leave items pending (no retries consumed).
- Show a one‑time per login session red toast: “Sync is not logged in”.
- Keep analyzer/test clean; preserve behavior when logged in.

## Non‑Goals

- No schema changes to `outbox`.
- No changes to login flows; toast only.

## Findings

- Processing path: `OutboxService` drives queue draining via `sendNext()`/`_processor.processQueue()`.
- Today only the feature flag gates `sendNext()`; login state is not considered.
- Login state is available (`MatrixService.isLoggedIn()`) and via `client.onLoginStateChanged.stream`.
- UI already uses SnackBars; Outbox Monitor handles retry actions.

## Design Overview

1) Process gate on login state
- Outbox processing runs only when both: feature flag enabled and `MatrixService.isLoggedIn()` is true.
- If not logged in when triggered, do not call the processor.

2) Pause processing while not logged in
- Do not drain or update outbox items; keep them pending.
- Avoid aggressive immediate re‑scheduling while logged out; rely on normal triggers after login.

3) One‑time red toast via StreamBuilder
- Add a top‑level StreamBuilder (e.g., in `BeamerApp`) that listens to a not‑logged‑in signal.
- When sync is enabled and the signal indicates “not logged in,” show a red SnackBar (`syncNotLoggedInToast`) once per login session.
- Maintain a simple per‑login guard; reset the guard on login state changes so the toast can re‑appear on a future logout.

## Data Flow & API Changes

- No repository changes.

- OutboxService
  - Call `_matrixService.isLoggedIn()` directly; if false, return early without draining.
  - Keep scheduling conservative while logged out (no tight loops).

- Not‑logged‑in stream for UI (StreamBuilder)
  - Option A (preferred): Extend `OutboxState` with `notLoggedIn` and have `OutboxCubit` derive it from the feature flag and login stream. Use `StreamBuilder<OutboxState>` on `cubit.stream` to drive the toast.
  - Option B: Use `StreamBuilder<LoginState>` on `matrixService.client.onLoginStateChanged.stream` combined with the feature flag stream to compute “not logged in”.

## UX & Localization

- Text: “Sync is not logged in”.
- Style: SnackBar with `colorScheme.error` background and `onError` foreground.
- L10n: add `syncNotLoggedInToast` to `lib/l10n/*.arb`; run `make l10n`.

## Implementation Phases

### Phase 1 — Service Gate (P0)
- In `OutboxService.sendNext()`, after checking the feature flag:
  - If not logged in: return early; do not drain; no retries consumed.
  - Else: unchanged drain behavior.

### Phase 2 — One‑Time Warning via StreamBuilder (P0)
- Implement Option A or B from “Not‑logged‑in stream for UI”.
- Add a top‑level StreamBuilder in `BeamerApp` (or a sync page shell) to show the red SnackBar when the stream indicates not logged in and the feature flag is on.
- Maintain a per‑login guard that resets on login state changes.

### Phase 3 — UX polish (P1)
- Adjust `OutboxBadgeIcon` disabled state (ingray) when the feature flag is on but login is missing.
- Add “Retry All Errors” action in Outbox Monitor (independent of this change).

## Testing & Verification

- Unit tests
  - OutboxService when logged out: `sendNext()` does not call `_processor.processQueue()`; no DB mutations; no spin.
  - OutboxService when logged in: unchanged behavior; drain scheduling works.
  - OutboxCubit (Option A): derives `notLoggedIn` correctly from flag + login stream.

- Widget/Integration tests
  - StreamBuilder shows toast once per login session on not‑logged‑in transition; guard resets on login.
  - Items remain Pending while logged out; resume processing after login without manual intervention.

- Analyzer & format
  - `make analyze` clean; `dart format .` as needed.

## Performance & Telemetry

- Eliminates wasted retries and network calls while logged out.
- Consider logging `OUTBOX loginGate.triggered` once per login session to confirm behavior.

## Rollout Plan

1) Implement Phase 1 (service gate) with targeted unit tests.
2) Implement Phase 2 (StreamBuilder toast) and add a widget test.
3) Implement Phase 3 polish.
4) Update docs and CHANGELOG; run analyzer/tests.

## Touch Points (proposed)

- `lib/features/sync/outbox/outbox_service.dart` (gate only)
- Option A: `lib/blocs/sync/outbox_state.dart` (`notLoggedIn`), `lib/blocs/sync/outbox_cubit.dart` (derive state)
- `lib/beamer/beamer_app.dart` (top‑level StreamBuilder for SnackBar)
- `lib/l10n/*.arb` (new `syncNotLoggedInToast` string)

## Implementation Checklist

- [ ] Wire `isLoggedIn` gate in `OutboxService.sendNext()`
- [ ] Option A: Extend `OutboxState` with `notLoggedIn` and update `OutboxCubit`
- [ ] Add top‑level StreamBuilder that shows red SnackBar (`syncNotLoggedInToast`) once per login session; reset guard on login
- [ ] Optional: adjust `OutboxBadgeIcon` disabled state when login missing
- [ ] Optional: “Retry All Errors” action in Outbox Monitor
- [ ] Add localization key; run `make l10n`
- [ ] Analyzer: zero warnings; format code; run targeted tests
- [ ] Update docs/sync/sync_summary.md and CHANGELOG.md

## Notes

- Gate lives in `OutboxService.sendNext()` to keep processing policy close to scheduling.
- Pending items remain pending while logged out; no retries consumed.
- Toast guard resets on login state changes (i.e., per login session), not by app launch alone.

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.

