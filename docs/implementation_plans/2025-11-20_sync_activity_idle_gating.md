[//]: # (# Sync Activity / Idle Gating – Implementation Plan)

**Date:** 2025-11-20  
**Author:** Codex (assistant)  
**Status:** Proposal

## Problem Statement

After saving or editing something, sync work (primarily Outbox sends and Matrix pipeline activity) starts almost immediately and can cause jerky scrolling and perceived sluggishness. The intended behavior is:

- Sync should *not* start while the user is actively interacting with the app.
- Outbox items can accumulate and be visible (icon shows pending), but heavy work should wait until a clear idle window.
- Only after a *multi‑second* period of complete inactivity (originally ~5s, possibly 2–3s) should sync begin.
- As soon as the user interacts again (scroll, tap, type), heavy sync should pause promptly and yield back to the UI.

Today, the behavior does not match this model: sync can start within ~1–2 seconds of interaction and continues even if the user keeps scrolling, so work competes with UI rendering.

## Prior Work & References

This plan builds on and refines the existing sync design:

- **Sync refactor & activity gating**
  - `docs/implementation_plans/2025-10-06_sync_refactor_progress.md`
    - Introduced `UserActivityService` and `UserActivityGate`.
    - Integrated activity gating into `OutboxService` (and wired it into `MatrixService` ownership).
- **Sync simplification & pipeline V2**
  - `docs/implementation_plans/2025-10-11-sync_simplification_plan.md`
    - Replaced custom drains with a stream‑first `MatrixStreamConsumer` V2.
    - Emphasized simpler, streaming‑oriented processing, with catch‑up only on attach/reconnect.
- **Sync deep dive / offline backlog issues**
  - `docs/sync/2025-10-18_sync_investigation_and_plan.md`
  - `docs/sync/investigation-2025-11-05.md`
    - Focused on correctness, attachment descriptor discovery, and catch‑up behavior under offline periods.
- **Outbox / sync UI sluggishness**
  - `docs/perf/outbox-sluggishness-report.md`
    - Identified descriptor prefetch on the receive side as a major jank source and removed it.
    - Called out two remaining levers for smoothness:
      - Logging volume / flush behavior.
      - **“Activity gating policy allows sending while the user remains active”** with a *hard 2s deadline* that forces progress.

This plan specifically targets the “activity gating policy” gap and aligns the implementation with the UX expectation described above.

## Current Behavior (Code Map)

### User Activity Tracking

- `lib/features/user_activity/state/user_activity_service.dart`
  - Holds a single global `DateTime _lastActivity`.
  - Exposes `void updateActivity()`, `DateTime get lastActivity`, and a broadcast `activityStream`.
- `lib/features/user_activity/state/user_activity_gate.dart`
  - `UserActivityGate` wraps the service and exposes:
    - `bool canProcess` and `Stream<bool> canProcessStream`.
    - `Future<void> waitUntilIdle()`.
  - Initialization:
    - Computes `elapsed = now - lastActivity` and sets `_canProcess = (elapsed >= idleThreshold)`.
    - Default `idleThreshold = Duration(seconds: 1)`.
    - Starts *idle* at boot (last activity is epoch); early sync will run immediately until the first activity event.
  - `waitUntilIdle()` behavior:
    - If `_canProcess` is already `true`, returns immediately.
    - Otherwise, subscribes to `canProcessStream` and sets a **hard deadline**:
      - `const maxWaitForProgress = Duration(seconds: 2);`
      - If the gate does *not* become idle before the deadline, the method returns anyway (“proceed once and let callers re-check idleness on the next iteration”).
- UI wiring:
  - A global `Listener` wraps the app shell (`lib/beamer/beamer_app.dart`) and calls `UserActivityService.updateActivity()` for pointer down/move/pan/scroll, so taps and scrolls are already tracked globally. Keyboard-only activity is not wired.
  - Additional scroll listeners exist on core surfaces, e.g.:
    - `lib/features/journal/ui/pages/infinite_journal_page.dart`
    - `lib/features/tasks/ui/pages/task_details_page.dart`
    - `lib/features/settings/ui/pages/sliver_box_adapter_page.dart`
    - `lib/features/habits/ui/habits_page.dart`
  - These listeners make activity updates very frequent during scroll/pan; idle timers reset on every pointer move.

### Outbox (Send Path)

- `lib/features/sync/outbox/outbox_service.dart`
  - Constructed in `lib/get_it.dart`:
    - `UserActivityService` and `UserActivityGate` are singletons.
    - `OutboxService` receives:
      - `required UserActivityService userActivityService`
      - Optional `UserActivityGate activityGate` (by default, constructs its own with the shared `activityService`).
  - `OutboxService._startRunner()`:
    - Creates a `ClientRunner<int>`:
      ```dart
      _clientRunner = ClientRunner<int>(
        callback: (event) async {
          final started = DateTime.now();
          await _activityGate.waitUntilIdle();
          final waitedMs = DateTime.now().difference(started).inMilliseconds;
          if (waitedMs > 50) {
            _loggingService.captureEvent(
              'activityGate.wait ms=$waitedMs',
              domain: 'OUTBOX',
              subDomain: 'activityGate',
            );
          }
          await sendNext();
        },
      );
      ```
    - Every queued Outbox “tick” must pass through `waitUntilIdle()` exactly once before calling `sendNext()`.
  - `enqueueMessage(SyncMessage)`:
    - Persists items into the Outbox DB (optionally writing refreshed JSON to disk and inferring attachments).
    - At the end, calls:
      ```dart
      unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
      ```
    - This nudges the runner ~1 second after enqueue.
  - `enqueueNextSendRequest(...)`:
    - After the delay, calls `_clientRunner.enqueueRequest(...)`.
  - `sendNext()`:
    - Checks `enableMatrixFlag` and login state (with a login gate).
    - Logs a state snapshot including `_activityGate.canProcess`.
    - Calls `_drainOutbox()`, then waits `_postDrainSettle` (250ms) and calls `_drainOutbox()` once more.
  - `_drainOutbox()`:
    - Loops up to `_maxDrainPasses = 20`:
      - Each pass calls `_processor.processQueue()`.
      - If the result has `nextDelay == Duration.zero`, continues immediately (next item in the same callback).
      - If `nextDelay` is non‑zero, schedules a follow‑up run and exits.
    - There is **no check for user activity inside this loop**; once started, a drain burst can send many items back‑to‑back, regardless of new activity.
  - Watchdog and connectivity/login nudges:
    - Periodic watchdog (`SyncTuning.outboxWatchdogInterval = 10s`) nudges the runner if there are pending items and the queue appears idle.
    - Connectivity regain and login transitions also enqueue requests.
    - All these still go through `_activityGate.waitUntilIdle()` before `sendNext()`.

### Matrix Receive Pipeline

- `lib/features/sync/matrix/matrix_service.dart`
  - Owns `MatrixStreamConsumer _pipeline` but does *not* currently use `UserActivityGate` to gate receive‑side work.
  - On connectivity regain:
    - Listens to `Connectivity().onConnectivityChanged`.
    - If connectivity is back and no recent rescan is in flight:
      - Records a connectivity signal into `_pipeline` and calls `await _pipeline?.forceRescan();`.
    - This can trigger catch‑up + live scan regardless of user activity.
- `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
  - Implements stream‑first ingestion with:
    - Initial attach‑time catch‑up.
    - Live scans scheduled via timers with `SyncTuning.minLiveScanGap` and trailing debounces.
    - Descriptor catch‑up logic for missing attachment descriptors.
  - Coalescing:
    - Enforces minimum gaps and trailing delays (e.g., `_trailingCatchupDelay = SyncTuning.trailingCatchupDelay`).
    - However, there is no explicit check against `UserActivityService` or `UserActivityGate`; scheduling is time‑based, not activity‑based.

## Observed / Likely Failure Modes

From the code and the existing perf report, the following issues explain the current UX:

1. **Idle threshold too short (1s) for the intended UX**
   - With `idleThreshold = 1s`, the system considers the user “idle” very quickly.
   - Combined with the 1s enqueue delay, saving an item often results in Outbox drains starting within ~2s, even if the user is still mentally “in the flow” (reading, minor interactions).

2. **Hard 2s deadline in `waitUntilIdle()` violates “never while active”**
   - Even if scroll events keep arriving and `_canProcess` remains `false`, `waitUntilIdle()` completes after `maxWaitForProgress` (~2s).
   - This means Outbox work *will* start under continuous interaction, exactly the scenario we want to avoid.
   - The design intent (“avoid indefinite starvation”) conflicts with the UX goal (“do not get in the way”).

3. **Outbox drains are not preemptible once started**
   - `sendNext()` calls `_drainOutbox()` (up to 20 passes) plus a trailing `_drainOutbox()` after `_postDrainSettle`.
   - There is no check for `activityGate.canProcess` inside the drain loop.
   - If the user starts scrolling mid‑drain:
     - File I/O, JSON encode/decode, Matrix SDK encryption, and network sends can all continue on the main isolate.
     - This can easily produce visible frame jank on scroll‑heavy screens (Infinite Journal, task details).

4. **Receive‑side work ignores activity**
  - Initial catch‑up, descriptor catch‑up, and live scans are time‑driven.
  - While prefetch removal has significantly reduced receive‑side jank, bursts of DB work and FS checks can still occur while the user is actively interacting.
  - This is less likely to be the primary cause of the described “immediately after saving” stall, but it contributes to background pressure.

## Goals for the New Behavior

1. **Strict idle gating for heavy sync work**
   - Outbox sends and expensive Matrix receive bursts should only run after a *continuous idle window* (configurable, but in the 2–5 second range).
   - No built‑in “force progress after 2s even if active” for Outbox send bursts.
   - At startup, sync may run immediately; once activity is detected, heavy work should pause until the next idle window.

2. **Immediate pause on new activity**
   - If the user interacts while Outbox is draining:
     - Finish the current in‑flight send (cannot cancel mid‑request).
     - Then *stop* further sends as soon as practical and yield until the next idle window.

3. **Reasonable throughput when idle**
   - When the user is inactive, Outbox and the pipeline should still be able to clear backlogs efficiently (no artificial throttling).
    - For long‑running “always active” sessions, it is acceptable for sync to remain paused indefinitely; no time‑sliced progress is required.

4. **Minimal API surface change**
   - Prefer changes that keep `UserActivityGate` and its callers simple.
   - Maintain existing tests where possible, updating expectations instead of rewriting the architecture.

## Proposed Design

### 1. Refine `UserActivityGate` Semantics

Files:

- `lib/features/user_activity/state/user_activity_gate.dart`

Changes:

- Replace the “hard 2s deadline” model with a *strict idle window* model for `waitUntilIdle()`:
  - Ensure the user has been continuously idle for at least `idleThreshold` before returning.
  - **Remove `maxWaitForProgress`** from the default implementation; do not force progress while the user remains active.
- Implementation sketch:
  - On construction:
    - Keep the existing `_canProcess` logic, but treat it as “currently in an idle window” (i.e., the last activity is at least `idleThreshold` ago).
  - In `waitUntilIdle()`:
    - If `_canProcess` is `true`, return immediately (we are already in an idle window).
    - Otherwise, wait until `canProcessStream` emits `true` (meaning the gate stayed idle for `idleThreshold`); no max-wait deadline.
- Backwards compatibility:
  - Outbox is currently the only caller of `waitUntilIdle()`. Matrix pipeline does not depend on it.
  - If we need a bounded variant for future use, we can add a separate method:
    - `Future<void> waitUntilIdleOrTimeout(Duration maxWait)` (not used by Outbox).

Config:

- Introduce a dedicated tuning constant for idle gating:
  - In `lib/features/sync/tuning.dart`:
    ```dart
    static const Duration outboxIdleThreshold = Duration(seconds: 3);
    ```
  - Pass this as `idleThreshold` when constructing the `UserActivityGate` for sync (see next section).

### 2. Tune Idle Threshold for Sync

Files:

- `lib/get_it.dart`
- `lib/features/sync/tuning.dart`

Changes:

- In `SyncTuning`, add:
  ```dart
  static const Duration outboxIdleThreshold = Duration(seconds: 3);
  ```
- In `get_it.registerSingletons()` when creating the global `UserActivityGate`:
  - Change:
    ```dart
    ..registerSingleton<UserActivityGate>(
      UserActivityGate(
        activityService: getIt<UserActivityService>(),
      ),
    )
    ```
  - To:
    ```dart
    ..registerSingleton<UserActivityGate>(
      UserActivityGate(
        activityService: getIt<UserActivityService>(),
        idleThreshold: SyncTuning.outboxIdleThreshold,
      ),
    )
    ```
- Rationale:
  - `3s` is a pragmatic compromise between the original “5s” desire and typical expectations for “I’m done interacting now”.
  - This is centralized and easily adjusted later if real‑world testing suggests a different value (2s vs 4s, etc.).

### 3. Make Outbox Drains Activity‑Aware (Preemptible)

Files:

- `lib/features/sync/outbox/outbox_service.dart`

Changes:

- **Before** starting a drain pass, check `canProcess` again:
  - In `_drainOutbox()`:
    - At the top of the loop:
      ```dart
      if (!_activityGate.canProcess) {
        _loggingService.captureEvent(
          'drain.paused activityGate.canProcess=false',
          domain: 'OUTBOX',
          subDomain: 'activityGate',
        );
        // Yield and let a future idle window resume.
        await enqueueNextSendRequest(delay: SyncTuning.outboxRetryDelay);
        return false;
      }
      ```
- Additionally, after each pass:
  - If `result.nextDelay == Duration.zero` (immediate continue):
    - Re-check `canProcess` before proceeding to the next pass.
    - If activity resumed, break out early and schedule a future run.
- For the trailing `_postDrainSettle` pass in `sendNext()`:
  - After `await Future<void>.delayed(_postDrainSettle);`
    - If `_activityGate.canProcess` is `false`, skip the second `_drainOutbox()` and schedule a future `enqueueNextSendRequest` instead.

Rationale:

- This pattern preserves high throughput when idle:
  - If the user stays idle, drains continue to run in tight loops.
- Under new activity:
  - We still complete the *current* send (no cancellation semantics altered).
  - Subsequent items are deferred until the user is idle again.
- Combined with strict idle gating, this should strongly reduce the chance of visible jank while scrolling or editing.

### 4. Activity Signals (Unchanged)

We will keep the current activity signal wiring:

- The app-shell `Listener` already reports pointer events globally.
- No additional DB-write‑based activity markers are planned.
- Keyboard-only typing remains uncaptured for now; acceptable for this iteration.

### 5. Receive‑Side Idle Awareness (Phase 2)

Files:

- `lib/features/sync/matrix/matrix_service.dart`
- `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`

Changes (Phase 2, optional for the immediate fix):

- Introduce a lightweight “receive gating” hook informed by `UserActivityService`:
  - For expensive operations (catch‑up scans, descriptor catch‑up runs), ensure:
    - Initial attach catch‑up can still run on startup, but trailing catch‑ups triggered by connectivity or descriptor deficits prefer idle windows.
- Future extension:
  - Add an optional `bool Function()` or `Future<void> Function()` “idle hint” callback to `MatrixStreamConsumer` that:
    - Either no‑ops (current behavior) or
    - Waits for brief idle windows before expensive work in certain modes.

Rationale:

- Not strictly required to address the “after saving I scroll and it janks” scenario.
- Aligns longer‑term with the philosophy that heavy sync work should be idle‑biased.

## Testing Strategy

### Unit Tests

1. **UserActivityGate tests**
   - Update existing tests (referenced in `2025-10-06_sync_refactor_progress.md`) to reflect:
     - No forced progress after 2 seconds of continuous activity.
     - `waitUntilIdle()` completes only after a full idle window.
   - Add coverage for:
     - Multiple quick activity bursts resetting the idle window.
     - Long‑running activity (no idle) not completing the future.

2. **OutboxService tests**
   - Add tests to verify:
     - `_drainOutbox()` respects `_activityGate.canProcess` at the start of each pass.
     - New activity mid‑drain causes an early pause:
       - Simulate `canProcess` flipping to `false` between passes and assert that:
         - No further `OutboxProcessor.processQueue()` calls occur in that drain.
         - A follow‑up enqueue is scheduled.
     - The trailing `_postDrainSettle` pass is skipped when `canProcess == false`.

3. **Integration / harness tests**
   - For a simple scenario:
     - Enqueue a few Outbox items.
     - Simulate scroll activity via `UserActivityService.updateActivity()`.
     - Assert that `OutboxMessageSender.send` is *not* called until a full idle window has elapsed.

### Manual / UX Validation

- Scenario: Infinite Journal scroll
  - Enable Sync.
  - Start smooth scrolling.
  - Trigger a save or edit (creating Outbox items).
  - Immediately continue scrolling for several seconds.
  - Expected:
    - Outbox icon shows pending items.
    - No noticeable scroll jank while the user keeps interacting.
    - After they pause for ~3s, Outbox begins sending.
- Scenario: Long editing session
  - Spend several minutes editing tasks or entries with frequent interactions.
  - Expected:
    - Sync avoids starting long drains mid‑editing.
    - When pausing (hands off keyboard/mouse), Outbox gradually flushes.

## Rollout & Observability

- Logging:
  - Keep existing `activityGate.wait ms=...` logging, but:
    - Update expectations: high wait times are now *normal* under long activity, not a concern.
  - Add a few coarse log events (ideally sampling‑friendly) to observe:
    - Idle threshold configuration in effect.
    - Number of drains paused due to activity vs completed uninterrupted.
- Feature flags:
  - For simplicity, ship the stricter gating behavior as the new default.
  - If needed, we can later introduce a config flag (e.g., `sync_strict_idle_gating`) stored in `JournalDb` for A/B or temporary rollback.

## Summary

By:

- Making `UserActivityGate` enforce a strict idle window (no 2s forced progress),
- Raising the idle threshold for sync to ~3 seconds,
- Making Outbox drains preemptible based on live activity,

we align the implementation with the desired UX: smooth scrolling and interaction while sync work waits patiently in the background, only kicking in after a clear period of user inactivity and backing off quickly whenever the user resumes interacting with the app.
