# Fix: Dormant Agent Automatic Trigger (P0)

## Problem Statement

After PRs #2703 and #2705 were merged, task agents no longer trigger automatically
when users:
1. Toggle checklist items
2. Create audio entries/logs
3. Make other manual modifications to tasks

The agent is completely dormant instead of reacting to these events after the
2-minute coalescing window.

---

## Root Cause Analysis

### What Changed (PR #2703 → PR #2705)

| Aspect | PR #2703 (original) | PR #2705 (current) |
|--------|--------------------|--------------------|
| **First notification** | Immediate `processNext()` call | Deferred by 120s via `Timer` |
| **Throttle window** | 300s (5 min) post-execution | 120s (2 min) defer-first |
| **During cooldown** | Notifications dropped | Tokens merged into queued job |
| **Safety net** | 30s `_pendingDrainTimer` | Removed — relies solely on deferred drain timer |

### Identified Bugs

#### Bug 1: `_scheduleDeferredDrain` silently drops drain when `remaining <= Duration.zero`

**File:** `lib/features/agents/wake/wake_orchestrator.dart`, line 324

```dart
void _scheduleDeferredDrain(String agentId, DateTime deadline) {
    _deferredDrainTimers[agentId]?.cancel();
    final remaining = deadline.difference(clock.now());
    if (remaining <= Duration.zero) return;  // ← BUG: silent drop
    ...
}
```

When `remaining` is zero or negative, no timer is scheduled AND `processNext()` is
never called. But the caller (`_onBatch` line 491 or `_setThrottleDeadline` line 247)
has already set `_throttleDeadlines[agentId] = deadline`. Result: the agent is
permanently throttled with no timer to clear it.

**When this happens:**
- During startup hydration via `setThrottleDeadline`: a persisted deadline that was
  in the future when read but expired by the time `_scheduleDeferredDrain` runs
  (TOCTOU race between the `isBefore` check and computing `remaining`)
- Clock resolution edge cases where `deadline.difference(clock.now())` returns
  `Duration.zero` due to same-millisecond evaluation

#### Bug 2: No safety-net mechanism after removal of `_pendingDrainTimer`

PR #2703 had a separate 30-second `_pendingDrainTimer` that fired `processNext()`
after execution, providing a fallback drain. PR #2705 removed this entirely,
relying solely on the deferred drain timer scheduled by `_scheduleDeferredDrain`.

If the deferred drain timer fails for ANY reason (macOS App Nap delaying timers,
the `remaining <= Duration.zero` edge case, or a race condition cancelling the
timer), there is **zero fallback** — the queue is never drained.

#### Bug 3: `_hydrateThrottleDeadline` can cancel a just-scheduled timer

**File:** `lib/features/agents/service/task_agent_service.dart`, lines 221-231

During `restoreSubscriptions()`, for each agent:
1. `_registerTaskSubscription(agentId, taskId)` — synchronous, adds subscription
2. `await _hydrateThrottleDeadline(agentId)` — async, may call `clearThrottle`

If a notification arrives during the `await` in step 2 (between registering the
subscription and completing hydration), `_onBatch` enqueues a job and schedules a
timer. Then `_hydrateThrottleDeadline` reads `nextWakeAt == null` and calls
`clearThrottle(agentId)`, which **cancels the just-scheduled timer**. The job sits
in the queue with no mechanism to drain it.

#### Bug 4: Defer-first model eliminates all immediate execution paths

In PR #2703, the first notification triggered immediate execution via
`unawaited(processNext())` at the end of `_onBatch`. PR #2705 replaced this with:

```dart
// Note: we do NOT call processNext() here. Subscription-driven wakes
// are always deferred via the throttle timer.
```

This means the ENTIRE subscription-triggered execution path depends on the 120-second
`Timer` firing reliably. There are known platform concerns:
- macOS App Nap can delay or freeze Timer callbacks for backgrounded apps
- Flutter engine may delay event loop processing during heavy rendering
- Any code path that cancels `_deferredDrainTimers[agentId]` without rescheduling
  leaves the queue permanently stuck

---

## Proposed Fix

### Fix 1: Handle `remaining <= Duration.zero` in `_scheduleDeferredDrain`

When the deadline has already passed, call `processNext()` immediately via
`scheduleMicrotask` and clear the throttle:

```dart
void _scheduleDeferredDrain(String agentId, DateTime deadline) {
    _deferredDrainTimers[agentId]?.cancel();
    final remaining = deadline.difference(clock.now());
    if (remaining <= Duration.zero) {
      // Deadline already passed — clear throttle and drain immediately.
      _throttleDeadlines.remove(agentId);
      unawaited(_clearPersistedThrottle(agentId));
      scheduleMicrotask(() => unawaited(processNext()));
      return;
    }
    _deferredDrainTimers[agentId] = Timer(remaining, () {
      _deferredDrainTimers.remove(agentId);
      _throttleDeadlines.remove(agentId);
      unawaited(_clearPersistedThrottle(agentId));
      unawaited(processNext());
    });
}
```

### Fix 2: Add periodic safety-net drain timer

Add a periodic timer (every 60 seconds) that checks if the queue has pending
jobs with no active deferred drain timer, and calls `processNext()` if needed:

```dart
Timer? _safetyNetTimer;
static const _safetyNetInterval = Duration(seconds: 60);

void _startSafetyNet() {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = Timer.periodic(_safetyNetInterval, (_) {
      if (!queue.isEmpty && _deferredDrainTimers.isEmpty && !_isDraining) {
        developer.log(
          'Safety-net drain: queue has ${queue.length} pending jobs '
          'with no deferred timers',
          name: 'WakeOrchestrator',
        );
        unawaited(processNext());
      }
    });
}
```

Start in `start()`, cancel in `stop()`.

### Fix 3: Fix hydration race in `_hydrateThrottleDeadline`

Only call `clearThrottle` when there's actually a stale in-memory deadline to
clear. Skip the clear if no in-memory deadline exists (nothing to clean up):

```dart
Future<void> _hydrateThrottleDeadline(String agentId) async {
    final state = await repository.getAgentState(agentId);
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.setThrottleDeadline(agentId, deadline);
    }
    // Removed: else { orchestrator.clearThrottle(agentId); }
    // Don't blindly clear throttle — it could cancel a timer that was
    // just scheduled by a concurrent _onBatch notification.
}
```

### Fix 4: Add diagnostic logging

Add `developer.log` calls at critical decision points:
- Timer scheduled (with duration)
- Timer fired
- `_scheduleDeferredDrain` early return (remaining <= 0)
- Job enqueued / merged
- `processNext()` entered / drain completed

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/agents/wake/wake_orchestrator.dart` | Fix `_scheduleDeferredDrain`, add safety-net timer, add logging |
| `lib/features/agents/service/task_agent_service.dart` | Fix hydration race in `_hydrateThrottleDeadline` |
| `test/features/agents/wake/wake_orchestrator_test.dart` | Add tests for edge cases |

## Verification

1. `dart-mcp.analyze_files` — zero warnings
2. `dart-mcp.dart_format` — clean
3. `dart-mcp.run_tests` — targeted: `test/features/agents/wake/wake_orchestrator_test.dart`
4. `dart-mcp.run_tests` — targeted: `test/features/agents/service/task_agent_service_test.dart`
