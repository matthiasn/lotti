---
type: Convention
title: Testing conventions
description: "The rules that keep a single-threaded CI lane green — fake time, centralized mocks, teardown discipline, and tagged property tests."
resource: ../../test/README.md
tags: [convention, testing, fake-time, glados, ci]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T15:00:00Z }
stale_after: 2027-01-18
sources:
  - id: test-readme
    resource: ../../test/README.md
    title: Test guidelines
    last_modified: 2026-08-05
  - id: agents-md
    resource: ../../AGENTS.md
    title: Repository guidelines
    last_modified: 2026-07-26
  - id: dart-test
    resource: ../../dart_test.yaml
    title: Test tags
    last_modified: 2026-07-22
---

# The constraint that shapes everything

**A test owns every process-wide resource it mutates.** A timer, stream
subscription, database handle or unconsumed Mocktail matcher can outlive its test
and break a later test in the same file or in an optimized local suite. Almost
every rule below exists because of that.

Unsharded `very_good test` runs use the optimizer by default: it generates a
single `.test_optimizer.dart` importing every test file into one isolate. Very
Good CLI does not yet support sharding independently generated optimized bundles
across runners because their filesystem ordering can differ. The ten-way
standard CI lane therefore uses `tool/ci/generate_test_optimizer.dart` to create
the same sorted bundle in every job before `package:test` slices that one stable
suite into shards. Tests within a shard still share an isolate, while execution
and merged coverage remain complete.

Two consequences:

- **A leak's victim is order-sensitive.** It can break a later test in the same
  optimized shard or local suite.
- **Passing a file alone proves less than it looks.** CI and optimized local runs
  add shared process state across files.

`test/flutter_test_config.dart` registers global teardown for exactly this
reason. It resets Mocktail's matcher state and restores the process-wide test
baseline for DevLogger, Google Fonts, Drift warnings, and GetIt's reassignment
policy after every test. Suite-owned GetIt registrations and resources still
belong to the suite that created them. [`test/README.md`](../../test/README.md)
carries the full account of the Mocktail case; do not re-derive it here.

# Fake time is mandatory

**Never use `Future.delayed()`, `sleep()`, or a real `Timer` in a test.** A real
delay is both slow and flaky, and under a single-threaded lane a pending timer
outlives its test.

- Unit and service tests involving timers, delays, retries or debounce use
  `fakeAsync`, with the repo's retry-time helpers.
- Widget tests prefer `tester.pump(duration)` over `pumpAndSettle()`.
  `pumpAndSettle` carries a 10-second default timeout and hangs when an animation
  never settles; use it only when every animation genuinely must complete, and
  never with a duration above one second.
- **`fakeAsync` does not fake real file I/O.** A test that touches the filesystem
  inside a fake zone will not advance the way it appears to.

**Dates are deterministic.** Never `DateTime.now()` — use a fixed date such as
`DateTime(2024, 3, 15)`, or inject `clock`. The only wall-clock exceptions are
the explicitly tagged `tutorial-video` drivers and `eval-live` model runs
documented in `test/README.md`.

# Shared infrastructure, not per-file improvisation

| Rule | Why |
|------|-----|
| **Mocks come from `test/mocks/mocks.dart`.** Never define one inline if it exists centrally; add it there first | An inline duplicate diverges from the real class signature and silently stops verifying anything |
| **Fallback values come from `test/helpers/fallbacks.dart`** | `registerFallbackValue` is global state; scattering it produces order-dependent failures |
| **Use `setUpTestGetIt()` / `tearDownTestGetIt()`** — never inline `getIt.isRegistered` / `unregister` boilerplate | GetIt is process-wide; a missed unregister leaks into the next test |
| **Use `makeTestableWidget()`** rather than ad-hoc `MaterialApp` / `ProviderScope` wrappers | Localization, media query and provider scoping have to match production |
| **Use the test data factories** where a feature has one | |

**Mocktail global-state hygiene** and **stubbing mixin-declared methods by
mirroring the production call shape** are both documented in `test/README.md` —
the second matters because a mixin method stubbed with the wrong shape compiles
and never matches.

# Structure

- **One test file per source file**, mirroring the path:
  `lib/features/foo/bar.dart` → `test/features/foo/bar_test.dart`. **Never split
  one source file's tests across multiple test files.**
- Keep tests DRY: extract pump/setup helpers when several tests share the same
  wrapping, extract stub helpers when the same `when(...)` appears three or more
  times, and use a `_TestBench` class when the shared setup is genuinely complex.
- **Parameterise varying inputs** rather than copy-pasting bodies for flag
  permutations.

# Quality bar

- **Every test must assert something meaningful.** `findsOneWidget` alone proves
  only that the tree built. Assert displayed content, a state change after an
  interaction, a callback invocation, or error handling.
- **No constructor smoke tests.** Instantiating an object and checking `isNotNull`
  has zero value.
- **Mock setup must not dwarf the test.** A hundred lines of setup for five lines
  of assertion means the test is testing the wrong thing or needs a shared helper.

## The vacuous-pass traps

A regression test that passes with the fix **reverted** is not a regression test.
Always re-run it against the broken state. Three specific traps have bitten this
repo:

- Offstage slivers hide from `find.byType`.
- An `AsyncLoading` with a previous value seeds baselines for free, so a
  stale-while-revalidate assertion can pass without the fix.
- Clamped or fixed-height scenarios assert nothing about the thing under test.

# Property-based tests

Glados property tests are expected for pure and logic-heavy code, not just
examples — and **tagging is mandatory**. `dart_test.yaml` declares `glados`,
`performance`, `eval-live` and `tutorial-video` tags so the fast default lane can
exclude the slow ones and CI can run them on their own step.

An untagged property test lands in the fast lane and slows every run.

# Time-driven UI

Any visible count-up or countdown **must use tabular figures and stable
geometry**, so digit changes, minute/hour transitions and format-length changes do
not move adjacent controls or trigger responsive reflow. Reserve space for the
supported format, or isolate the changing label inside a fixed region.

**Add a deterministic widget regression test** that crosses representative digit
and format boundaries and asserts the timer and its neighbours keep the same size
and position. Examples of this discipline in practice:
[the agent automation row](../features/agents/ui-surfaces.md).

# Running them

**Locally, run the test files for the source files you actually touched.**
`fvm flutter test <path/to/one_test.dart>` — that is the unit of work, not the
directory it sits in.

**Not the whole suite, and not a whole feature either.** A single feature's suite
— `agents` is the clearest case — runs for many minutes locally, and worse inside
a Linux VM, which is long enough to stall the work the tests exist to protect.
CI is both faster and free of your machine: the Linux lane shards
`very_good test` **ten ways** across parallel matrix jobs. Push, keep working,
read the result when it lands.

Two exceptions, and only two: when someone asks for a broader run, and when a
change's blast radius genuinely cannot be bounded to the files you touched — a
shared test helper, a `getIt` registration, a design-system token. Even then,
prefer letting CI do the sweep.

`make coverage` builds the HTML report when you genuinely need it.
