# Implementation Plan: Domain-Specific Logging & Agent Runtime Fix

## Context

The agent runtime works on the first wake (creation/manual) but subsequent runs — both
automated (subscription-triggered after throttle window) and manually triggered re-analysis —
silently fail to execute. There is zero user-visible feedback. The current logging
(`developer.log` + general `LoggingService`) provides no domain-specific visibility into
the wake orchestrator's decision pipeline (suppression, throttle, queue, drain, execution).

**Goal**: Build a structured, PII-safe, domain-specific logging layer, instrument the
agent runtime with it, then use the logs to identify and fix the P0 bug.

---

## Part 1: Domain-Specific Logging Infrastructure

### 1a. Domain Registry (`lib/services/domain_logging.dart` — new file)

Create a lightweight `DomainLogger` that wraps the existing `LoggingService` with:

- **Domain constants**: `agentRuntime`, `agentWorkflow`, `sync`, `ai`, `general`
- **PII scrubbing**: A `sanitize(String raw)` helper that:
  - Replaces UUIDs with `[id:first6chars]` (preserves correlation without full IDs)
  - Strips content/message bodies, replaces with `[content: N chars]`
  - Keeps counts, status enums, durations, timestamps
- **Domain-specific file sink**: Appends to `{documents_dir}/logs/{domain}-YYYY-MM-DD.log`
  alongside the existing general log file
- **Dual-sink**: Continues writing to `LoggingDb` (domain field already exists and is indexed)
- **Per-domain enabled check**: Reads from a set of enabled domains (managed via Settings)

```dart
class DomainLogger {
  DomainLogger({required LoggingService loggingService});

  void log(String domain, String message, {String? subDomain, InsightLevel level});
  void error(String domain, String message, {Object? error, StackTrace? stackTrace});
  static String sanitizeId(String id); // → [id:abc123]
  static String sanitizeContent(String content); // → [content: 142 chars]
}
```

### 1b. Per-Domain Config Flags

Add domain-specific logging flags to `lib/utils/consts.dart`:

```
const logAgentRuntimeFlag = 'log_agent_runtime';
const logAgentWorkflowFlag = 'log_agent_workflow';
const logSyncFlag = 'log_sync';
```

Register in `lib/database/journal_db/config_flags.dart` with `status: true` (enabled by
default when the global `enable_logging` flag is on).

Update `expectedFlags` in `test/database/database_test.dart`.

### 1c. Settings UI — Logging Domain Toggles

Add a "Logging Domains" section to the existing **Advanced Settings** page
(`lib/features/settings/ui/pages/advanced_settings_page.dart`) as a new card that
navigates to a `LoggingSettingsPage`. This page shows:

- Global logging toggle (existing `enable_logging` flag)
- Per-domain toggles (agent-runtime, agent-workflow, sync)
- Link to the existing log viewer

Files to create/modify:
- `lib/features/settings/ui/pages/advanced/logging_settings_page.dart` (new)
- `lib/features/settings/ui/pages/advanced_settings_page.dart` (add card)
- Route registration in the beamer router
- Localization strings in all 5 arb files

---

## Part 2: Instrument the Agent Runtime

### 2a. Wake Orchestrator Instrumentation

Replace all `developer.log` calls in `wake_orchestrator.dart` with `DomainLogger.log`
calls using domain `agentRuntime`. Key decision points to instrument:

| Location | What to Log |
|----------|------------|
| `_onBatch` entry | `batch: N tokens, M subscriptions registered` |
| Subscription match | `matched N tokens for agent [id:xxx] (sub: [id:yyy])` |
| Suppression check | `suppressed=true/false for [id:xxx], TTL remaining: Ns` |
| Running gate | `agent [id:xxx] executing — merged/queued` |
| Throttle gate | `agent [id:xxx] throttled until <deadline>` |
| Enqueue | `enqueued job runKey=[id:xxx], reason=subscription` |
| `processNext` entry | `drain started, queue.length=N, isDraining=<bool>` |
| `_drain` re-check | `subscription re-check: suppressed=<bool>, throttled=<bool>` |
| `_executeJob` start | `executing runKey=[id:xxx], agent=[id:yyy]` |
| `insertWakeRun` failure | `ERROR: insertWakeRun failed: <error>` |
| Executor success/failure | `wake completed/failed in Nms` |
| Throttle set/clear | `throttle set/cleared for [id:xxx], deadline=<time>` |
| Deferred drain scheduled | `deferred drain scheduled in Ns for [id:xxx]` |
| Deferred drain fired | `deferred drain timer fired for [id:xxx]` |
| Safety net triggered | `safety-net drain: queue=N` |
| History cleared | `run-key history cleared (queue empty)` |

### 2b. Workflow Instrumentation

Instrument `task_agent_workflow.dart` with domain `agentWorkflow`:

| Location | What to Log |
|----------|------------|
| execute() entry | `wake start: agent=[id:xxx], triggers=N` |
| State/task resolution | `state resolved, taskId=[id:xxx]` |
| Template resolution | `template=[id:xxx], version=[id:yyy], model=<modelId>` |
| Conversation created | `conversation created: [id:xxx]` |
| LLM call start/end | `LLM call started/completed: N tokens in Nms` |
| Tool calls | `tool calls: N (names only, no args)` |
| Report published | `report published: [content: N chars]` |
| Observations count | `observations: N recorded` |
| State updated | `state updated: rev N→N+1, wakeCounter=N` |
| Failure | `ERROR: wake failed: <error type only>` |

### 2c. Task Agent Service Instrumentation

Instrument `task_agent_service.dart`:

| Location | What to Log |
|----------|------------|
| restoreSubscriptions | `restoring subscriptions for N active agents` |
| _hydrateThrottleDeadline | `hydrated deadline for [id:xxx]: <deadline or null>` |
| triggerReanalysis | `manual reanalysis triggered for [id:xxx]` |

---

## Part 3: Fix the Agent Runtime Bug

### Diagnostic Strategy

After instrumentation, the logs will reveal the exact failure point. Based on code
analysis, the most likely candidates are:

1. **`_setThrottleDeadline` is `unawaited` (line 445)**: The DB write in `setDeadline`
   is async. If it fails or hangs, `_scheduleDeferredDrain` is never called → no timer
   → job sits in queue until safety net (60s). But the safety net finds the agent
   throttled and defers again. The timer eventually fires when the deadline passes, but
   this creates a confusing user experience.

2. **`insertWakeRun` UNIQUE constraint collision**: If the same `runKey` exists in the
   DB from a previous run (e.g., due to `clearHistory` allowing re-enqueue with a
   colliding key), the insert fails silently (line 587-592) and the job is dropped.

3. **`_isDraining` stuck true**: If `processNext()` from a previous call is still
   awaiting (e.g., the executor or DB write hangs), new `processNext()` calls set
   `_drainRequested` but never execute, causing all subsequent wakes to be silently
   queued.

4. **Self-suppression persisting**: If `clearPreRegistered` is not called (e.g., due to
   an exception path), all future notifications for subscribed entity IDs are suppressed
   permanently.

### Immediate Defensive Fixes (apply alongside logging)

These are safe to apply now regardless of which root cause is active:

**Fix A: Ensure timer scheduling happens before DB write**

In `_onBatch` line 445, the `unawaited(_setThrottleDeadline(...))` means the timer may
never be scheduled if the DB write fails. Move the timer scheduling BEFORE the DB write:

```dart
// In _WakeThrottleCoordinator.setDeadline:
Future<void> setDeadline(String agentId) async {
  final deadline = clock.now().add(throttleWindow);
  _throttleDeadlines[agentId] = deadline;
  _scheduleDeferredDrain(agentId, deadline); // ← Schedule FIRST
  // Then persist (best-effort, non-blocking)
  try {
    final state = await repository.getAgentState(agentId);
    // ... persist ...
  } catch (e) { ... }
}
```

**Fix B: Add timeout to `_isDraining` guard**

If `_drain` hangs for > 5 minutes, force-reset `_isDraining`:

```dart
DateTime? _drainStartedAt;

Future<void> processNext() async {
  if (_isDraining) {
    if (_drainStartedAt != null &&
        clock.now().difference(_drainStartedAt!) > const Duration(minutes: 5)) {
      // Force-reset stale drain lock
      _isDraining = false;
    } else {
      _drainRequested = true;
      return;
    }
  }
  _drainStartedAt = clock.now();
  // ... existing logic ...
}
```

**Fix C: Log `insertWakeRun` failures as ERROR level**

Currently silent `developer.log` at line 588. Change to `DomainLogger.error` so it
appears in the domain log files.

---

## Part 4: File Listing

### New Files
| File | Purpose |
|------|---------|
| `lib/services/domain_logging.dart` | DomainLogger class with PII scrubbing |
| `lib/features/settings/ui/pages/advanced/logging_settings_page.dart` | Domain toggle UI |
| `test/services/domain_logging_test.dart` | Unit tests for DomainLogger + sanitization |
| `test/features/settings/ui/pages/advanced/logging_settings_page_test.dart` | Widget tests |

### Modified Files
| File | Change |
|------|--------|
| `lib/utils/consts.dart` | Add domain logging flag constants |
| `lib/database/journal_db/config_flags.dart` | Register new flags |
| `lib/features/agents/wake/wake_orchestrator.dart` | Instrument + Fix A + Fix B |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Instrument with DomainLogger |
| `lib/features/agents/service/task_agent_service.dart` | Instrument with DomainLogger |
| `lib/features/agents/state/agent_providers.dart` | Inject DomainLogger into orchestrator |
| `lib/features/settings/ui/pages/advanced_settings_page.dart` | Add logging settings card |
| `lib/l10n/app_en.arb` | New localization strings |
| `lib/l10n/app_de.arb` | German translations |
| `lib/l10n/app_es.arb` | Spanish translations |
| `lib/l10n/app_fr.arb` | French translations |
| `lib/l10n/app_ro.arb` | Romanian translations |
| `test/database/database_test.dart` | Update `expectedFlags` |
| `test/features/agents/wake/wake_orchestrator_test.dart` | Update for new logging calls |
| `CHANGELOG.md` | Add entry |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | Add entry |

---

## Execution Order

1. **Create `DomainLogger`** with PII scrubbing and domain-specific file sink
2. **Add config flags** for per-domain toggles
3. **Write DomainLogger tests** (sanitization, file output, domain filtering)
4. **Instrument wake orchestrator** — replace `developer.log` with `DomainLogger`
5. **Apply Fix A** (synchronous timer scheduling before DB write)
6. **Apply Fix B** (drain timeout guard)
7. **Instrument workflow + task agent service**
8. **Build Settings UI** for domain toggles
9. **Add localization strings** to all 5 arb files
10. **Update existing tests** to account for new logging dependency
11. **Run analyzer + formatter + tests**
12. **Update CHANGELOG + metainfo**

---

## Verification

1. `dart-mcp.analyze_files` — zero warnings
2. `dart-mcp.dart_format` — clean
3. `dart-mcp.run_tests` — targeted: `test/services/domain_logging_test.dart`
4. `dart-mcp.run_tests` — targeted: `test/features/agents/wake/wake_orchestrator_test.dart`
5. `dart-mcp.run_tests` — targeted: `test/features/settings/`
6. Manual verification: enable logging, trigger agent, check domain log files appear in
   `{documents_dir}/logs/agent-runtime-YYYY-MM-DD.log`
7. Manual verification: subsequent agent triggers produce new conversations
