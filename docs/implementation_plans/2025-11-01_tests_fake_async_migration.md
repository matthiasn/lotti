# Tests — Remove Real Sleeps via fakeAsync

## Summary

- Replace all real waits in tests (e.g., `Future.delayed`, `sleep`, real timers) with deterministic
  time control using `fakeAsync` (unit/service tests) or `tester.pump` (widget tests).
- Goals: speed up the suite significantly, reduce flakiness, and make timing‑sensitive behavior
  deterministic.
- Scope extends beyond sync tests: apply to all `test/` and `integration_test/` where real time is
  used.

## Goals

- Convert remaining real sleeps/waits in unit/service tests to `fakeAsync((async) { … })` with
  `async.elapse` and `async.flushMicrotasks`.
- In widget tests, use `tester.pump` / `pumpAndSettle` instead of `Future.delayed`.
- Where code under test enforces min‑gaps/debounces, elapse the intended amounts deterministically.
- Keep analyzer/test green at each step; update docs and CHANGELOG.

## Non‑Goals

- Do not rewrite production timing logic (only adjust tests and minimal test helpers/mocks).
- Do not change widget tests already using `tester.pump(Duration…)` — those are already virtual
  time.
- No behavior changes to app logic; only increase determinism in tests.

## Findings (grounded in code)

High‑impact remaining real waits in sync (line numbers provided for quick patching):

- `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart`
  - 200, 389, 2628, 3490, 3762, 3868, 3952, 4658, 4961, 5154, 5316, 5328, 5333, 5426, 5432, 5506,
    5587, 5595, 5767, 5834, 5911, 5983, 6054, 6279
  - Many 100–900ms sleeps; converting will notably shorten runtime.
- `test/features/sync/matrix/matrix_service_connectivity_test.dart`
  - 98, 139, 148, 154, 156 (includes a 2s wait)
- `test/features/sync/matrix/pipeline/client_stream_coalescing_test.dart`
  - 94, 96 (100ms + 1800ms)
- `test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart`
  - 244, 349 (500ms)
- `test/features/sync/matrix/matrix_service_pipeline_test.dart`
  - 133 (350ms), 208 (10ms)
- `test/features/sync/matrix/sync_lifecycle_coordinator_test.dart`
  - 106 (50ms), 121 (10ms), 123 (50ms), 143 (150ms), 159 (20ms)
- `test/features/sync/outbox/outbox_service_test.dart`
  - 977 (20ms), 1041 (20ms), 1047 (40ms), 1115 (120ms via delayed), 1135 (200ms)
- `test/features/sync/outbox/outbox_processor_test.dart`
  - 55 (1s inside mock sender) → elapse configured `sendTimeoutOverride` / `retryDelayOverride`.

Lower‑impact (Duration.zero)

- `test/features/sync/matrix/room_test.dart`: 96, 116, 138
- `test/features/sync/matrix/key_verification_runner_test.dart`: 196, 205
- `test/features/sync/state/matrix_stats_provider_test.dart`: 25, 34, 55
- `test/features/sync/state/matrix_state_providers_test.dart`: 108
- `test/features/sync/matrix/sync_room_manager_test.dart`: 142
- Strategy change: replace these with explicit `async.flushMicrotasks()` (or `await tester.pump()`
  in widget tests) and add a short comment indicating the yield point intent. This removes ambiguity
  and aligns with the “no real waits” policy.

Broader suite (outside sync) — examples found via ripgrep:

- `test/blocs/theming/theming_cubit_sync_test.dart`: multiple `Future<void>.delayed(…ms)` waits.
- `test/blocs/theming/theming_cubit_sync_listener_test.dart`: several `Future<void>.delayed`.
- `test/sync/client_runner_test.dart`: uses `Future.delayed` for retries.
- `test/integration/gemma/model_management_integration_test.dart`: inner loops with
  `Future.delayed`.
- Widget tests (many): use `tester.pump(Duration…)` which is already virtual time; no changes
  needed.

Suggested discovery commands (non‑destructive):

- `rg -n --type dart "Future\\.(delayed|wait)\\(|sleep\\(|Timer\\(" test integration_test`
- `rg -n --type dart "await +tester\\.(pump|pumpAndSettle)\\(" test integration_test` (review only;
  not real time)
- `rg -n --type dart "Duration\\((milliseconds|seconds): *[1-9]" test integration_test` (to spot
  suspicious waits)
  Note: see “Enforcement (CI guard)” for a robust, low‑false‑positive approach.

## Design Overview

General conversion pattern for unit/service tests:

1. Wrap the test body in `fakeAsync((async) { … })` from `package:fake_async/fake_async.dart`.
2. Initialize/start SUT; immediately `async.flushMicrotasks()`.
3. Replace `await Future.delayed(x)` with `async.elapse(x); async.flushMicrotasks();`.
4. Where code under test uses recurring/timer‑based scheduling or debounces, elapse enough time to
   cross thresholds; flush after each elapse.
5. If asserting logs or event counts, prefer verifying presence of expected markers rather than
   exact counts overly sensitive to tight timing.

Widget test nuance:

- Do not nest `fakeAsync` inside `testWidgets` (Flutter test already manages virtual time). Use
  `await tester.pump(duration)` and `await tester.pumpAndSettle()` instead of real delays. Replace
  any `Future.delayed` in widget tests with pumps.

Required helper:

- Add `test/test_utils/fake_time.dart`:
  ```dart
  import 'package:fake_async/fake_async.dart';

  extension FakeAsyncX on FakeAsync {
    void elapseAndFlush(Duration duration) {
      elapse(duration);
      flushMicrotasks();
    }
  }
  ```
  Use `async.elapseAndFlush(const Duration(milliseconds: 120));` to keep tests tidy and consistent
  across files.

What to convert vs. what to keep real:

- Convert when the awaited thing is a pure time wait (e.g., `Future.delayed(x)`, `Timer(x)`,
  debounce/min‑gap logic).
- Do NOT use `fakeAsync` around real async work (e.g., DB I/O, file I/O, network/mocks that perform
  real asynchronous steps, real streams producing data from the system). For those, either await
  them normally or refactor the test to separate the timer‑driven parts that can be faked.
- In widget tests, always prefer `tester.pump`/`pumpAndSettle` for virtual time; avoid `fakeAsync`
  inside `testWidgets`.

## Phased Plan

Phase 0 — Discovery & foundations

- Run the ripgrep queries above and snapshot counts by file.
- Classify occurrences into: unit/service (convert to `fakeAsync`) vs widget tests (convert to
  `pump` if using real waits).
- Add required helper `test/test_utils/fake_time.dart` and migrate the first converted file to use
  it (establish pattern).
- Audit whether `test/README.md` exists. Create or update it to document fake time policy, patterns,
  and pitfalls (see “Debugging” and “Timeout implications”). Do not add CI guards yet.

Phase 1 — Biggest wins first (sync) — Completed

- Converted:
  - `matrix_stream_consumer_test.dart` (batched waits to targeted elapses).
  - `matrix_service_connectivity_test.dart` and `client_stream_coalescing_test.dart` (
    debounce/min‑gap).
  - `descriptor_catch_up_manager_test.dart` (scheduling waits).
  - Verified by commit f6313220.

Phase 2 — Remaining sync timing tests — Completed

- Converted `matrix_service_pipeline_test.dart` and `sync_lifecycle_coordinator_test.dart` to fake
  time.
- Converted outbox tests: `outbox_service_test.dart` and `outbox_processor_test.dart` (elapse
  `sendTimeoutOverride` / `retryDelayOverride`).
- Verified by commit f6313220.

Phase 3 — Broader suite cleanup (next priority)

- Sweep non‑sync tests flagged in discovery:
  - `test/blocs/theming/theming_cubit_sync_test.dart` — replace `Future<void>.delayed` with
    `fakeAsync` elapses.
  - `test/blocs/theming/theming_cubit_sync_listener_test.dart` — convert time waits similarly.
  - `test/sync/client_runner_test.dart` — replace retry sleeps with `fakeAsync` elapses.
  - `test/integration/gemma/model_management_integration_test.dart` — only convert pure timer waits;
    keep real I/O awaits.
- Replace `Future.delayed` with `fakeAsync` in unit/service tests; ensure widget tests use pumps
  only.

Phase 4 — Enforce and stabilize

- Land the CI guard (post‑migration) and (optionally) a `custom_lint` rule to flag `Future.delayed`
  usage under `test/`. Place exceptions in an allowlist (see “Mocks & test data exceptions”).
- Ensure `test/README.md` documents the finalized policy and helper usage.

## Migration Playbook (per test)

Before

```dart
test
('retries after 120ms
'
, () async {
sut.start();
await Future.delayed(const Duration(milliseconds: 120));
expect(sut.didRetry, isTrue);
});
```

After

```dart
import 'package:fake_async/fake_async.dart';

test
('retries after 120ms
'
, () {
fakeAsync((async) {
sut.start();
async.flushMicrotasks();
async.elapse(const Duration(milliseconds: 120));
async.flushMicrotasks();
expect(sut.didRetry, isTrue);
});
});
```

Widget test conversion

```dart
testWidgets
('animation completes in 200ms
'
, (tester) async {
await pumpWidgetUnderTest(tester);
await tester.pump(const Duration(milliseconds: 200)); // virtual time
expect(find.byType(DoneIcon), findsOneWidget);
});
```

Notes

- If the SUT schedules work with `Timer.run` or immediate microtasks, call `async.flushMicrotasks()`
  before/after elapse.
- For streams with debounce/throttle (e.g., 120ms), elapse slightly beyond the threshold (e.g.,
  121–125ms). Rationale: many implementations compare `now >= scheduledAt + duration`, and microtask
  scheduling order can make exact equality brittle; advancing past the boundary avoids racey edge
  cases. If the code explicitly checks `>=` and tests are stable with exact durations, exact
  duration is acceptable.

Duration.zero conversions

- Replace `await Future.delayed(Duration.zero)` with `async.flushMicrotasks()` in unit/service
  tests, or with `await tester.pump()` in widget tests. Add a brief comment:
  `// Yield to microtasks queued by SUT`.

## Testing & Verification

- Use MCP tools for a tight loop:
  - Analyze: `dart-mcp.analyze_files` (zero warnings policy).
  - Targeted tests: `dart-mcp.run_tests` with
    `paths: ["test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart"]` while
    iterating.
  - Format: `dart-mcp.dart_format`.
- End‑to‑end: `make test` then `make coverage` to validate suite speed and determinism.

Coverage verification

- Record baseline coverage before migrations and compare after each phase. Timing conversions must
  not drop coverage; ensure all timing‑dependent branches still execute by elapsing appropriate
  durations.

Flakiness measurement

- Before Phase 1, run the suite N times to measure baseline flake rate; repeat after each phase.
  Example: `for i in {1..10}; do dart test --test-randomize-ordering-seed=random || exit 1; done`
  Track failures and duration deltas in `docs/progress/`.

## Risks & Mitigations

- Nested fake time in widget tests can conflict with Flutter’s own fake clock. Mitigation: avoid
  `fakeAsync` inside `testWidgets`; prefer pumps.
- Over‑reliance on exact timing counts can make tests brittle. Mitigation: assert on
  markers/terminal states rather than transient counts when timing windows are involved.
- Microtask vs timer ordering differences. Mitigation: flush microtasks between elapses
  consistently.
- Infinite loops/timeouts: `fakeAsync` won’t consume real time; a busy loop can hang a test. Keep
  per‑test logic bounded, assert on terminal states, and prefer `pumpAndSettle`/bounded elapses.

Rollback strategy

- Each phase lands as a separate PR limited to a few files. If regressions occur, revert the phase
  PR cleanly. Defer enabling CI guard until after all migrations to avoid blocking reverts.

## Rollout Plan

1) PR 1 — Discovery + foundations

- Commit the discovery summary, add `test/test_utils/fake_time.dart`, and update `test/README.md`
  with policy and patterns.

2) PR 2 — Phase 1 (sync: high‑impact files)

- Convert `matrix_stream_consumer_test.dart`, `matrix_service_connectivity_test.dart`,
  `client_stream_coalescing_test.dart`, `descriptor_catch_up_manager_test.dart`.

3) PR 3 — Phase 2 (remaining sync)

- Convert `matrix_service_pipeline_test.dart`, `sync_lifecycle_coordinator_test.dart`,
  `outbox_service_test.dart`, `outbox_processor_test.dart`.

4) PR 4 — Phase 3 (broader suite)

- Sweep remaining `Future.delayed` under `test/` and `integration_test/`. Convert per rules above.

5) PR 5 — Enforce

- Land or tighten CI guard; consider a `custom_lint` rule and finalize `test/README.md` section on
  fake time.

## Acceptance Criteria

- No uses of real waits (`Future.delayed`, `sleep`, real `Timer`) under `test/` and
  `integration_test/`, except explicitly allowed mocks defined in the allowlist.
- Widget tests rely only on `tester.pump`/`pumpAndSettle` for time; no `Future.delayed`.
- Analyzer shows zero warnings; tests pass reliably; measured runtime reduced for the targeted
  files.

---

## Integration Tests — Decision Criteria

- Prefer keeping real time when the test validates end‑to‑end behavior involving OS, plugins, or
  real I/O where virtual time would hide integration issues.
- It is acceptable to fake time for purely app‑internal timers/debounces while still awaiting real
  operations. Strategy: do not wrap the whole test in `fakeAsync`; instead, abstract and drive the
  timer‑dependent unit with fake time or use widget `pump` where applicable.
- If a test currently uses long delays solely to wait for internal timers, convert those waits to
  controlled elapses while preserving real I/O awaits.

## Mocks & Test Data Exceptions

- Allowed exceptions (document in allowlist):
  - Mock services that simulate network latency to exercise timeout/error paths (e.g.,
    `MockGemmaService.streamingDelay`).
  - Test data builders that include delays for sequencing in recorded transcripts.
- Requirements for exceptions:
  - The delay must be configurable and settable to `Duration.zero` or driven by fake time in tests
    using it.
  - Annotate with a comment: `// allowed-test-delay: intentional simulation for <reason>`.
  - Add the file or pattern to the CI guard allowlist.

## Debugging Guidance

- When a converted test fails unexpectedly:
  - Verify microtask flushing: add `async.flushMicrotasks()` before/after `elapse` segments.
  - Try elapsing slightly beyond threshold windows (e.g., 121–125ms for 120ms debounce).
  - Temporarily run the body without `fakeAsync` to observe real clock behavior; reduce waits to
    keep iterations fast.
  - Add logging of state transitions and scheduled times in the SUT/test.
- Common patterns:
  - Timer fires but handler enqueues a microtask — you must flush microtasks after elapse.
  - Multiple timers scheduled — elapse in chunks and assert intermediate states.
  - `Timer.periodic` requires advancing time stepwise to trigger N ticks; don’t jump to a large
    duration if testing intermediate effects.

## Enforcement (CI guard)

- Phase 4 only. Two‑tier approach:
  - Short‑term: grep‑based guard tuned to reduce false positives:
    ```bash
    disallow='(Future\s*\.\s*delayed\s*\(|sleep\s*\()'
    rg -n --type dart "$disallow" test integration_test \
      | rg -v '^\s*//' \
      | rg -v '"[^"]*(Future\\.delayed|sleep)'; status=$?
    test $status -ne 0
    ```
    Maintain an allowlist (file paths) that is filtered out with
    `rg -v -f tools/test_delay_allowlist.txt`.
  - Long‑term: add a `custom_lint` rule that flags usages under `test/` except allowlisted
    locations; integrate into `make analyze`.

## Timeout Implications

- `fakeAsync` eliminates real clock passage; test runner timeouts may not catch logical busy loops.
  Keep assertions focused on terminal states and bound loops with counters where appropriate. Use
  runner default timeouts conservatively for integration tests that still use real time.
- Status Update (2025‑11‑02)
- Completed in sync tests (see latest commit f6313220):
  - Converted to `fakeAsync` with deterministic `elapse`/flushes across key sync suites:
    - `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart`
    - `test/features/sync/matrix/matrix_service_connectivity_test.dart`
    - `test/features/sync/matrix/pipeline/client_stream_coalescing_test.dart`
    - `test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart`
    - `test/features/sync/matrix/matrix_service_pipeline_test.dart`
    - `test/features/sync/matrix/sync_lifecycle_coordinator_test.dart`
    - `test/features/sync/outbox/outbox_service_test.dart`
    - `test/features/sync/outbox/outbox_processor_test.dart`
    - Related additions: `matrix_stream_consumer_signal_test.dart`, `catch_up_strategy_test.dart`,
      `outbox_retry_cap_db_test.dart`
- Next focus: apply the same policy to non‑sync unit/service tests; keep widget tests on
  `tester.pump`.

Status Update (2025‑11‑02 — non‑sync progress)

- Converted remaining real waits in non‑sync tests and tightened AI timeouts:
  - `test/services/tags_service_test.dart` — replaced 100ms sleeps with `fakeAsync` +
    `flushMicrotasks()` across stream‑driven cache updates; no real waits remain.
  - `test/features/ai/repository/ollama_model_management_test.dart` — converted two 2s network delay
    simulations to `fakeAsync` and drove elapse deterministically for timeout handling and warm‑up;
    no real waiting.
- Verified targeted regressions are green locally:
  - `test/services/logging_service_test.dart` — stable under isolation; no sleeps needed anymore.
  - `test/features/journal/ui/pages/infinite_journal_page_test.dart` — passes with existing path
    provider mock setup.
- Follow‑ups queued:
  - Sweep AI tests for any lingering long `Future.delayed` in mocks; prefer `fakeAsync` or immediate
    `TimeoutException` to avoid real time.
  - Consider a lightweight `setUpAll` helper in AI suites to call
    `MockGemmaService.setFastDelays(stream: 1ms, step: 1ms, simulate: 2ms)` where appropriate.

## Remaining Candidates (Next Sweep)

These tests still contain real-time waits (`Future.delayed`, periodic streams, or mock latencies)
and should be converted to fake time where applicable. Widget tests should replace any
`Future.delayed` with `tester.pump(...)` and keep `pumpAndSettle` bounded; unit/service tests should
wrap bodies in `fakeAsync` and drive `elapse`/`flushMicrotasks`.

Highest‑impact (largest counts and/or long waits)

- [ ] test/blocs/journal/journal_page_cubit_persistence_test.dart — many `Duration.zero` yields and
  short sleeps; convert to `fakeAsync` and replace yields with `flushMicrotasks`.
- [ ] test/blocs/journal/journal_page_cubit_test.dart — repeated `defaultWait` sleeps (20–300ms) and
  explicit `Future.delayed`; migrate to `fakeAsync` and rely on `blocTest.wait` or deterministic
  elapses.
- [ ] test/features/ai_chat/ui/controllers/chat_session_controller_test.dart — multiple short sleeps;
  convert to `fakeAsync` and drive timers/microtasks deterministically.
- [ ] test/features/speech/helpers/automatic_prompt_trigger_test.dart — numerous 30–100ms waits; wrap in
  `fakeAsync` and elapse thresholds for debounce/gate logic.
- [ ] test/features/sync/outbox/outbox_service_test.dart — mocks return `Future.delayed` (12–30s) and
  internal 120–200ms waits; inject short override durations and elapse via `fakeAsync`.
- [ ] test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart — two 500ms waits;
  convert to `fakeAsync` and elapse.
- [ ] test/features/sync/matrix/matrix_service_pipeline_test.dart — 350ms wait; convert to `fakeAsync`
  and elapse.
- [ ] test/features/ai/state/linked_entity_inference_test.dart — many 50–100ms waits; convert to
  `fakeAsync` and use `waitUntil(..., fake: async)` from `test/utils/utils.dart`.
- [ ] test/test_helpers/mock_gemma_service.dart — streaming and download delays; ensure suites call
  `MockGemmaService.setFastDelays(...)` or drive via fake time where practical.

Additional unit/service tests to migrate (contains real `Future.delayed`)

- [ ] test/database/common_test.dart
- [ ] test/logic/persistence_logic_test.dart
- [ ] test/services/logging_service_test.dart (replace `Duration.zero` with `flushMicrotasks`)
- [ ] test/sync/client_runner_test.dart (retry sleeps → `fakeAsync` elapse)
- [ ] test/utils/cache_extension_test.dart
- [ ] test/utils/utils.dart (prefer passing `fake:` parameter to avoid real polling)
- [ ] test/utils/wait.dart (deprecate; replace with `fakeAsync` + `elapse` in callers)

AI repositories and controllers (unit/service; convert to fake time)

- [ ] test/features/ai/repository/gemma3n_inference_repository_test.dart
- [ ] test/features/ai/repository/ollama_model_management_test.dart
- [ ] test/features/ai/repository/unified_ai_inference_integration_test.dart (keep real I/O; only fake
  pure waits)
- [ ] test/features/ai/repository/unified_ai_inference_repository_test.dart
- [ ] test/features/ai/repository/whisper_inference_repository_test.dart
- [ ] test/features/ai/state/active_inference_controller_test.dart
- [ ] test/features/ai/state/direct_task_summary_refresh_controller_test.dart
- [ ] test/features/ai/state/latest_summary_controller_test.dart
- [ ] test/features/ai/state/settings/ai_config_by_type_controller_test.dart
- [ ] test/features/ai/state/settings/prompt_form_controller_test.dart
- [ ] test/features/ai/state/task_summary_refresh_status_listener_test.dart
- [ ] test/features/ai/state/unified_ai_controller_test.dart
- [ ] test/features/ai/conversation/conversation_manager_test.dart (several `Duration.zero` and small
  waits)

AI UI and widget tests (replace real waits with pumps; keep virtual time)

- [ ] test/features/ai/ui/gemma_model_install_dialog_test.dart
- [ ] test/features/ai/ui/settings/ai_settings_page_integration_test.dart
- [ ] test/features/ai/ui/unified_ai_popup_menu_test.dart
- [ ] test/features/ai/ui/unified_ai_progress_view_controller_test.dart
- [ ] test/features/ai_chat/ui/widgets/chat_interface/chat_input_voice_test.dart

AI chat controllers (Riverpod controllers; unit‑style)

- [ ] test/features/ai_chat/ui/controllers/chat_recorder_controller_test.dart — uses `Stream.periodic`
  and short sleeps; prefer `fakeAsync` and manual event emission (or elapse periodic ticks).
- [ ] test/features/ai_chat/ui/controllers/chat_sessions_controller_test.dart — contains a real wait;
  migrate to `fakeAsync`.

Categories, labels, calendar, journal state (unit/service)

- [ ] test/features/categories/repository/categories_repository_test.dart
- [ ] test/features/categories/state/categories_list_controller_test.dart
- [ ] test/features/categories/state/category_details_controller_test.dart
- [ ] test/features/labels/integration/label_workflow_test.dart (treat as integration; keep real I/O,
  fake only pure waits)
- [ ] test/features/labels/label_assignment_processor_edge_cases_test.dart
- [ ] test/features/labels/services/label_validator_test.dart
- [ ] test/features/labels/state/label_editor_controller_test.dart
- [ ] test/features/journal/state/linked_entries_controller_test.dart
- [ ] test/features/journal/state/linked_from_entries_controller_test.dart
- [ ] test/features/calendar/state/day_view_controller_test.dart

Matrix/sync state and rooms (small `Duration.zero` yields)

- [ ] test/features/sync/matrix/room_test.dart — replace `Duration.zero` with `flushMicrotasks`.
- [ ] test/features/sync/matrix/key_verification_runner_test.dart — replace `Duration.zero` with
  `flushMicrotasks`.
- [ ] test/features/sync/matrix/sync_room_manager_test.dart — replace `Duration.zero` with
  `flushMicrotasks`.
- [ ] test/features/sync/state/matrix_state_providers_test.dart — replace `Duration.zero` with
  `flushMicrotasks`.
- [ ] test/features/sync/state/matrix_stats_provider_test.dart — replace `Duration.zero` with
  `flushMicrotasks`.

Integration and system‑level tests (evaluate per test; fake only pure timer waits)

- [ ] test/integration/gemma/model_management_integration_test.dart — inner short sleeps (5–10ms) for
  polling; prefer `waitUntil(..., fake: async)` where feasible, keep real HTTP/file I/O.
- [ ] test/flatpak/flatpak_security_test.dart — contains a 2ms delay; likely negligible, but can be
  converted to `fakeAsync` if it’s a pure wait.
- [ ] test/utils/screenshots_flatpak_test.dart — contains a 2ms delay used in polling; consider
  switching to fake polling.

Notes

- Some files already contain `fakeAsync` in specific tests (e.g.,
  `test/services/ip_geolocation_service_test.dart` timeout case). For these, only convert the
  remaining occurrences that still use real delays.
- For mocks returning delayed futures in `thenAnswer(...)`, prefer injecting a configurable duration
  and using `fakeAsync` elapse instead of real time.

Expected impact

- Migrating the high‑impact buckets (journal cubit tests, AI chat/session controllers, speech
  helpers, outbox, descriptor catch‑up) is expected to shave an additional ~20–40s from
  `very_good test` on local CI hardware by eliminating hundreds of small sleeps and a few large
  mocked delays.
