# Oversized Test Suite Decomposition

**Date:** 2026-08-05

**Status:** In progress

**Scope:** The seven largest non-exempt test suites found in the August 2026
engineering due-diligence review

## Goal

Replace monolithic test ownership with suites that follow the production
responsibility boundaries. Each monolith is handled in its own pull request so
scenario movement, test counts, and CI failures remain attributable.

This work does **not** add a new CI policy or size check. The improvement is the
decomposition itself.

## Baseline and PR sequence

| PR | Original suite | Baseline lines | Intended ownership boundary | Status |
|---:|---|---:|---|---|
| 1 | `sync_sequence_log_service_test.dart` | 6,871 | receive, backfill, population, covered clocks, facade/cache | Merged (#3804) |
| 2 | `task_agent_workflow_test.dart` | 9,132 | wake execution, persistence, prompt/context delegation, workflow shell | Merged (#3806) |
| 3 | `unified_ai_inference_repository_test.dart` | 8,593 | inference execution, tool-call processing, post-processing, repository shell | Merged (#3807) |
| 4 | `eval_constraints_test.dart` | 8,228 | split the test-only constraint framework and mirror its focused source files | Merged (#3808) |
| 5 | `outbox_service_test.dart` | 7,820 | send pipeline, queue/database behavior, retry/maintenance, service shell | Merged (#3811) |
| 6 | `day_agent_workflow_test.dart` | 7,379 | day wake execution, context/prompt construction, persistence, workflow shell | Merged (#3812) |
| 7 | `wake_orchestrator_test.dart` | 6,905 | scheduling, drain/claim lifecycle, recovery, orchestrator shell | In progress |

Line counts are the review baseline, not enforced thresholds. They exist so a
PR cannot present a cosmetic rename as decomposition.

## Decomposition rules

1. Preserve meaningful scenarios. Before and after each split, compare test and
   group declarations, then run every resulting executable suite.
2. Prefer production ownership. When a production collaborator or part file
   already owns behavior, its tests move to the mirrored suite. Extract a
   production collaborator when the monolith reveals a real mixed
   responsibility.
3. Use satellite suites only for a cohesive facade whose integration behavior
   cannot honestly belong to one collaborator. Document every exception in
   `test/README.md`, with mutually exclusive ownership boundaries.
4. Shared setup may move to a sibling helper library without `main()`. It must
   centralize real shared wiring and generators, not hide another executable
   monolith.
5. Do not weaken assertions, replace behavior tests with constructor checks, or
   delete coverage merely to reduce a line count.
6. Keep each suite split in its own PR. Do not mix deterministic-time cleanup,
   shared-isolate cleanup, or unrelated production changes into these PRs.

## Verification per PR

- format the repository with `fvm dart format .`;
- run the analyzer with zero warnings or infos;
- run only the resulting test files locally, including property tests;
- compare test/group declaration counts where tests are moved mechanically;
- let the normal sharded CI suite prove optimizer/shared-isolate behavior; and
- inspect patch coverage and actionable review feedback through mergeability.

## Progress

### PR 1 — sync sequence facade

The original sequence facade suite is split by receive/gap behavior, backfill
resolution, population/query behavior, covered-clock semantics, and core
facade/cache behavior. Generated models and common mock wiring live in a helper
library with no `main()`.

The split preserves all 157 test declarations and 39 groups. The largest
resulting executable suite is 2,004 lines.

### PR 2 — task-agent workflow facade

The task-agent workflow suite is split by wake execution, persistence and
model routing, prompt/context assembly, tool handling, and memory capture.
Shared deterministic fixtures and mock wiring live in a helper library with no
`main()`, while `WakeResult` now has its own mirrored suite.

The split preserves all 173 test declarations. The largest resulting
executable suite is 2,333 lines.

### PR 3 — unified AI inference facade

The unified inference suite is split by prompt selection and repository-shell
behavior, multimodal inference execution, response post-processing,
concurrency, normal tool dispatch, and tool recovery paths. Shared lifecycle,
deterministic fixtures, and stream builders live in a helper library with no
`main()`.

The split preserves all 115 conventional test declarations and the Glados
property test. The largest resulting executable suite is 2,368 lines.

### PR 4 — evaluation constraints framework

The test-only evaluation framework now keeps constraint IDs and the ordered
registry in a small shell, with schedule, estimate, trade-off, and content
scoring in focused part files. Each source responsibility has one mirrored test
suite, while deterministic block/outcome builders live in a helper library with
no `main()`.

The split preserves all 341 conventional test declarations, 24 groups, and the
Glados property test. The largest resulting executable suite is 3,908 lines;
the largest focused source part is 1,849 lines.

### PR 5 — outbox service facade

The outbox facade suite is split into service-shell and subscription wiring,
enqueue/database behavior, payload preparation and sequence enrichment, and the
existing send/runner part boundary. Deterministic collaborators, fallback
registration, temporary-directory lifecycle, and service construction live in
a helper library with no `main()`.

The split preserves all 149 test declarations and 29 groups. The largest
resulting executable suite is 2,848 lines. These line counts are descriptive;
this PR adds no CI size check, threshold, or other guardrail.

### PR 6 — day-agent workflow facade

The day-agent workflow suite is split by workflow-shell preconditions, memory
recall, coordinator/directive behavior, capture and planning context, terminal
draft enforcement, tool dispatch, persistence, and week/dependency context.
Shared deterministic identities, mock wiring, prompt parsing, and conversation
capture live in a helper library with no `main()`.

The split preserves all 141 test declarations and the 11 original semantic
groups; seven additional groups are only the executable suite containers. The
largest resulting executable suite is 1,608 lines. These counts describe the
refactor; this PR adds no CI size check, threshold, or other guardrail.

### PR 7 — wake orchestrator facade

The wake-orchestrator suite is split by subscription routing, drain execution,
manual wakes, throttle and deferred scheduling, stale-drain recovery, and
content/timeout behavior. Shared lifecycle wiring and generated property-test
models live in a helper library with no `main()`.

The split preserves all 142 test declarations and the 28 original semantic
groups; five additional groups are only the executable suite containers. The
largest resulting executable suite is 1,936 lines. These counts describe the
refactor; this PR adds no CI size check, threshold, or other guardrail.
