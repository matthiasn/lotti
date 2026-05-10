# Test Guidelines

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

CI runs two parallel jobs:
- **Unit & Widget Tests** — `very_good test --exclude-tags glados` (fast feedback, all non-property tests)
- **Glados Property Tests** — `very_good test --tags glados` (CPU-bound, runs longer in parallel)

A new Glados test without `tags: 'glados'` will run in the standard suite, slowing fast feedback for everyone. The split also lets us upload separate codecov flags (`standard`, `glados`) while still merging both into the project total.

### Local commands

```bash
make test_standard      # everything except glados (wipes coverage/ first)
make test_glados        # only glados property tests (wipes coverage/ first)
make coverage_standard  # test_standard + HTML report
make coverage_glados    # test_glados   + HTML report
make test               # full suite, no filtering — same as before
```

All Make targets use `very_good test` to match CI behavior. Run `make activate_very_good` once on a fresh checkout.

### Picking `numRuns`

`ExploreConfig(numRuns: N)` controls how many random inputs are explored per property. Existing tests use 80–180. Pick the smallest number that still surfaces regressions in your domain — every run is CPU time on every CI build. If you find yourself going above 200, ask whether the property is actually generative or whether a few targeted examples would do better.

### Custom generators

Define generators as private extensions on `Any` in the test file:

```dart
extension _AnyMyType on Any {
  Generator<MyType> get myType =>
      AnyUtils(this).choose(MyType.values);
}
```

Combine via `combine2`/`combine3` for tuples, and prefer using existing generators (`any.int`, `any.dateTime`, etc.) over hand-rolled ones.

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

## Native Desktop Libraries

ObjectBox desktop tests must preload the native macOS framework binary before
importing the ObjectBox-backed store. Use
`test/features/ai/database/objectbox_test_loader.dart` instead of importing
`objectbox_embedding_store.dart` directly in tests.

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

## Migration Status

This codebase is in the process of migrating all tests to fake time. See:
- `docs/implementation_plans/2025-11-01_tests_fake_async_migration.md` - Full migration plan
- Completed: All sync tests, AI inference tests
- In Progress: Additional service/controller tests

## Further Reading

- [fake_async package](https://pub.dev/packages/fake_async)
- [Flutter testing guide](https://docs.flutter.dev/cookbook/testing)
- Migration plan: `docs/implementation_plans/2025-11-01_tests_fake_async_migration.md`
