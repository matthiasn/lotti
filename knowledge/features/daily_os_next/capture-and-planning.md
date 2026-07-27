---
type: Feature Module
title: Capture and planning
description: The Capture/Reconcile/Draft/Refine tools, batch-first durable voice capture, and the review fence that stops machine text overwriting the user's own words.
resource: ../../../lib/features/daily_os_next/agents/service
tags: [daily-os, capture, planning, transcription, tools]
status: stable
generated: { by: codex/5, at: 2026-07-27T15:38:00+02:00 }
stale_after: 2026-10-27
sources:
  - id: services
    resource: ../../../lib/features/daily_os_next/agents/service
    title: Capture and plan services
    last_modified: 2026-07-26
  - id: prompt-builder
    resource: ../../../lib/features/daily_os_next/agents/workflow/day_agent_prompt_builder.dart
    title: Day-agent prompt builder
    last_modified: 2026-07-27
  - id: workflow
    resource: ../../../lib/features/daily_os_next/agents/workflow
    title: Day-agent workflow and terminal-tool strategy
    last_modified: 2026-07-27
  - id: processing-runtime
    resource: ../../../lib/features/daily_os_next/services/day_processing_runtime.dart
    title: Durable processing runtime
    last_modified: 2026-07-27
  - id: state
    resource: ../../../lib/features/daily_os_next/state
    title: Controllers and runtime wiring
    last_modified: 2026-07-25
  - id: adr-0031
    resource: ../../../docs/adr/0031-batch-first-day-audio-capture.md
    title: ADR 0031 — Batch-first day audio capture
    last_modified: 2026-07-22
---

# The tool surface

`DayAgentStrategy` handles private observations itself and delegates the rest
through the workflow handler:

| Group | Tools |
|-------|-------|
| Scheduling | `set_next_wake` |
| Recall | `search_memory` |
| Knowledge | `propose_knowledge` |
| Capture / Reconcile | `submit_capture`, `parse_capture_to_items`, `match_to_corpus`, `link_capture_phrase_to_task`, `break_capture_link`, `surface_pending_decisions`, `apply_triage`, `create_task_from_phrase` |
| Planning | draft and refine tools |
| Week context | `write_day_summary` |
| Coordination | `issue_day_directive` (coordinator only), `raise_day_status` |

`DayAgentCaptureService` owns the direct Capture/Reconcile mutations.
**`apply_triage` and `create_task_from_phrase` both enforce the planner
identity's category allow-list** — the planner cannot close, re-date, or create
tasks outside its configured categories.

`submit_capture` persists a `CaptureEntity` and enqueues a durable
`parseCapture` outbox job. Its executor later starts the agent wake with a
`capture_submitted:<captureId>` trigger token. **The caller supplies the selected
planning day independently of the recording timestamp**, so reusing a retained
check-in from a past or future Day Activity view cannot enqueue work into the
wrong workspace.

`DayAgentPlanService` writes the drafted plan as a `DayPlanEntity` under
`day_agent_plan:<dayId>`, plus `capture_to_plan` links, and persists refine
diffs as change sets and decisions.

# Why one plan is multiple wakes

The user-facing Capture/Reconcile/Draft journey intentionally has **two model
wakes**: one turns the transcript into reviewable capture items, and a second
turns the user's selections into a plan. The coordinator is a third, separate
agent: its digest consumes status events and recent-day context in the
background, so it can revise the day's directive without making the day agent
own cross-day policy.

Each user-facing wake now has a narrow tool surface:

| Wake | Tools exposed |
|---|---|
| Capture submitted | `parse_capture_to_items` only |
| Drafting | `create_task_from_phrase`, `raise_day_status`, `draft_day_plan` |
| Refine | Normal day-agent tools except `parse_capture_to_items` and `draft_day_plan`; the plan mutation is `propose_plan_diff` |

The parser and drafter tools are **terminal artifacts only in their owning wake
mode**. Once either one is accepted there, `DayAgentStrategy` completes that
conversation immediately rather than asking the provider for a prose wrap-up.
It also stops processing the current tool-call batch, so nothing can mutate
state after the terminal artifact. Any later calls already batched by the
provider are persisted as rejected/skipped without execution, so evaluation
still sees the ordering violation. Rejected calls before the terminal artifact
continue so the model can repair them. This matters twice: an unrestricted
drafting wake can re-parse, triage, search and summarize before it plans, and
continuing after the final write adds another provider call after the requested
artifact already exists. Refine never exposes the full-draft writer, so it
cannot overwrite its baseline instead of producing a reviewable diff.

Durable scheduling has a matching no-lost-signal invariant. When an outbox
change arrives while `DayProcessingRuntime` is already draining, the runtime
must distinguish its own claim/status writes from genuinely new work. It pauses
the outbox subscription during the mutation phase, resumes it before the
due-work query, and lets that query schedule anything that arrived while
paused. A later change sets `_followUpNudgeRequested`, ensuring one immediate
follow-up after `_nudgeFuture` clears. This avoids both a lost capture and the
redundant drain chain that would result from treating every processor status
write as a new enqueue.

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Draining: nudge sets _nudgeFuture
    Draining --> Draining: owned outbox writes while listener paused
    Draining --> Inspecting: drain returns, listener resumes
    Inspecting --> FollowUpRequested: external change sets _followUpNudgeRequested
    Inspecting --> Idle: query schedules due work or finds none
    FollowUpRequested --> Draining: active future clears, immediate nudge
    Idle --> Draining: due-work timer or external change
    Idle --> [*]: dispose
```

# What the write path enforces

The distinction matters for reading eval results and for trusting the model:

| Enforcement | Constraints |
|-------------|-------------|
| **Hard — throws `DayAgentCaptureException`**, rejecting the whole `draft_day_plan` call and handing the message back to the model, which retries | Day boundaries, `end > start`, same-day past-start, allowed categories, committed-plan overwrite, model-authored `committed` blocks, `cal` blocks, unresolvable `taskId` |
| **Prompt contract only** | Block overlap, capacity, decided tasks actually being placed, blocker ordering |

So **the persisted plan is always *legal***, and inspecting it alone measures the
guards rather than the model. See [evaluation](evaluation.md).

**A capture may parse to nothing.** `parse_capture_to_items` accepts an empty
`items` array, meaning "this capture holds nothing to act on" — the only honest
answer to a transcript like *"Nothing much on today."* It used to be rejected,
which left a model that had correctly found nothing with no compliant move:
invent an item, or skip the call and trip `MissingCaptureParseException` and a
forced retry. It was the second most frequent rejection across the eval runs,
and six of seven were that same capture.

An empty parse is not a no-op. `persistParsedItems` replaces a capture's items
wholesale, so it clears an earlier parse rather than leaving a stale queue in
the reconcile panel — which is what makes "nothing here" a correction the model
can actually make. It also writes `CaptureEntity.parseCompletedAt`, the durable
completion signal shared by the workflow, the outbox executor, and Activity's
retry path. Without that marker a successful empty result is indistinguishable
from an unparsed capture after restart and reopening Activity spends another
inference run. Legacy captures with parsed-item links still count as complete.
The marker is monotonic at both the local sync-envelope and repository write
boundaries, so a whole-row rewrite cannot erase locally observed completion;
the sync-envelope merge reads and writes inside one repository transaction.
Every successful parse also writes a deterministic basic self-link
(`capture_parse_completion:<captureId>`). That oldest link variant is readable
by peers predating the marker and syncs independently of the capture row, so a
fresh device still learns completion when it receives a causally newer
marker-less legacy rewrite before the original completion update. The link is
not a `capture_to_parsed_item` edge, so it never appears in the reconcile item
list. A recovered outbox job treats a deleted capture as terminal instead of
retrying removed user intent. Parse finalization also revalidates access against
the transaction-local capture before it replaces any artifacts.

Only an explicitly empty model `items` array means "nothing to act on." A
non-empty response whose entries are all invalid or outside the planner's
category scope is rejected, preserving the previous parse and giving the model
a chance to correct its output. Before replacing parsed items, the service
re-reads the capture inside the write transaction so concurrent edits survive
and a concurrent tombstone is never revived.

## Three guards worth stating precisely

**Planning into the past is refused, whatever the block's type.** For today's
plan, `draft_day_plan` rejects any block it would be *planning* — state `drafted`
or `committed` — whose start precedes `clock.now()` **at the moment the tool
executes**.

That last clause is load-bearing, and getting it wrong was measurable. The
threshold moves between rendering the prompt and enforcing it, because the model
thinks in between — 13s to 152s in the eval. So a plan whose first block starts
at the instant the prompt advertised is *always* rejected: every sampled
`lateStart` cell across both models started the day at 15:00 when the prompt read
`15:00:00.005877`, and all 6/6 lost by under six milliseconds. Complying would
have meant predicting inference latency.

The prompt therefore carries a top-level `<planning_window>` section —
`advertisedPlanningStart`, the first five-minute boundary at least three minutes
out — rather than the raw instant. It is **top-level on purpose**: the
constraint belongs to the day, not to a wake mode. `draft_day_plan` is always
exposed and a scheduled `planning_day` wake builds neither a drafting nor a
refine context, so nesting it under either left exactly those wakes deriving the
threshold themselves. The guard is unchanged and unweakened; only what the model
is *told to aim at* moved.

Late enough in the day, walking forward for that headroom runs past midnight,
and a block outside the plan day is rejected just as firmly — advertising 00:05
tomorrow would steer the model into the same rejection from the other end. So
the window **closes**: `<planning_window>` carries `closed` instead, and the
rules say to leave the day alone rather than add to it. The three states are
deliberately distinct, because collapsing any two misleads:

| `<planning_window>` | Meaning |
|---|---|
| `{"earliestStart": …, "availableMinutes": …}` | today, still plannable — start here, and this is how much is left |
| `{"closed": true}` | today, no usable slot left (no five-minute window before midnight, or no working minutes left) — add nothing |
| `+ {"capacityMinutes": …, "scheduledMinutes": …}` | added on a refine wake — judge your *net* change against these, alongside whichever row above applies |
| `{"availableMinutes": …}` | neither `earliestStart` nor `closed` — the day has not begun, so no part of it is past |

`availableMinutes` is absent from the `closed` row deliberately, and absent
everywhere when the working hours cannot be parsed.

Reading `closed` as `{}` would let a wake at 23:58 plan freely from this
morning, and the guard would reject every block of it.

The day boundary is computed with calendar arithmetic (`DateTime(y, m, d + 1)`),
not by adding 24 hours: on a DST transition day the latter lands on 01:00 or
23:00 and would either advertise into tomorrow or close the window an hour
early.

**The agent cannot create a `committed` block.** `committed` asserts that *the
user approved this block*, and exactly two things may say that: the user
committing the day through the UI, and `acceptPlanDiff` on an already-agreed
plan. So the only `committed` block the model may emit is a faithful repeat of
one the plan already had — same id, same start, same state — which is what a
re-draft over an agreed plan does. Anything else is rejected.

The guard is unconditional rather than part of the past-start rule, which is why
it was missed: guarding `committed` against *backdating* made the hole look
covered, while a forward-dated committed block persisted and projected to the UI
as agreed work. Observed in 4 of 9 archived eval runs, always a single 09:00
block titled "Already scheduled" — the model depicting the directive's
`alreadyScheduledMinutes` as existing commitments. That is a fair thing to want
to express; `drafted` expresses it without claiming a verdict the user never
gave. `committed` stays in the tool schema, unlike `cal`, because its
carry-forward use is real — removing it would force a re-draft to call approved
work `drafted` and silently un-commit it.
**And so are the estimates it is compared against.** `drafting.decidedTasks`
projected only `{id, title, categoryId, status, blockedBy}`, while the rules ask
the model to total `estimateMinutes` and weigh them against `availableMinutes`.
The task corpus was the only carrier of estimates and it renders inside
`<capture>` alone, so on a capture-less wake that instruction was unfollowable —
the same shape as ADR 0043's rule arriving without its data, in a rule written
one commit earlier. `DecidedTaskRef` carries `estimateMinutes` from
`task.data.estimate`, the read `hydrateDecidedTasks` already performs, and it is
omitted rather than zeroed when a task has no estimate.

Both decided-task hydration and task-corpus serialization normalise zero to
absent, because both creation paths store `Duration.zero` rather than null for
an unestimated task — passing `inMinutes` straight through would have told the
model that unsized work costs nothing, which is worse than saying nothing at
all. And absence alone is not enough: the rules say outright that a missing
estimate means **unsized, not free**, so it is given a deliberate slot with a
stated reason or left out, rather than totalling as zero against
`availableMinutes`.

**The day's remaining budget is stated, not derived.** `<planning_window>`
carries `availableMinutes` — working time still available, bounded by the
clock *and* by capacity, whichever binds harder. Without it the model had to
combine three separate facts: `capacityMinutes` and `workingHours` from the
system prompt's planning defaults, and `earliestStart` from the user message.
It did not, and the failures were exactly what that predicts — a plan running
to 17:45 against a 17:00 day, and 780 minutes scheduled against 480 of
capacity.

Same move as `advertisedPlanningStart`: compute what is already known rather
than asking the model to. It counts from the *advertised* start, so the budget
never describes minutes the model is not allowed to use, and it is suppressed
when the window is `closed` — that already carries the instruction, and a
second number saying the same thing invites the model to reconcile two
signals. **It is therefore never zero:** a day with no working minutes left
reports `closed` instead (see below), so `availableMinutes` always names time
the model can actually use. Malformed working hours leave it unstated rather
than guessed, since they are free-text config nothing else parses.

A **refine** wake gets `capacityMinutes` and `scheduledMinutes` *in addition to*
the temporal fields, not instead of them — `proposePlanDiff` enforces the same
past-start guard, so a diff still needs the floor and the clock-bounded
remainder. A diff edits an
existing plan, so what matters is the *net* change — dropping a 180-minute block
to add another is net zero, and judging the addition against the unused
remainder alone would report a conflict that does not exist. Occupancy is
recomputed from the blocks rather than read from the denormalized
`scheduledMinutes`, which can drift; the projection and the agenda view
recompute for the same reason. A drafting baseline is replaced wholesale, so the
whole-day budget is correct there.

A day with **no working minutes left** reports `closed` rather than a start
paired with a budget of zero. Those are the same instruction, and the pair left
a fresh draft no coherent move: the rules forbid running past working hours,
and there is no time left inside them. (`closed` still collides with the
mandatory `draft_day_plan` call on a drafting wake — a pre-existing conflict
tracked in lotti3-ddp, not introduced here.)

The rules pair it with what to do when the work does not fit: decide visibly —
leave work out and name it, or place a task for less than its estimate and say
so — rather than running past the end of the day or quietly shrinking
estimates so everything appears to fit.

Omitted work is **never a block**. In particular, a zero-duration
`UNSCHEDULED` placeholder is not a representation of a trade: `end > start`
correctly rejects it, costs a model retry, and leaves no usable plan artifact.
The drafting rules therefore say explicitly that every block has a later end
and omitted work belongs in an existing block reason. When there is no retained
block to carry that reason, the planner must raise `attentionNeeded`, use the
typed reason matching the conflict (`overCommitted`, or
`directiveUnsatisfiable` for a binding directive), and name the omitted work in
the status note.

**A block that names a task is filed under that task's category.** The block's
own `categoryId` and its `taskId` were each validated against the agent's
allow-set but never against *each other*, so a block could carry a task from one
area and bill its time to another — `plannedMinutesByCategory` and every rollup
built on it read that field.

Derived rather than rejected: the task's category is the only correct answer, so
asking the model to guess it would cost a round trip to learn something already
known. Safe by construction, because `resolveAllowedTaskIds` only returns tasks
whose category this agent may touch — the derived value is always inside the
allow-set the block was checked against. That resolver now returns
id → category from the same read that filters, so the two facts cannot drift
apart again. Blocks with no task (buffers, breaks, manual blocks) keep the
category the model chose, and an uncategorised task leaves it alone rather than
nulling it out of every rollup.

`categoryForPlannedBlock` states the rule once and **both doors apply it** — a
fresh `draft_day_plan` and an accepted `propose_plan_diff`. Enforcing it on one
door only is precisely how the original mismatch existed, so the diff route
derives at *acceptance* rather than at proposal: a ChangeSet is durable and
synced, so one written before this rule, or by a peer on an older build, is
filed correctly when the user accepts it instead of persisting the old
mismatch. A move re-derives even when it only shifts times, which is what makes
that self-healing.

**The agent cannot emit a `cal` block at all**, through either `draft_day_plan` or
`propose_plan_diff`, and the type is absent from both tool schemas. `cal` means
"imported calendar event", and no calendar reaches this agent — `calendarBlocks`
is a deferred parameter `RealDayAgent` drops, and no context section renders
events. Such a block could therefore only assert an import that never happened,
and `DayAgentPlanEditor` would then refuse to edit it, **leaving the user a block
they can neither change here nor find in a calendar.** All of this reverses
together if calendar events are ever rendered into the drafting context.

**A block's `taskId` must resolve to a live task in a category this agent may
touch, on both routes.** `decidedTaskIds` is an argument the model writes itself,
so it is resolved against the journal rather than trusted — and a
`propose_plan_diff` snapshot is held to the same standard, because an accepted
diff copies its `taskId` onto the live plan while the approval summary shows only
title and times. An unchecked reference would be **approved unseen**.

# Batch-first durable voice capture

**Every voice session fixes its context before the microphone opens**: a fresh
recording-session id, a deterministic UUIDv5 activity id, the selected
`dayId`/`planDate` (never the wall clock at stop), the capture intent
(`dayPlan` / `dayRefine`), and the host id when available.

The platform recorder writes a plain `.m4a`. Stop follows a **strict local-first
commit order**:

1. Persist the `JournalAudio` with its `DayAudioContext` provenance.
2. Enqueue and claim the durable transcription job.
3. Run foreground batch transcription through that job's state machine.

```mermaid
stateDiagram-v2
  [*] --> Listening
  Listening --> Error: permission denied / recorder start fails
  Listening --> Transcribing: stop
  Transcribing --> Error: journal persist rejected (audioPersistFailed)
  Transcribing --> SavedPendingTranscription: transcription fails after commit
  Transcribing --> Captured: transcript attached, job succeeded
  SavedPendingTranscription --> Captured: background retry / reviewed text
```

A transcription or network failure **keeps the saved recording** and hands
retries to the background runtime, displayed as a saved-pending warning — never
as a successful empty capture or a lost recording.

**Controller lifecycle epochs fence each start boundary**, so a reset, route
disposal, or superseding start cannot resurrect an obsolete microphone session.

There is **no streaming/realtime transcription path and no live transcript**. The
orb caption carries listening/transcribing status and the waveform freezes dimmed
in its slot — deliberately no inference-bars animation on the recorder surface.
The Reconcile step is where the wait is made visible.

# The review fence

Each unsubmitted recording card embeds `EditorWidget` keyed by the recording's
journal id — **the same Quill editor, toolbar and save path used everywhere else
in the app**; there is no separate text dialog.

Because that save flows through generic journal persistence,
`DayAudioReviewFence` (started with the processing runtime) listens to journal
audio update notifications and terminalizes any non-terminal transcription job
whose recording now carries user-authored `entryText` via `satisfyWithReviewedText`.

**"User-authored" is derived, not flagged**: non-empty text that no machine
transcript on the entity produced.

The transcript writer applies the same invariant, so a late-arriving machine
transcript is recorded as a receipt but **never overwrites reviewed wording**. A
claim revoked mid-attempt — reviewed text or deletion — surfaces as
`DayProcessingClaimRevokedException`, which the processor treats as a benign
deferral.

# Denormalized day columns

`JournalAudio` writes denormalize `dayContext.dayId` and
`dayContext.recordingSessionId` into **indexed journal columns**. Activity and
outbox repair therefore perform bounded day/session lookups instead of
deserializing the full audio history. The schema migration backfills existing
rows and preserves one canonical owner for each stable recording session.

# Attribution

When Capture attaches the transcript to the persisted `JournalAudio`,
`TranscriptAttributionCoordinator` has **already** created an in-memory
attribution session before inference — whenever the coordinator is available,
independently of the concrete transcriber implementation.

The resulting `AudioTranscript` carries a stable sub-id and embedded attribution;
unreported provider cost stays null. Attribution is projected **only after the
journal update confirms it applied**, while the embedded carrier remains
authoritative.

Provider failures, empty transcripts, rejected transcript persistence and user
cancellation all terminalize **without a carrier**; process interruption leaves
no fabricated terminal record. See [AI attribution](../ai/attribution.md).

# Activity

The Day header exposes Agenda, Day and Activity. Activity is a **local
chronological projection** over day-scoped `JournalAudio`, outbox state, typed
and voice `CaptureEntity` check-ins, and the generated plan. It keeps the day's
already-tracked sessions visible in a `TimeSpentCard`, including before the first
plan exists.

It remains available offline and keeps the prior list visible during background
refresh. A saved recording can be played, retried, deleted (cancel job, then
soft-delete the journal entry), edited in place, or routed into the
Reconcile/Refine flow.

**A submitted capture remains a visible durable continuation handle**: reopening
it re-enqueues parsing after a process restart. Missing local audio is reported to
both Activity and the agent context, and setup-required rows link directly to AI
settings.
