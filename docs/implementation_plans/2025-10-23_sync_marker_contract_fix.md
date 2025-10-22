# Sync Catch-Up Reliability — Journal Update Contract Fix

## Summary

- Desktop catch-up stalls because `JournalDb.updateJournalEntity` reports `rowsAffected = 0` on
  legitimate updates, causing the V2 pipeline to classify events as "missing base" and block marker
  advancement.
- We will realign the contract so database writes return an explicit "applied" outcome, propagating
  that signal through `SyncApplyDiagnostics` into the stream consumer.
- The pipeline will stop retrying already-applied events, advance the read marker, and eliminate the
  repeated backlog reprocessing that currently bloats logs and leaves gaps after offline periods.

## Goals

- Introduce a truthful result type for journal updates that distinguishes `applied`, `skipped` and
  conflict outcomes without relying on raw row ids.
- Update all call sites (sync pipeline, persistence logic, repositories, tests) to consume the new
  result and honor the refined semantics.
- Ensure Matrix V2 catch-up no longer enters the `_missingBaseEventIds` loop when updates succeed,
  allowing markers to progress and devices to ingest full backlogs after offline windows.
- Preserve analyzer/test cleanliness (`dart-mcp.analyze_files`, targeted `dart-mcp.run_tests`).

## Non-Goals

- No schema changes to the underlying Drift tables.
- No alterations to vector clock comparison logic beyond reporting accuracy.
- No changes to attachment ingestion or descriptor catch-up strategies.

## Findings Recap

- `insertOnConflictUpdate` returns the inserted row id (or `0` for updates), which we bubbled up as
  `rowsAffected`, misleading higher layers (`lib/database/database.dart:178-215`).
- `SyncApplyDiagnostics` uses `rowsAffected == 0 && status.contains('b_gt_a')` as a proxy for
  missing base, so the matrix consumer enqueues every event for retry even when DB writes succeed
  (`lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:1118-1156`).
- Logs confirm the desktop keeps re-ingesting the same payloads (
  `docs/sync/lotti-2025-10-22_2100_desktop.log`).

## Design Overview

1. **Result Object** — Replace the `int` return value with a lightweight result class, e.g.
   `JournalUpdateResult { bool applied; bool skipped; String? skippedReason; int? rowsWritten; }`.
  - Expose factory helpers for common outcomes (applied, skippedOlder, skippedConflict).
  - Carry `rowsWritten` for telemetry if needed, but base decisions on `applied`.
2. **Database Layer** — Update `JournalDb.updateJournalEntity` to:
  - Return `JournalUpdateResult.applied()` whenever we call `upsertJournalDbEntity`.
  - Return `JournalUpdateResult.skipped(reason: 'older')` (or similar) when vector clocks dictate a
    skip.
  - Maintain existing `overwrite` and `overrideComparison` behaviors while populating the result.
3. **Sync Diagnostics** — Extend `SyncApplyDiagnostics` with a new `bool applied` and optional
   `String? skipReason`.
  - Populate it from the new result inside `SyncEventProcessor._handleMessage` when handling
    `SyncJournalEntity` payloads.
4. **Pipeline Consumption** — Adjust `MatrixStreamConsumer.reportDbApplyDiagnostics` to:
  - Use `diag.applied` to increment metrics and drive `_missingBaseEventIds`.
  - Stop assuming `rows == 0` implies missing base; only register `_missingBaseEventIds` when
    `!diag.applied && diag.conflictStatus.contains('b_gt_a') && diag.skipReason == 'missing_base'`.
5. **Support Layers** — Update `PersistenceLogic`, repositories, and tests to account for the new
   return type (primarily swapping `int` comparisons for `result.applied`).

## Data Flow & API Changes

- `JournalDb.updateJournalEntity` signature changes from `Future<int>` to
  `Future<JournalUpdateResult>`.
- `SyncApplyDiagnostics` gains new fields (`applied`, `skipReason`). Existing log messages can be
  updated to include the applied flag.
- `matrix_stream_consumer` metrics will leverage the new flag to increment `dbApplied` and avoid
  false `missingBase` entries.
- All layers that invoke `updateJournalEntity` (listed via `rg`) must be updated:
  - `lib/logic/persistence_logic.dart`
  - `lib/features/journal/repository/journal_repository.dart`
  - `lib/features/sync/matrix/sync_event_processor.dart`
  - Various feature modules/tests enumerated earlier (e.g., `test/database/database_test.dart`,
    `test/features/journal/state/entry_controller_test.dart`, AI repos).

## Implementation Phases

### Phase 0 — Prep & Ownership Check

- Status: Planned
- Confirm call-site inventory and note any external integrations expecting an `int` return.
- Document the new `JournalUpdateResult` shape and ensure naming aligns with existing conventions.

### Phase 1 — Database Contract Update (P0)

- Status: Planned
- Introduce `JournalUpdateResult` in `lib/database/models/` (or alongside the DB class if more
  appropriate).
- Refactor `JournalDb.updateJournalEntity` to construct and return the new result.
- Update unit tests (`test/database/database_test.dart`) to assert on result fields rather than raw
  ints.

### Phase 2 — Sync Pipeline Integration (P0)

- Status: Planned
- Extend `SyncApplyDiagnostics` plus `SyncEventProcessor` to surface `applied/skipReason`.
- Update `MatrixStreamConsumer.reportDbApplyDiagnostics` and `_processSyncPayloadEvent` to rely on
  `diag.applied` instead of `rows` heuristics.
- Add targeted tests ensuring the pipeline advances markers when `applied == true` even if
  `rowsWritten == 0`.

### Phase 3 — Persistence & Feature Call Sites (P0)

- Status: Planned
- Adjust `PersistenceLogic.updateJournalEntity*` and repository helpers to decode the new result.
- Update mocks/stubs in tests (journal repository, entry controller, AI inference) to emit
  `JournalUpdateResult`.
- Ensure UI/business logic that previously checked `> 0` now checks `result.applied`.

### Phase 4 — Verification & Regression Tests (P0)

- Status: Planned
- Add regression coverage for the sync consumer (unit or integration test) reproducing the missing
  base scenario with stubbed DB results.
- Run `dart-mcp.analyze_files` and targeted `dart-mcp.run_tests` suites (database, sync pipeline,
  persistence, AI repos).
- Capture a new desktop log after offline catch-up to confirm continuous `marker.local` advancement
  (manual verification step if automation is heavy).
- Adhere to the repository implementation discipline (per `AGENTS.md`): analyzer must stay clean,
  formatter runs before checks, CHANGELOG and touched feature READMEs updated, meaningful tests for
  every modified path, and avoid progressing to new files until existing changes are green.

## Testing Strategy

- Update existing DB tests to assert `JournalUpdateResult.applied` on both insert and update paths.
- Extend `matrix_stream_consumer_test.dart` (or create new coverage under
  `test/features/sync/matrix/pipeline_v2/`) to simulate applied vs skipped diagnostics and ensure
  `_missingBaseEventIds` behaves accordingly.
- Adapt repository/controller tests that currently expect integer results.
- Manual smoke: reproduce offline backlog catch-up on desktop build and confirm full ingestion.

## Telemetry & Logging

- Update logging in `SyncEventProcessor` to include `applied` vs `skipped` in `apply journalEntity`
  lines to aid future debugging.
- Consider adding a metrics counter for `dbSkipped` vs `dbApplied` using the new result to monitor
  real-world frequency.

## Risks & Mitigations

- *Risk:* Widespread signature change may cascade into numerous mocks. *Mitigation:* create
  convenience constructors (`JournalUpdateResult.applied()`) to simplify test updates.
- *Risk:* Missed call sites continue assuming an `int`. *Mitigation:* use analyzer to flag
  mismatched return types; search for `> 0` checks on `updateJournalEntity` results. The 
  compiler will flag this.
- *Risk:* Behavior expectations around `overwrite=false` or `overrideComparison` may change.
  *Mitigation:* expand database tests to cover those branches with the new result type.

## Decisions

- **Result Shape:** Implement a `JournalUpdateResult` class (alongside existing persistence models)
  rather than a simple enum to preserve extensibility and attach telemetry fields.
- **Skip Reasons:** Distinguish between `older/equal`, `conflict`, and `missing_base` in both logs
  and the sync stats page so analytics stay actionable.
- **Logging Format:** Update the `apply journalEntity` log line to include `applied=true/false` (no
  separate log entry required).
- **Verification:** Manual desktop catch-up verification remains required now; follow-up task will
  scope automated/integration coverage once the contract change ships.
