# Test Guidelines

## Running tests locally

- Use `fvm` for every Flutter command — `.fvmrc` pins the version CI uses (currently 3.44.1). Running with a different local SDK can make a test pass locally and fail in CI (or vice versa).
- Iterate on a single file with `fvm flutter test test/path/foo_test.dart` (optionally `--plain-name '<test name>'`). Run targeted files, not the whole suite — the full run is slow.
- **Never pass `--coverage` to an ad-hoc `flutter test <file>` run.** It rewrites the shared `coverage/lcov.info` with only that file's data, clobbering a full-suite report someone else may be relying on. Generate coverage only through the `make` targets (`make test` / `make coverage` / `make coverage_standard`), which manage `coverage/` as a unit.
- Prefer `tester.pump(duration)` over `tester.pumpAndSettle()` (10s default timeout → hangs if an animation never settles). Never pass `pumpAndSettle` a duration > 1s.

## Streams & async teardown

Holding a `StreamController` open across `tester.runAsync(...)` and widget teardown causes a hard-to-debug hang that surfaces as:

```
Bad state: Cannot close sink while adding stream.
Bad state: Cannot add event while adding stream.
```

It happens when the widget's `await for` is still attached to the controller's stream while the test ends and `addTearDown(controller.close)` fires mid-delivery. Avoid it:

- Drive widget streams with a **finite** stream (`Stream.fromIterable([...])`) so the `await for` completes on its own, instead of an open `StreamController` you feed one event at a time.
- If you must use a controller, `await controller.close()` **inside** the test body (before it returns) so the consumer drains before teardown — don't defer the close to `addTearDown`.
- A test that asserts a transient mid-stream UI state ("…while an event is in flight") is inherently racy; assert the settled state after a finite stream completes instead.

For broader test conventions — centralized mocks/fallbacks (`test/mocks/mocks.dart`, `test/helpers/fallbacks.dart`), `setUpTestGetIt()` / `makeTestableWidget()`, the "every test must assert something meaningful" rule, and one-test-file-per-source-file — see the **Testing Guidelines** section of `AGENTS.md`.

## Database test layout

`lib/database/database.dart` and `lib/database/sync_db.dart` are shells (constructor + migration ladder) whose query surfaces live in `part` files holding private mixins (`database_task_queries.dart`, `sync_db_outbox.dart`, …). The tests mirror that layout one test file per part file:

- `test/database/database_*_test.dart` mirror `lib/database/database_*.dart`; shared setup (GetIt registrations, mock stubs, fallback values) and entity builders live in `test/database/test_utils.dart`. `database_test.dart` itself only covers the shell's migration path.
- `test/database/sync_db_*_test.dart` mirror `lib/database/sync_db_*.dart`; the shared outbox-row builder and generated-status model live in `test/database/sync_db_test_utils.dart`. Migration coverage (with `_createXxx` DDL seed helpers) lives in `sync_db_migration_test.dart`.
- Watermark behavior (`sync_db_watermarks.dart`) is exercised through the public sequence-log API in `sync_db_sequence_test.dart` rather than a dedicated file — the watermark members are library-private.

When adding a query to one of the mixins, put its tests in the matching mirror file; don't grow a new monolith or split one source file's tests across files.

### Documented exception: `AgentRepository` satellite suites

`test/features/agents/database/` deliberately splits `AgentRepository`'s tests
by sub-domain — `agent_repository_test.dart` (core) plus the
`_change_set_test.dart` / `_evolution_test.dart` / `_soul_test.dart`
satellites. The repository is a single ~1.7k-line class whose consolidated
mirror would exceed 10k lines; the split is a conscious size-management
decision, not an accident. Rules for the satellites:

- a sub-domain's tests live in exactly **one** satellite (never two);
- Glados generator scaffolding lives in the sibling `*_generators.dart`
  helper libraries (no `main()`, so they are not extra test files);
- new sub-domains get a satellite only when the core file would otherwise
  grow past ~8k lines — default to the core file.

## Mocktail global-state hygiene

Mocktail stores argument matchers (`any`, `captureAny`) in **process-global**
state between `when`/`verify` registration and the mock invocation that
consumes them. A matcher that is registered but never consumed silently
corrupts the next mock interaction — anywhere in the same isolate. Under
plain `flutter test` every file gets its own isolate, so the damage stays
local; under very_good's test optimizer (CI and `make test` run one isolate
per shard) it can break an unrelated test in a different file, and the victim
depends on the platform-specific bundle order — which is why such failures
appear on one machine/shard and not another.

`test/flutter_test_config.dart` therefore registers a global
`tearDown(resetMocktailState)` that clears this state after every test,
confining any leak to the test that caused it. Registered fallback values
survive the reset by design, and stubs live on mock instances, so
`setUpAll`-created stubs keep working. If you see a stub or `verify` that
matches in isolation but fails in a bundled run, suspect a matcher leak in a
test that ran earlier in the bundle — or the mixin-default pitfall below.

## Stubbing mixin-declared methods: mirror the production call shape

`JournalDb` and `SyncDatabase` get their query members from private mixins in
`part` files (see "Database test layout"). Mocktail mocks of these classes
(`MockJournalDb`, `MockSyncDatabase`) dispatch through compiler-generated
noSuchMethod forwarders, and the forwarders' handling of *omitted optional
parameters with default values* is **not stable for mixin-declared members**:
in a plain `flutter test` run the forwarder fills in the declared default
(`catalogId: 'session'`), but in very_good's optimizer bundle (CI) the same
forwarder can fill `null` instead, because the default values of
mixin-cloned members get lost in modular compilation. Which library is
affected depends on compile order, so the failures are
machine/shard-specific: a stub that "works on my machine" can fail only in
CI, and vice versa.

Consequence: a `when`/`verify` on a mixin-declared method matches reliably
**only if it passes exactly the parameters the production call site passes
and omits exactly what production omits**. Example: the sequence-log service
calls `getMissingEntries(limit:, maxRequestCount:, offset:, minAge:)` and
omits `now`, so the stub must supply matchers for all four passed parameters
and must *not* stub `now`:

```dart
when(
  () => mockDb.getMissingEntries(
    limit: any(named: 'limit'),
    maxRequestCount: any(named: 'maxRequestCount'),
    offset: any(named: 'offset'),
    minAge: any(named: 'minAge'),
  ),
).thenAnswer((_) async => []);
```

A lazy `when(() => mockDb.getMissingEntries(limit: any(named: 'limit')))`
matches under plain `flutter test` (both sides get the same forwarder-filled
defaults) but mismatches in the CI bundle (stub records `offset: null`, the
real call passes `offset: 0`) — the mock then returns `null` and the test
dies with `type 'Null' is not a subtype of type 'Future<…>'`. The same
failure surfaced for `getRatingForTimeEntry(targetId)` stubs that omitted
`catalogId` while `RatingRepository` passes it explicitly.

This only bites for *mixin-declared* members mocked via mocktail; methods
declared directly on a class keep their defaults in all compile modes.
Prefer testing the DB mixins against a real in-memory database
(`test/database/*_test.dart` do this); when a service test must mock the DB,
mirror the call shape exactly.

## Property-Based Tests with Glados

We use [`package:glados`](https://pub.dev/packages/glados) for property-based ("generative") testing of pure logic. Going forward, **any new code with non-trivial pure logic should reach for Glados first** — it explores far more inputs than hand-rolled examples and shrinks failing cases automatically. Reach for Glados when you have:

- Pure functions with structured input (parsers, comparators, encoders, math)
- Algebraic invariants (idempotence, commutativity, associativity, round-trips)
- State machines or queues whose invariants must hold across any input sequence

Glados is a poor fit for UI/widget tests, code that touches real I/O, or anything whose correctness depends on a single concrete fixture.

### Tagging is mandatory

Every Glados test **must** carry the `glados` tag so CI can run it on a separate runner from the standard suite:

```dart
import 'package:glados/glados.dart';

Glados(any.myInput, ExploreConfig(numRuns: 120))
    .test('round-trip preserves value', (input) {
  expect(decode(encode(input)), equals(input));
}, tags: 'glados'); //  ← required
```

The `tags` argument is a passthrough to `package:test`'s `test()`. It works the same for `Glados.testWithRandom`, `Glados2`, `Glados3`. The tag is declared in `dart_test.yaml` at the repo root.

### Why the tag matters for CI

CI runs two parallel test lanes — a five-shard standard matrix plus a Glados job — followed by a final Codecov status job gated on both:
- **Unit & Widget Tests** — five shards of `very_good test --coverage --exclude-tags glados -- --total-shards=5 --shard-index=N` (fast feedback, all non-property tests)
- **Glados Property Tests** — `very_good test --coverage --tags glados` (CPU-bound, runs longer in parallel)

A new Glados test without `tags: 'glados'` will run in the standard suite, slowing fast feedback for everyone. The split also lets us upload separate codecov flags (`standard`, `glados`) while still merging all five standard shards plus Glados into the project total. Codecov status publishing is manually triggered by a final CI job after every coverage upload job succeeds, so PRs do not show transient project coverage from only the Glados report or a partial standard shard set.

### Local commands

```bash
make test_standard      # everything except glados (wipes coverage/ first)
make test_glados        # only glados property tests (wipes coverage/ first)
make coverage_standard  # test_standard + HTML report
make coverage_glados    # test_glados   + HTML report
make test               # full suite, no filtering — same as before
```

To reproduce one standard CI shard locally, run:

```bash
very_good test --coverage --exclude-tags glados -- --total-shards=5 --shard-index=0
```

Replace `0` with `1`, `2`, `3`, or `4` for the other shards. The `--` terminator forwards the sharding arguments to the underlying `flutter test` command; the equals-form arguments keep Very Good's test optimizer enabled because no forwarded argument looks like a positional test-file target. The Make test-suite targets (`test`, `test_standard`, `test_glados`, and their `coverage_*` variants) use `very_good test` to match CI behavior. Run `make activate_very_good` once on a fresh checkout.

### Picking `numRuns`

`ExploreConfig(numRuns: N)` controls how many random inputs are explored per property. Existing tests range from 24 to 180, most commonly 120, 160, or 180. Pick the smallest number that still surfaces regressions in your domain — every run is CPU time on every CI build. If you find yourself going above 200, ask whether the property is actually generative or whether a few targeted examples would do better.

### Custom generators

Define generators as private extensions on `Any` in the test file:

```dart
extension _AnyMyType on Any {
  Generator<MyType> get myType =>
      AnyUtils(this).choose(MyType.values);
}
```

Combine via `combine2`/`combine3` for tuples, and prefer using existing generators (`any.int`, `any.dateTime`, etc.) over hand-rolled ones.

### Conventions

These conventions are followed across the existing Glados tests. New tests should follow them too unless there's a good reason not to.

**Per-file vs. shared generators.** Default to a per-file private extension (`_AnyMyType on Any`). Lift a generator into `test/test_utils/glados_generators.dart` only when the same shape appears verbatim in three or more files — see the existing `daysInMonth` / `twoDigits` / `fourDigits` helpers there, which are shared across four test files. A shared generator should be small, focused, and orthogonal to any one feature; if it has to grow new parameters every time a caller migrates, it isn't the right abstraction.

**Value-class naming.** A generated value class is named `_GeneratedX` (e.g., `_GeneratedFollowUpScenario`, `_GeneratedAttachmentObservation`). Shape enums use `_GeneratedXShape` or `_GeneratedXKind`. Keep them private (`_`-prefixed) — they exist to feed one file's properties, not to be reused across files.

**Combinator depth.** Glados ships `combine2` through `combine9`. Prefer a single flat `combineN` over nesting two smaller combinators: shrinking works best when each input dimension is its own primitive that the shrinker can reduce independently. If you find yourself packing several flags into one integer to fit a smaller combinator, expand to the larger one instead — the per-flag shrink behavior is worth the extra parameter.

**`toString()` for shrunken-input legibility.** Every generated value class needs a `toString()` that names each input dimension. Glados prints this exact string when a property fails, so the failure message either reads like a debug record or like `Instance of '_GeneratedFooScenario'`. Pair this with `reason: '$scenario'` (or `reason: 'foo for $scenario'`) on the `expect` so shrunk failures land in the test output already labeled.

**`tags: 'glados'` is enforced by convention, not the analyzer.** Every Glados invocation in this repo carries `tags: 'glados'`. There is no lint that fails on a missing tag — adding one without the tag silently routes it through the standard CI lane and slows everyone down. Mind the tag on copy-paste; check with `grep -L "tags: 'glados'" $(grep -rl 'Glados(' test/)` before opening a PR if you're touching many files.

**Static vs. generated tests.** A handful of static `test('...', () { ... })` cases per file are useful as worked examples — they make a failure during local hacking land on a one-line concrete assertion rather than inside a 160-input Glados loop. Avoid keeping a static case for every variant the generator already covers; once the property exists, the static version is bloat that grows with the input space.

**Mocks come from `test/mocks/mocks.dart`.** Do not declare `class _MockX extends Mock implements X {}` in a Glados test file when a `MockX` already exists there. The centralized mocks carry sensible default stubs (e.g., `MockEvent.originServerTs` returns a fixed `DateTime`) that one-off inline mocks lose. If a new mock is needed, add it to `test/mocks/mocks.dart` first.

## Fake Time Policy

All tests in this codebase must use **deterministic time control** instead of real waits. This ensures:
- Fast test execution
- Deterministic behavior
- No flakiness from timing issues

### Rules

1. **Unit/Service Tests**: Use `fakeAsync` from `package:fake_async/fake_async.dart`
2. **Widget Tests**: Use `tester.pump(duration)` and `tester.pumpAndSettle()`
3. **Never use**:
   - `await Future.delayed(duration)` in tests
   - `sleep()` in tests
   - Real `Timer` instances in tests
4. **Exception**: Tests validating real I/O (network, file system, OS integration) may use real time when necessary

## Retry & Timeout Testing

### Helpers

Two helper utilities simplify testing retry/timeout scenarios:

#### For Unit/Service Tests: `retry_fake_time.dart`

```dart
import 'package:fake_async/fake_async.dart';
import '../test_utils/retry_fake_time.dart';

test('handles timeout with retries', () {
  fakeAsync((async) {
    // Build a plan: 3 attempts, 10s timeout each, 2s exponential backoff
    final plan = buildRetryBackoffPlan(
      maxRetries: 3,
      timeout: const Duration(seconds: 10),
      baseDelay: const Duration(seconds: 2),
      epsilon: const Duration(seconds: 1),
    );

    // Start operation that will timeout and retry
    sut.startWithRetries();
    async.flushMicrotasks();

    // Elapse all retry attempts deterministically
    async.elapseRetryPlan(plan);

    // Assert final state after all retries exhausted
    expect(sut.didExhaustRetries, isTrue);
  });
});
```

#### For Widget Tests: `pump_retry_time.dart`

```dart
import '../test_utils/pump_retry_time.dart';

testWidgets('handles timeout with retries', (tester) async {
  // Build a plan: 3 attempts, 10s timeout each, 2s exponential backoff
  final plan = buildRetryBackoffPumpPlan(
    maxRetries: 3,
    timeout: const Duration(seconds: 10),
    baseDelay: const Duration(seconds: 2),
    epsilon: const Duration(seconds: 1),
  );

  await pumpWidgetUnderTest(tester);

  // Advance virtual time through all retry attempts
  await tester.pumpRetryPlan(plan);

  expect(find.text('Failed after retries'), findsOneWidget);
});
```

### How Retry Plans Work

A retry plan calculates the total time needed to trigger all retry attempts:

**For each attempt** (1 to maxRetries):
1. Elapse `timeout + epsilon` to trigger timeout
2. If not the last attempt and `baseDelay > 0`: elapse `baseDelay * 2^(attempt-1)` for exponential backoff

**Example**: 3 retries, 10s timeout, 2s base delay
- Attempt 1: 11s (timeout + epsilon)
- Backoff 1: 2s (2 * 2^0)
- Attempt 2: 11s
- Backoff 2: 4s (2 * 2^1)
- Attempt 3: 11s
- **Total: 39s of virtual time**

The `epsilon` (default 1ms) ensures the timeout boundary is crossed deterministically.
In some cases (e.g., coarse timeouts or to simplify mental math), using a larger
epsilon such as `Duration(seconds: 1)` is fine, but the helper defaults to
`Duration(milliseconds: 1)`.

### When to Use Retry Helpers

**Use retry helpers when**:
- Testing code that implements timeout + retry logic
- Multiple sequential timeouts need to fire
- Exponential backoff is involved
- You want to make retry behavior explicit in tests

**Don't use retry helpers when**:
- Testing a single timeout (just use `async.elapse(timeout + epsilon)`)
- No retry logic exists
- Testing debounce/throttle (use simple elapse instead)

## Common Patterns

### Single Timeout

```dart
test('times out after 5 seconds', () {
  fakeAsync((async) {
    sut.start();
    async.flushMicrotasks();

    // Elapse slightly past timeout
    async.elapse(const Duration(seconds: 5, milliseconds: 1));
    async.flushMicrotasks();

    expect(sut.timedOut, isTrue);
  });
});
```

### Debounce/Throttle

```dart
test('debounces events with 120ms window', () {
  fakeAsync((async) {
    sut.addEvent('a');
    sut.addEvent('b');
    sut.addEvent('c');
    async.flushMicrotasks();

    // Elapse past debounce window
    async.elapse(const Duration(milliseconds: 121));
    async.flushMicrotasks();

    expect(sut.processedEvents, ['c']); // Only last event
  });
});
```

### Replacing Duration.zero Yields

```dart
// Before
await Future.delayed(Duration.zero);

// After (unit tests)
async.flushMicrotasks();

// After (widget tests)
await tester.pump();
```

### Periodic Timers

```dart
test('periodic timer fires 3 times', () {
  fakeAsync((async) {
    sut.startPeriodicTask(interval: const Duration(seconds: 10));
    async.flushMicrotasks();

    // Advance through 3 periods
    for (var i = 0; i < 3; i++) {
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
    }

    expect(sut.taskExecutionCount, 3);
  });
});
```

## Debugging Fake Time Tests

### Test Hangs

If a test hangs under `fakeAsync`:
- Check for infinite loops that don't involve timers
- Ensure all async operations eventually complete
- Add bounded retries/timeouts in the code under test

### Assertions Fail Too Early

If assertions fire before expected:
- Add `async.flushMicrotasks()` after starting operations
- Ensure you've elapsed enough time
- Check timer/microtask scheduling order

### Timing-Sensitive Assertion Failures

If tests work with real time but fail with fake time:
- Code may schedule work in unexpected order
- Add strategic `flushMicrotasks()` calls
- Use state-based assertions instead of counting intermediate events

## Design-Review Screenshots from Widget Tests

Widget tests can produce real-looking PNGs for design review — see
`test/features/insights/ui/time_analysis_screenshots_test.dart` for the
canonical harness. **Such harnesses must be opt-in** (env-gated, e.g.
`LOTTI_SCREENSHOT_DIR`): `FontLoader` registers fonts process-wide with no
unload, and under very_good's single-isolate optimizer that silently
changes text metrics — and therefore intrinsic widths — for every test
that runs afterwards. The three ingredients:

1. **Real fonts.** Tests render the blocky FlutterTest font by default.
   Load the bundled families with `FontLoader` in `setUpAll`, reading the
   bytes straight from the repo files (`assets/fonts/...`) — `rootBundle`
   cannot load them in unit tests. MaterialIcons comes from the Flutter
   SDK (`$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/`, falling back
   to `.fvm/flutter_sdk`), otherwise icons render as tofu boxes.
2. **Desktop surface.** `tester.view.physicalSize`/`devicePixelRatio` set
   the real render surface; `MediaQueryData` alone does NOT resize the
   viewport (lazy lists won't build below the 800×600 default fold).
3. **Capture.** Wrap the tree in a keyed `RepaintBoundary`, then inside
   `tester.runAsync`: `boundary.toImage` → `toByteData(png)` → write to
   `screenshots/` (gitignored).

Charts gotcha: fl_chart animates data swaps implicitly (~150ms). Pump past
the animation (`tester.pump(const Duration(milliseconds: 600))`) after any
tap that changes chart data, or captures show mid-lerp frames.

## Migration Status

This codebase is in the process of migrating all tests to fake time. See:
- `docs/implementation_plans/2025-11-01_tests_fake_async_migration.md` - Full migration plan
- Completed: All sync tests, AI inference tests
- In Progress: Additional service/controller tests

## Further Reading

- [fake_async package](https://pub.dev/packages/fake_async)
- [Flutter testing guide](https://docs.flutter.dev/cookbook/testing)
- Migration plan: `docs/implementation_plans/2025-11-01_tests_fake_async_migration.md`
