# Day-planning quality: progress and what is left

Handover document. Written 2026-07-27 for whoever picks this up next.

## What this work is

The day planner is an LLM emitting `draft_day_plan` / `propose_plan_diff` tool
calls. An eval framework (`test/features/daily_os_next/eval/`) runs a matrix of
scenarios × models × samples through the **real** pipeline, scoring the output
against pure constraint scorers. It is opt-in and never runs in CI.

The framework itself is built and merged. This document covers what it has
*found*, what has been fixed, and what remains.

## The pattern that keeps paying

Almost every defect found so far has one shape:

> **The prompt asks the model to derive something the app already knows.**

The fix is always the same move — compute it and state it. Instances:

| Defect | The derivation asked for |
|---|---|
| `lotti3-e27` | "respect blockers" while `blockedBy` was never rendered |
| `lotti3-y65` | derive the earliest legal start *and* predict your own inference latency |
| `lotti3-6n3` | combine capacity + working hours + start, across two prompt sections |
| `lotti3-5u8` | total estimates that were not in the projection carrying the rule |

**When you find the next one, look for a rule whose data lives somewhere the
wake does not render.** That has been the single most productive question.

A second, related pattern: **a guard that rejects what a competent model
produces**. `lotti3-y65` (start always rejected), `lotti3-1os` (cannot say a
capture is empty), `lotti3-ddp` (closed window vs mandatory draft). Check the
rejection tallies in the eval reports — they surface these directly.

## Shipped (merged to main)

| PR | What it closed |
|---|---|
| #3596 | three ways a plan could reference work it should not |
| #3601 | ADR 0043's blocked-work data never reaching the model (`lotti3-e27`) |
| #3610 | past-start rejections (`lotti3-y65`) |
| #3613 | the model marking blocks as user-approved (`lotti3-cqc`) |
| #3615 | time credited to the wrong category (`lotti3-lcs`) |
| #3617 | the day's remaining budget stated, not derived (`lotti3-6n3`) |
| #3622 | generated planning-window and block-category properties |
| #3625 | an explicit empty capture parse is accepted (`lotti3-1os`) |

Plus the eval framework itself (#3586–#3593), which is test-only.

### Measured improvements

These are the only numbers worth quoting, and each is a before/after on the same
scenario and models (glm-5.2 and qwen3.5-397b-a17b, 3 samples each):

- **`blockerBeforeBlocked`** — `blockedWithoutCorpus` failed 6/6 cells before
  #3601; after, both models decline the blocked leaf instead of placing it.
- **past-start rejections** — `lateStart` 6/6 cells rejected before #3610; 0/6
  after. `compliedWithoutRejection` 100% both models.
- **`withinWorkingHours`** — glm 33% → 100% on `lateStart` after #3617. (This
  closed a regression #3610 had introduced.)

## Open pull requests

**Do not merge these yourself** — the maintainer does that.

| PR | Branch | State |
|---|---|---|
| #3624 | `fix/decided-tasks-carry-their-estimate` | `lotti3-5u8`; rebased onto current main, review feedback addressed and pushed |
| #3627 | `agent/persist-empty-capture-parse` | post-merge #3625 review follow-up; durable empty-parse completion, draft |

## Continuation — 2026-07-27 review pass

The unresolved threads on both PRs were refreshed through GitHub's thread-aware
GraphQL view and addressed:

- A successful explicit empty parse now satisfies workflow enforcement.
- `CaptureEntity.parseCompletedAt` durably distinguishes a completed empty parse
  from a capture that has never been parsed, so Activity retry does not spend a
  second inference or recreate cleared items.
- Decided-task and task-corpus projections omit non-positive estimates. Missing
  means unsized, not free; the prompt requires a deliberate explained slot or an
  explicit omission.
- `hydrateDecidedTasks` documents that estimate propagation is independent of
  dependency resolution.
- The hydration tests now live in the mirrored
  `day_agent_plan_editor_test.dart`, including the resolver-present path.
- CHANGELOG and Flatpak release notes cover estimate-aware planning as well as
  empty captures.

Validation after the final review edits:

- 475 targeted tests passed across the eight touched test files.
- Whole-repository `fvm dart analyze`: no issues.
- `make knowledge_check`: 89 concepts and 132 Mermaid blocks passed.
- After splitting and rebasing, #3624 passed 297 targeted tests and #3627
  passed 302 targeted tests; both branches repeated analyzer and knowledge
  validation successfully.

The final Melious matrix used `restraint,overCommitted`, 3 samples, and
`glm-5.2,qwen3.5-397b-a17b`:

- Local report:
  `tmp/day-planning-eval/2026-07-27-pr3624-3625-review-fixes-final/day-planning-eval-20260727-020006.md`
- Local judge bundle:
  `tmp/day-planning-eval/2026-07-27-pr3624-3625-review-fixes-final/day-planning-eval-20260727-020006.json`
- Empty-parse restraint held: `noInventedWork` and
  `compliedWithoutRejection` were 3/3 for both models.
- Estimate-capacity compliance remains 3/6 overall. It moved from qwen 2/3 and
  GLM 1/3 in the preceding run to qwen 1/3 and GLM 2/3 here, which is sampling
  noise rather than an improvement.
- Two GLM samples first emitted a zero-length "unscheduled" block and needed the
  forced retry (`block end must be after start`). The retry produced a usable
  plan, but this is a new concrete rejection shape for the next planning-quality
  pass.

Durable tracker updates:

- `lotti3-1os` and `lotti3-5u8` carry the implementation, validation, and
  publication notes.
- `lotti3-qip` and `lotti3-anb.11` carry the qualitative-scoring evidence.
- New bug `lotti3-ga5` tracks the zero-length "unscheduled" placeholder
  rejection.

Published Git state:

- #3624 was rebased onto `ba4f4a5fd`, committed, force-pushed with lease, and
  retitled to match its remaining diff.
- The already-merged #3625 could not be updated, so its post-merge review fixes
  became draft PR #3627.
- #3622 was verified as already merged; no duplicate PR was opened.
- No review replies or thread resolutions were posted.

## Open work, in the order I would take it

### 1. `lotti3-ga5` — never represent omitted work as a zero-length block

Two GLM samples encoded an omitted task as an `UNSCHEDULED` buffer from
17:00–17:00. The writer correctly rejected `end == start`, and forced retry
produced a usable plan, but the invalid first call costs time and tokens. Make
the drafting rule explicit: omitted work belongs in a reason or status note,
never in a placeholder block. Re-run `overCommitted` and require zero instances
of this rejection shape without weakening the writer guard.

### 2. `lotti3-qip` + `lotti3-anb.11` — verify a truncated task was declared partial

On a day that cannot fit, the planner may either drop work and name it, or
place a task partially and say so. The eval checks the first and not the second:
`respectsEstimates` stands down on an impossible day (correctly — see below),
and `surfacedConflict` looks only for *omitted* work, so a truncation makes both
stand down. Nothing verifies the declaration.

Both models did declare it well in practice, so this is an instrument gap, not a
behaviour one. It needs reason-text reading, which is the same gameable
string-matching family `anb.11` covers — do them together rather than adding a
second brittle matcher.

### 3. `lotti3-ddp` — needs a product decision, not code

`<planning_window>` can report `closed` (no usable slot left today), while the
drafting rules require `draft_day_plan` as the final call and the write path
rejects an empty block list. A fresh draft with no baseline cannot satisfy both.

Two candidate resolutions, both in the bead. **Ask the maintainer** — guessing
here would be worse than leaving it. Do not "fix" it by dropping the closed
state; that reintroduces `lotti3-y65`.

### 4. The variant seam — the constraint on everything after this

`EvalVariant` can only transform `DayAgentConfig`. The framework says so
explicitly:

> *"Swapping a prompt section or reordering context needs a production seam that
> does not exist yet."*

So prompt changes cannot be A/B'd in one pass. Every improvement so far was
measured as before/after across two runs, which worked **only because the
effects were large** (6/6 → 0/6). It will not resolve, say, `respectsEstimates`
84% → 92%, where sampling noise swamps the signal.

Building that seam is what makes the next ten changes measurable. I recommended
it repeatedly and never got to it; the remaining quality work needs it.

### 5. Scenario coverage gaps

No scenario exercises: a hand-marked `BLOCKED` task (no links), a cross-category
blocker, or a re-draft over a baseline plan. All three are paths that production
code now handles and the eval never visits.

### 6. `lotti3-eg0` — CI flake, not ours

`Matrix Test on Linux with degraded network` has failed on four consecutive PRs
that touch nothing under `sync/` or `matrix/`, and the same commits pass on main
after merge. It is a convergence race (600-message burst, client rejoining,
injected latency). Worth fixing or marking non-blocking — a check that fails on
innocent PRs trains people to merge past red, and one PR already did.

## Things I got wrong, so you do not repeat them

Recorded because several cost multiple review rounds.

- **I fix one door and miss its sibling.** Three consecutive PRs shipped a rule
  enforced at the draft path but not the diff path, or on drafting wakes but not
  refine/scheduled ones. **Before opening a PR, enumerate every door a rule must
  hold at, and say so in the description.**
- **The edges of my own new rule are where the bugs are.** Not the original
  defect — the boundary conditions of the fix. One second of headroom before a
  five-minute mark; a walk past midnight; DST where +24h is not the next
  midnight; a partial-match carry-forward.
- **Property tests over ranges caught more of these than hand-picked cases.**
  But **sweep what is finite, generate what is not** — I replaced an exhaustive
  1,440-minute sweep with 300 random samples and lost coverage. Review caught it.
- **Do not assert a constant against itself.** A property comparing a gap to
  `minimumPlanningHeadroom` lets the constant and the test weaken together. Pin
  the magnitude separately.
- **Verify CHANGELOG placement after editing.** I filed a note under the
  previous release twice, because `0.9.1071` had `### Added` but no `### Fixed`,
  so an index-based insert silently landed in `0.9.1070`. Grep both sections
  afterwards.
- **Read conflict content before resolving.** Mechanically keeping both sides of
  the recurring flatpak collision duplicated an upstream release note, because
  the two sides were the *same* content across successive rebases.
- **I over-claimed a measurement.** I repeated "glm writes committed blocks 2/3
  samples" for most of a session; the archived runs show 4 of 9 *runs*, one block
  each. Check the JSON before quoting a number.

## Running the eval

```sh
set -a; source .env; set +a   # provides UP_UPSTREAM_API_KEY / UP_UPSTREAM_BASE_URL
export MELIOUS_API_KEY="$UP_UPSTREAM_API_KEY"
export MELIOUS_BASE_URL="$UP_UPSTREAM_BASE_URL"
LOTTI_DAY_PLANNING_EVAL_LIVE=1 \
DAY_PLANNING_EVAL_MODELS=glm-5.2,qwen3.5-397b-a17b \
DAY_PLANNING_EVAL_SAMPLES=3 \
DAY_PLANNING_EVAL_SCENARIOS=lateStart,overCommitted \
DAY_PLANNING_EVAL_DIR=tmp/day-planning-eval/<name> \
  fvm flutter test test/features/daily_os_next/eval/day_planning_eval_live_test.dart --tags eval-live
```

It always passes and reports; the deliverable is the Markdown report and the
JSON judge bundle beside it. Archived runs live under `tmp/day-planning-eval/`
and are worth grepping before forming a hypothesis — I have twice been wrong
about behaviour that the bundles settled in one query.

Per-scenario rates come from `scenarioMatrix` in the JSON; the Markdown table
aggregates across scenarios and will mislead you if you are comparing one.

## Reference

- Concepts: `knowledge/features/daily_os_next/` — `capture-and-planning.md`,
  `dependency-aware-planning.md`, `evaluation.md`, `wake-prompt.md`
- Eval framework: `test/features/daily_os_next/eval/framework/`
- Prompt rules: `lib/features/daily_os_next/agents/workflow/day_agent_prompt_builder.dart`
- Window/budget logic: `lib/features/daily_os_next/agents/service/day_agent_plan_parser.dart`
- ADRs 0006, 0032, 0042, 0043 under `docs/adr/`
