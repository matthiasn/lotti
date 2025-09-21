# Riverpod 3 Migration Plan

## Context
- Current dependencies: `flutter_riverpod ^2.4.9`, `riverpod ^2.6.1`, `riverpod_annotation ^2.3.5`, `riverpod_generator ^2.4.0`, `riverpod_lint ^2.3.10`.
- Codebase relies on generated providers (`@riverpod`, `@Riverpod`) plus manual `StateNotifier`/`StateNotifierProvider` implementations across sync, AI, and dashboard features.
- Trial refactor completed: `ActionItemSuggestionsController` now uses the `Notifier` API while still targeting Riverpod 2.x.
- Goal: adopt Riverpod 3.x ecosystem (core, flutter bindings, annotations, generator, lint) and align application/tests with new APIs.

## Deliverables
- Updated Riverpod-related dependencies to the latest stable 3.x releases with locked versions.
- All providers migrated away from legacy APIs (`StateNotifierProvider`, `StateProvider`, `ChangeNotifierProvider`, typed `*Ref`s, etc.).
- Generated code regenerated using Riverpod 3 toolchain with zero analyzer warnings.
- Widget/tests suites updated to compile and behave correctly with new notifier semantics and `ProviderObserver` signature.
- Documentation updates (internal notes / README) capturing new conventions.

## Implementation Steps

1. **Preparation & Baseline**
   - Run `dart-mcp.analyze_files` and targeted tests to capture current status.
   - Snapshot key manually maintained provider classes to compare behavior post-migration.

2. **Dependency Upgrade**
   - Update `pubspec.yaml` versions for `riverpod`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, and `riverpod_lint` to 3.x.
   - Execute `dart-mcp.pub get` and record lockfile updates.

3. **Automated Migration Support**
   - Run `dart run custom_lint --fix` (or equivalent MCP invocation) to apply `riverpod_lint` automated migrations.
   - Regenerate sources via `make build_runner` (or MCP build_runner command) ensuring `--delete-conflicting-outputs` is used.

4. **Manual Code Updates**
   - **Notifier Adoption**: Convert remaining `StateNotifier` subclasses to extend `Notifier`/`AsyncNotifier` (including families). Move constructor dependencies into `build()` and handle `ref` access accordingly.
   - **Provider Declarations**: Replace `StateNotifierProvider`/`StateProvider`/`ChangeNotifierProvider` usages with the new `NotifierProvider` / `AutoDisposeNotifierProvider` forms or alternative primitives (for purely stateful cases, consider `StateProvider` from `legacy.dart` only if temporary).
   - **Ref Types & Extensions**: Update custom code referencing typed refs (`ActionItemSuggestionsControllerRef`, etc.) to plain `Ref`. Adjust usages of `ref.keepAlive`, `ref.listenSelf`, `ref.future`, and `ref.invalidate` to their new locations on notifiers where necessary.
   - **Observers & Overrides**: Update `ProviderObserver` implementations to use the new `ProviderObserverContext`, verify `ProviderScope.containerOf` and override APIs for compatibility.
   - **Error Handling**: Audit locations awaiting provider futures (`ref.read(provider.future)`) and ensure they handle the new `ProviderException` wrapping.
   - **Dependency Injection**: For controllers previously receiving dependencies via constructors (e.g., `getIt`), standardize on acquiring dependencies inside `build()` or `ref.watch` to avoid mismatched lifecycle issues.

5. **Widget & Test Adjustments**
   - Update widgets importing Riverpod to reflect new provider names and ensure no legacy helper usage remains.
   - Revise tests that instantiate notifiers/providers directly to use the new `NotifierProvider` patterns and `ProviderContainer` overrides. Modify mocks/stubs extending generated classes to match new signatures.
   - Refresh helper utilities under `test/` and `lib/test_utils` that interact with provider APIs.

6. **Validation & Quality Gates**
   - Run `dart-mcp.analyze_files` until clean.
   - Execute targeted widget/unit tests for each migrated module, followed by full suite via `dart-mcp.run_tests` (with concurrency tuned if necessary).
   - Produce coverage report if required (`make coverage`) to ensure no regressions in exercised paths.

7. **Documentation & Follow-up**
   - Update feature READMEs or internal docs to describe new notifier patterns and migration gotchas.
   - Record any deferred migrations (e.g., spots requiring temporary legacy imports) with explicit TODOs and create follow-up tasks.
   - Communicate changes to the team (release notes / PR description) highlighting new APIs and testing expectations.

## Risk Assessment
- **Breaking Lifecycle Changes**: Notifier lifecycle differs from StateNotifier; mitigate via thorough widget/test coverage and manual verification of ref listeners.
- **Generated Code Drift**: Build_runner may introduce large diffs; mitigate by batching commits and reviewing generated changes carefully.
- **Third-party Integrations**: Ensure packages relying on Riverpod 2 APIs (if any) are compatible or receive updates.

## Testing Strategy
- Prioritize targeted tests for each migrated controller/service.
- Run snapshot-based regression tests (if available) after provider changes.
- Perform manual sanity checks on critical flows (AI suggestions, sync maintenance, dashboards) in debug builds once migration passes automated tests.

## Open Questions
- Are there runtime overrides or provider observers in platform-specific code that require additional updates?
- Do we rely on `family` arguments inside generated `build` methods that need manual constructor adjustments post-migration?
- Should we introduce additional lint rules or CI steps to enforce Notifier usage going forward?

## Sequencing Notes
1. Finalize the isolated trial migration (Action Item Suggestions) and validate behavior.
2. Upgrade dependencies and regenerate code.
3. Migrate remaining modules feature-by-feature, running tests per feature.
4. Conclude with full test suite and documentation updates.
