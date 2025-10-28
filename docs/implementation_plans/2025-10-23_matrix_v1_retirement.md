# Matrix V1 Retirement Plan

## Summary

- We now run the Matrix V2 pipeline in integration, so the legacy Matrix V1 listener path is
  redundant.
- This plan removes the `enable_sync_v2` feature flag and deletes every V1-only implementation,
  leaving a single pipeline implementation.
- A follow-up effort (Phase 2) will rename remaining `*_v2` identifiers and collateral once the
  codebase compiles and tests pass with only the new pipeline.

## Goals

- Eliminate the `enable_sync_v2` config flag from persistence, DI, UI, and localization.
- Remove Matrix V1 classes (`MatrixTimelineListener`, `timeline.dart`, tests, helpers) and all
  conditionals that referenced them.
- Ensure `MatrixService`, `SyncLifecycleCoordinator`, and related orchestration always instantiate
  and operate on the stream-first pipeline.
- Keep analyzer/tests clean (`dart-mcp.analyze_files`, focused `dart-mcp.run_tests`) with coverage
  proving the single-pipeline behaviour.
- Update documentation and CHANGELOG to reflect that Matrix V1 is removed and V2 is the only path.

## Non-Goals

- Renaming `*_v2` files, providers, metrics, or documentation — that is the explicit Phase 2
  follow-up once this landing is stable.
- Reworking Matrix attachment ingestion, metrics shape, or sync protocol details beyond what the V1
  removal requires.
- Adjusting integration test coverage cadence; the existing Matrix integration run stays as-is.

## Current Findings

- Dependency injection (`lib/get_it.dart`) still reads `enable_sync_v2` before constructing
  `MatrixService`, which keeps V1 reachable.
- The config flag is surfaced through `config_flags` seeding, `FlagsPage`, localization entries, and
  multiple tests expecting the flag to exist.
- `MatrixService` owns both pipelines: `MatrixTimelineListener` constructs the legacy listener and
  exposes `listenToTimeline` plus `lastReadEventContextId`.
- `SyncLifecycleCoordinator` requires either a `SyncPipeline` or the legacy timeline API; teardown
  still assumes the timeline needs cancellation.
- Numerous unit tests (timeline_* suites, matrix_service_unit tests) and integration tests
  explicitly exercise V1-specific behaviours.
- Documentation (`docs/sync/sync_summary.md`, `lib/features/sync/README.md`, CHANGELOG) frames the unified pipeline
  as optional behind the flag.

## Design Overview

1. **Feature Flag Removal**
  - Delete `enableSyncV2Flag` from constants, config seeding, and tests; update the expected flag
    lists accordingly.
  - Remove the flag card from the settings Flags page and prune localization strings (rerun
    `make l10n` after edits).
  - Adjust any helper scripts or docs that reference toggling `enable_sync_v2`.
2. **Service & Lifecycle Simplification**
  - Update `MatrixService` to construct `MatrixStreamConsumer` unconditionally and delete
    `MatrixTimelineListener`, `listenToTimeline`, and V1-only state.
  - Collapse `SyncLifecycleCoordinator` to always depend on a `SyncPipeline`, calling
    `initialize/start/dispose` on the pipeline instead of timeline methods.
  - Simplify `SyncEngine` to expose only pipeline-based lifecycle wiring; remove timeline-specific
    getters/assumptions.
  - Delete V1 classes/files (`matrix_timeline_listener.dart`, `timeline.dart`,
    `timeline_context.dart`, related helpers) once nothing references them.
3. **Test Suite Updates**
  - Revise service/unit tests to use pipeline doubles (e.g., `MockSyncPipeline`) instead of timeline
    mocks; ensure expectations align with single-path behaviour.
  - Remove V1-only test suites (timeline processors, tail retry, etc.) and adjust integration tests
    to rely on the new pipeline without calling `listenToTimeline`.
  - Update existing V2 tests to drop flag toggling and assert the service exposes the same
    metrics/diagnostics without a flag.
4. **Docs & CHANGELOG**
  - Rewrite sync documentation to state the stream-first pipeline is now the default and only path.
  - Document the removal in CHANGELOG with guidance for operators (no flag toggle, ensure
    integration job state).
  - Note the upcoming Phase 2 rename work so contributors understand the staged approach.

## Implementation Phases

### Phase 0 — Discovery ✅

- Confirmed the flag footprint, dual-pipeline wiring, test coverage, and documentation references.

### Phase 1 — Remove `enable_sync_v2`

- Delete the flag constant, seeding, UI, localization, and dependent tests.
- Ensure database seeding smoke tests and settings UI continue to pass without the flag.

### Phase 2 — Collapse to Single Pipeline

- Refactor `MatrixService`, `SyncLifecycleCoordinator`, and `SyncEngine` to remove V1 logic.
- Delete unused files/classes, adjust imports, and tidy dependency graphs.
- Update integration tests and mocks to the new single-pipeline API.

### Phase 3 — Cleanup & Docs

- Run analyzer/tests; address breakages across unit/integration suites.
- Update docs/README/CHANGELOG and verify localization generation.
- Prepare follow-up task for Phase 2 (V2 rename) once this change is merged cleanly.

## Testing Strategy

- `dart-mcp.analyze_files` to ensure lint/analysis compliance after deletions.
- Targeted `dart-mcp.run_tests` runs:
  - Sync-focused unit tests (`test/features/sync/matrix/**/*`).
  - Database config seeding tests (`test/database/database_test.dart`).
  - Integration test suite (`integration_test/run_matrix_tests.sh` or equivalent MCP command) to
    confirm end-to-end behaviour.
- Consider adding/adjusting tests that assert `MatrixService` always exposes the pipeline (no
  `listenToTimeline`) and that metrics are still accessible.

## Risks & Mitigations

- **Residual references to V1 classes** — Use `rg` to confirm no imports remain; keep analyzer clean
  to surface stragglers.
- **Config migrations** — Existing flag rows may still exist in persisted DBs; ensure code tolerates
  dangling entries or write a lightweight migration to ignore unknown flags.
- **Test fragility** — Removing timeline helpers could break unrelated suites; stage deletions with
  supportive mocks and ensure coverage for the new path.
- **Integration flake** — Matrix E2E tests are slow; iterate locally first, then run the full
  integration suite before landing.

## Rollout & Monitoring

- Land behind CI runs (`make analyze`, `make test`, integration job) to guarantee green pipelines.
- Announce in release notes/Slack that the flag is gone and the new pipeline is now authoritative.
- After deploy, monitor Matrix sync metrics/logs to confirm no regression in message throughput or
  read markers.
- Schedule the Phase 2 rename work once stability is confirmed (rename files/classes, update metrics
  labels, etc.).
