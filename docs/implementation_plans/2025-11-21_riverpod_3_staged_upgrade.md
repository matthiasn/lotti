# Riverpod 3.0.3 Staged Upgrade Plan

## Context

- Current stack: `flutter_riverpod ^2.4.9`, `riverpod ^2.6.1`, `riverpod_annotation ^2.3.5`,
  `riverpod_generator ^2.4.0`, `riverpod_lint ^2.6.5`.
- Target: Riverpod 3.0.3 ecosystem (core, flutter bindings, annotations/generator/lints).
- Inventory highlights:
  - Only one manual `StateNotifier`/`StateNotifierProvider`:
    `lib/features/sync/state/matrix_stats_provider.dart` (`SyncMetricsHistory`).
  - One `StateProvider`: `lib/features/ai/providers/gemini_thinking_providers.dart` toggle.
  - Remainder are generator-driven `@riverpod` controllers plus vanilla `Future/StreamProvider`s.
- Migration notes from Riverpod 3 docs (context7):
  - `Notifier` subsumes `AutoDisposeNotifier` and `FamilyNotifier`; family args move into
    constructors; `build()` drops parameters.
  - `Ref` loses typed subclasses; generated providers use bare `Ref`; `listenSelf/future/state` live
    on notifiers.
  - Legacy providers (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`) move
    behind `legacy.dart` imports.
  - `ProviderObserver` callbacks now take `ProviderObserverContext`; provider failures throw
    `ProviderException`.

## Staged Approach

### Stage 0 — Baseline & References (Riverpod 2.x)

- Run `dart-mcp.analyze_files` + a smoke subset of tests to document current health.
- Snapshot behavior of `SyncMetricsHistory` and its consumers (sparklines) plus AI “include
  thoughts” toggle.
- Confirm no custom `ProviderObserver` implementations or direct `*Ref` type usages outside
  generated code.

### Stage 1 — Pre-upgrade Source Prep (stay on 2.x)

- Convert manual providers to the Notifier API that survives 3.0:
  - Rework `SyncMetricsHistory` as a `Notifier<Map<String, List<int>>>` with a `NotifierProvider` (
    or `autoDispose` if appropriate); keep listener wiring inside `build()`; ensure history
    truncation logic is preserved.
  - Replace `geminiIncludeThoughtsProvider` with an `@riverpod`/Notifier-based toggle (default
    `false`) so no `StateProvider` dependency remains.
- Remove dependencies on typed generated `*Ref` classes where present; prefer `Ref` or notifier
  `ref` fields to ease the 3.0 ref simplification.
- Update tests that construct providers/containers to the Notifier pattern; avoid
  `StateNotifierProvider`/`StateProvider` in new code.
- Run `dart-mcp.analyze_files`, targeted tests for sync/AI features, and reformat touched files.

### Stage 2 — Pre-upgrade Release Gate (still 2.x)

- Cut a release/build after Stage 1 with all tests green to lock in stability before the major bump.
- Capture release notes noting “riverpod prep (still on v2.x)” and tag/branch as needed.

### Stage 3 — Dependency Upgrade to 3.0.3

- Bump `riverpod`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`
  to `^3.0.3` (or matching generator/lint 3.x).
- Refresh deps (`dart-mcp.pub get`) and rerun codegen (`make build_runner` via MCP) ensuring
  `--delete-conflicting-outputs`.
- Address API changes:
  - Ensure all providers use `Notifier/AsyncNotifier/StreamNotifier`; avoid `legacy.dart` imports (
    should be unnecessary post-Stage 1).
  - Update any `ProviderObserver` implementations to `ProviderObserverContext`.
  - Adjust error handling expecting `ProviderException` wrappers where provider futures are awaited.
  - Verify `listenSelf/future/state` usage on notifiers instead of refs when applicable.
- Apply `riverpod_lint` fixes; run `dart-mcp.analyze_files` until clean and format.

### Stage 4 — Post-upgrade Validation & Release

- Run targeted feature tests, then full `dart-mcp.run_tests` (all platforms in scope); sanity-check
  UI flows (sync KPIs, AI chat toggle).
- Regenerate localization/build artifacts if required; ensure no missing translations surfaced by
  CI (`make l10n` if touched).
- Prepare release notes highlighting the Riverpod 3 jump, migration specifics, and risk mitigations;
  cut release/build.

## Risks & Mitigations

- **Notifier lifecycle differences**: Address via feature-targeted tests and ensuring listeners are
  inside `build()` to respect dispose.
- **Generated code churn**: Large diffs from 3.x generator—review g.dart output carefully and keep
  commits scoped by stage.
- **Hidden typed ref usages**: Grep for `Ref` subclasses before upgrade; keep prep stage focused on
  removing them.

## Success Criteria

- No `StateNotifierProvider`/`StateProvider`/`ChangeNotifierProvider` usage remains outside
  temporary legacy imports (ideally none).
- Analyzer clean; formatter applied; all tests pass on both pre-upgrade (Stage 2) and post-upgrade (
  Stage 4) releases.
- Releases cut before and after upgrade with documented QA checklists.
