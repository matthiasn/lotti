# Outbox Login Gate — Pause Processing, One‑Time “Not Logged In” Toast

## Summary

- When sync is configured but the user is not logged in, the outbox still attempts to process and wastes retries. We will pause processing while logged out and show a one‑time red toast to explain why.
- Use a simple guard in `OutboxService.sendNext()` and a StreamBuilder‑driven UI toast. No DB mutations while logged out; pending items resume automatically after login.

### 2025‑10‑29 Update — Connectivity regain didn’t auto‑send until a new item was created

- Field observation: after landing (network available and other apps online), pending outbox items did not start sending. Creating a new item immediately triggered sends.
- Expected behavior: connectivity detection should reliably nudge the outbox to send pending items once the Matrix client is logged in again, without requiring a new enqueue.

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

### New findings (connectivity + login interaction)

- Outbox already listens to connectivity regain and enqueues a send: `OutboxService` subscribes to `Connectivity().onConnectivityChanged` and calls `_clientRunner.enqueueRequest(...)` when any of `[wifi, mobile, ethernet]` is present.
- `sendNext()` has a login gate; if the Matrix client isn’t logged in yet, it returns early and emits a one‑time UI event. There is no follow‑up nudge when the client later reports `loggedIn`.
- MatrixService separately nudges its pipeline on connectivity regain (forces a rescan), but that doesn’t enqueue the outbox.
- Net effect: if the connectivity nudge fires before login completes, Outbox idles until another event (e.g., creating a new item) enqueues a request.

## Design Overview

1) Process gate on login state
- Outbox processing runs only when both: feature flag enabled and `MatrixService.isLoggedIn()` is true.
- If not logged in when triggered, do not call the processor.

2) Pause processing while not logged in
- Do not drain or update outbox items; keep them pending.
- Avoid aggressive immediate re‑scheduling while logged out; rely on normal triggers after login.

3) One‑time red toast (event‑driven)
- Show a red SnackBar (`syncNotLoggedInToast`) once per login session, but only when the outbox actually attempts to send and is blocked by the login gate.
- Maintain a simple per‑login guard; reset the guard on login state changes so the toast can re‑appear on a future logout.

4) Robust recovery on connectivity regain (new)
- Subscribe Outbox to the Matrix login state stream and enqueue immediately on `LoginState.loggedIn`. This guarantees that a connectivity nudge which arrived “too early” (pre‑login) still results in sending once login completes.
- Optionally add a bounded follow‑up nudge sequence after connectivity regain while logged out (e.g., schedule re‑nudges at 1s and 5s) to catch staggered login without spinning.

5) Reduce startup toast noise (new)
- Emit the login‑gate toast only if there are pending outbox items at the moment of the gate.
- Add a short startup grace window before surfacing the toast to avoid alarming users during normal boot/login initialization.

### Post‑Implementation Update (2025‑10‑28) — Startup toast regression and fix

- Introduced problem
  - After the initial implementation, the app showed the red “Sync is not logged in” toast on app startup whenever sync was enabled but the user had not logged in yet. This was noisy and misleading because no send had been attempted yet.

- Root cause
  - The UI computed a “not logged in” condition (sync flag × login state) in `AppScreen.build()` and immediately triggered the toast, leading to a startup‑time SnackBar before any actual outbox activity.

- Fix (event‑driven toast)
  - Move toast triggering behind an explicit outbox login‑gate event so it only fires when the outbox tries to send and is prevented by being logged out.
  - OutboxService now exposes a `notLoggedInGateStream` and emits when `sendNext()` returns early due to `!isLoggedIn`.
  - `AppScreen` subscribes to this stream via the `outboxServiceProvider` and shows the one‑time red toast upon receiving the event. The guard resets when the user logs in or sync is disabled.

- Code changes
  - `lib/features/sync/outbox/outbox_service.dart`
    - Added `StreamController<void>` and public `notLoggedInGateStream`.
    - On login gate in `sendNext()`, emit to the stream (no aggressive rescheduling).
  - `lib/beamer/beamer_app.dart`
    - Removed the eager, startup‑time toast check from `build()`.
    - Subscribed to `outboxServiceProvider.notLoggedInGateStream` and deferred showing the toast to after frame.

- Tests
  - Updated widget test to assert no toast on startup and that a toast appears only after emitting an outbox login‑gate event:
    - `test/beamer/not_logged_in_toast_test.dart`

- Outcome
  - Users no longer see a red toast on app launch when they simply haven’t logged in yet. The toast appears only when it is actionable/relevant—i.e., when the outbox attempts to send and is blocked by login state.

### 2025‑10‑29 Addendum — Connectivity‑driven recovery and toast polish

- Problem restated
  - Connectivity regain enqueues a send, but if login is not yet complete, `sendNext()` returns early. With no subsequent nudge tied to login success, Outbox remains idle until a new item is created.

- Fix plan
  - OutboxService subscribes to `matrixService.client.onLoginStateChanged.stream` and, on `loggedIn`, calls `enqueueNextSendRequest(Duration.zero)`. This provides a deterministic post‑login nudge.
  - Gate the not‑logged‑in toast behind “has pending items” and an optional startup grace window to avoid noisy toasts while the client is still initializing.
  - Optional: after a connectivity regain event while logged out, schedule a small, bounded re‑nudge sequence (e.g., 1s and 5s) to bridge login latency.

- Acceptance criteria
  - With pending items and app offline at launch: upon connectivity regain, once login completes, Outbox sends without creating new items.
  - No “not logged in” toast at startup while the client is in the process of logging in and there are no pending items, or we’re still within the grace window.
  - Analyzer/test clean.

## Data Flow & API Changes

- No repository changes.

- OutboxService
  - Store an optional `MatrixService` reference (passed at construction via DI) and use it for gating. If absent (e.g., tests that inject only a custom `OutboxMessageSender`), default to permissive behavior so tests are unaffected.
  - Call `_matrixService?.isLoggedIn()`; if `false`, return early without draining and do not enqueue an immediate retry.
  - Keep scheduling conservative while logged out (no tight loops, no reschedule on gate).

- Not‑logged‑in stream for UI (StreamBuilder)
  - Option A (preferred): Extend `OutboxState` with `notLoggedIn` and have `OutboxCubit` derive it from the feature flag and login stream. Use `StreamBuilder<OutboxState>` on `cubit.stream` to drive the toast.
  - Option B: Use the existing Riverpod providers (`loginStateStreamProvider` / `isLoggedInProvider`) from `lib/features/sync/state/matrix_login_controller.dart` combined with the feature flag stream from `JournalDb` to compute “not logged in”.

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
- Add a top‑level StreamBuilder in `AppScreen` (where a `Scaffold` is present) to show the red SnackBar when the stream indicates not logged in and the feature flag is on.
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
  - Connectivity/login recovery: with a pending outbox item, simulate connectivity regain while `isLoggedIn=false` (no send), then emit `LoginState.loggedIn` → send occurs without enqueueing a new item; toast gated by pending items and startup grace.

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
- `lib/beamer/beamer_app.dart:1-240` and `lib/beamer/beamer_app.dart:240-560` (entry tree)
- `lib/beamer/beamer_app.dart` → specifically integrate in `AppScreen` (top‑level `Scaffold`) for SnackBar context
- `lib/l10n/*.arb` (new `syncNotLoggedInToast` string)

## Current State (short)

- Outbox drain gate checks only the feature flag, not login state:
  - `lib/features/sync/outbox/outbox_service.dart:296-356` — `sendNext()` returns early only when `enableMatrixFlag` is false. It always proceeds to `_drainOutbox()` when enabled.
- Matrix login state is available and already surfaced:
  - Imperative: `lib/features/sync/matrix/matrix_service.dart:448` — `bool isLoggedIn()`
  - Streams/providers: `lib/features/sync/state/matrix_login_controller.dart:1-200` — `loginStateStreamProvider`, `isLoggedInProvider`
- Outbox UI/state:
  - `lib/blocs/sync/outbox_state.dart:1-60` — Freezed union with `initial|online|disabled` only.
  - `lib/blocs/sync/outbox_cubit.dart:1-80` — Emits `online|disabled` based on `enableMatrixFlag`.
- App shell and SnackBar context:
  - `lib/beamer/beamer_app.dart:1-240` — `AppScreen` defines the top‑level `Scaffold` where SnackBars are shown.
  - `lib/features/settings/ui/pages/outbox/outbox_badge.dart:1-240` — badge does not reflect login state.

## Implementation Details — Code Sketches

1) Outbox gate

Add an optional `_matrixService` field in `OutboxService` and gate in `sendNext()`:

```dart
class OutboxService {
  OutboxService({
    // ...
    MatrixService? matrixService,
  }) : _matrixService = matrixService /* existing assigns ... */;

  final MatrixService? _matrixService;

  Future<void> sendNext() async {
    try {
      final enableMatrix = await _journalDb.getConfigFlag(enableMatrixFlag);
      if (!enableMatrix) return;

      // New: login gate
      if (_matrixService != null && !_matrixService!.isLoggedIn()) {
        // Do not drain; do not schedule immediate retry to avoid spin.
        return;
      }

      final firstDrained = await _drainOutbox();
      if (!firstDrained) return;
      await Future<void>.delayed(_postDrainSettle);
      await _drainOutbox();
    } catch (e, st) {
      // unchanged
    }
  }
}
```

Tests that inject a custom `OutboxMessageSender` (without a `MatrixService`) keep behavior unchanged (`_matrixService == null` → no gate).

2) One‑time toast in AppScreen

Compute “sync enabled” × “not logged in” and show a one‑time SnackBar per login session. Use the existing login providers and `JournalDb` flag stream:

```dart
// In AppScreen.build() -> around the Scaffold body
return StreamBuilder<bool>(
  stream: journalDb.watchConfigFlag(enableMatrixFlag),
  builder: (context, flagSnap) {
    final syncEnabled = flagSnap.data ?? false;
    return Consumer(builder: (context, ref, _) {
      final loginState = ref.watch(loginStateStreamProvider).valueOrNull;
      final notLoggedIn = syncEnabled && loginState != LoginState.loggedIn;
      _maybeShowOneTimeToast(context, notLoggedIn);
      return Scaffold(
        // ... existing content ...
      );
    });
  },
);

void _maybeShowOneTimeToast(BuildContext context, bool notLoggedIn) {
  // Keep a bool _toastShownForThisSession; reset it when loginState becomes loggedIn.
  if (notLoggedIn && !_toastShownForThisSession) {
    _toastShownForThisSession = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.messages.syncNotLoggedInToast),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  if (!notLoggedIn && _toastShownForThisSession) {
    // Reset on login so a future logout can show again.
    _toastShownForThisSession = false;
  }
}
```

3) Optional: Outbox badge disabled styling

In `OutboxBadgeIcon`, consider dimming the icon when sync is enabled but not logged in; combine the flag stream with `isLoggedInProvider`.

## Localization Keys

- Add to `lib/l10n/app_en.arb` (and sync to other locales):

```json
"syncNotLoggedInToast": "Sync is not logged in"
```

- Run `make l10n` and resolve `missing_translations.txt`.

## Testing — Files and Cases

- Unit
  - `test/features/sync/outbox/outbox_service_gate_test.dart`
    - When `enableMatrixFlag=false` → unchanged early return.
    - When `enableMatrixFlag=true` and `isLoggedIn=false` → `sendNext()` returns early; `_processor.processQueue()` never called; no scheduling.
    - When `enableMatrixFlag=true` and `isLoggedIn=true` → normal drain path.
- Widget
  - `test/beamer/app_not_logged_in_toast_test.dart`
    - With sync enabled and login state `loggedOut` → SnackBar appears once; after login then logout again → appears again.
    - With sync disabled → no SnackBar regardless of login state.

## Risks & Mitigations

- Gate could suppress processing in tests where no `MatrixService` is injected.
  - Mitigation: optional `_matrixService`; default to permissive behavior when null.
- Potential UI flicker if toast logic rebuilds too often.
  - Mitigation: guard with a per‑session boolean and show only on state transitions.
- Accidental tight loops while logged out.
  - Mitigation: do not enqueue follow‑up drain when the login gate returns early.

## Implementation Checklist

- [ ] Wire `isLoggedIn` gate in `OutboxService.sendNext()`
- [ ] Option A: Extend `OutboxState` with `notLoggedIn` and update `OutboxCubit`
- [ ] Add top‑level StreamBuilder that shows red SnackBar (`syncNotLoggedInToast`) once per login session; reset guard on login
- [ ] Subscribe OutboxService to login state; enqueue on `LoginState.loggedIn`
- [ ] Gate toast emission: pending‑only + startup grace window
- [ ] Optional: bounded re‑nudge after connectivity regain while logged out
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
