---
type: Convention
title: Testing conventions
description: "The rules that keep a single-threaded CI lane green — fake time, centralized mocks, teardown discipline, and tagged property tests."
resource: ../../test/README.md
tags: [convention, testing, fake-time, glados, ci]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T12:00:00Z }
stale_after: 2027-01-18
sources:
  - id: test-readme
    resource: ../../test/README.md
    title: Test guidelines
    last_modified: 2026-07-25
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

**Tests in one file share a process, so a leak escapes the test that caused it.**
A timer, stream subscription or database handle left open outlives its own test
and fails a *later* one in the same file — usually one that looks unrelated and
passes in isolation. Almost every rule below exists because of that.

Be precise about the blast radius, because the looser version of this claim keeps
coming back. CI runs `very_good test` with **no `-j`, so its default concurrency
of 4 applies**: four suites run in parallel, each in its own process, sharded ten
ways across matrix jobs. A leak therefore *cannot* reach another file — the reach
is within a file, which is exactly where `tearDown` discipline pays.

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
`DateTime(2024, 3, 15)`, or inject `clock`.

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

**Locally, run the tests your change touches** — `fvm flutter test <path>`, or a
directory while iterating. `make coverage` builds the HTML report when you
genuinely need it.

**Do not run the whole suite locally as a habit.** It is slow enough to stall the
work it is meant to protect, and CI runs it far faster anyway: the Linux lane
shards `very_good test` **ten ways** across parallel matrix jobs, so the full
result arrives on the push without blocking anyone's machine. Push, keep working,
read the result when it lands.

The exception is a change whose blast radius you cannot bound — a shared
helper, a `getIt` registration, a design-system token — where the whole suite is
the only honest check. Even then, prefer letting CI do it.
