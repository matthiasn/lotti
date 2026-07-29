# Daily OS

Daily OS is Lotti's day planner. Instead of dragging tasks onto a calendar, the
user talks: a short spoken check-in about what's on their mind, and an agent turns
it into an actual plan for the day.

It is the `/calendar` tab, and the only Daily OS surface in the app.

## What it does for the user

- **Plans a day from a spoken check-in.** Talk for a minute; the agent transcribes
  it, works out which existing tasks were mentioned, asks about anything
  ambiguous, and drafts a timed plan.
- **Reconciles before planning.** Spoken phrases are matched against real tasks,
  so "finish the migration thing" attaches to the actual task rather than creating
  a duplicate. Anything it cannot place is surfaced as a decision.
- **Refines by conversation.** "Too much", "Move lighter", "Add buffer" — or
  anything spoken — produces a proposed diff on the existing plan, accepted or
  rejected per change.
- **Respects what's real.** The plan knows about tasks already tracked today, due
  dates, estimates, and which tasks are blocked by others.
- **Keeps everything even when things fail.** A recording is saved before anything
  is transcribed, and a failed transcription is retried in the background rather
  than losing the recording. Closing the app mid-plan does not lose the request.
- **Never loses a check-in to a crash.** Capture, parsing, drafting and refining
  are durable jobs on this device — they resume after a restart.
- **Reviews and edits by hand.** Blocks can be dragged, resized, retitled,
  recategorized or deleted, and a recording's text can be corrected in the normal
  editor — corrected text is respected and never overwritten by a late machine
  transcript.
- **Remembers across days.** The planner keeps durable notes about how the user
  works, reviews the past week each morning, and carries commitments forward.

## What it owns

The Day surface and its Agenda / Day / Activity views; the planning modal and its
voice capture; the day-agent workflow, prompt assembly and planning tools; the
day-plan store; the device-local processing outbox for transcription, parsing,
drafting and refining; and Daily OS settings and personalization.

It does not own the agent runtime itself — wake scheduling, memory and the review
gates live in [agents](../agents/README.md) — nor transcription and model routing,
which belong to [ai](../ai/README.md).

## Where the code lives

```text
lib/features/daily_os_next/
├── agents/     # day-agent workflow, services, prompt building
├── database/   # day_processing.sqlite (device-local job outbox)
├── logic/      # pure predicates (availability, recorded time)
├── services/   # processing jobs, outbox repository, job executor
├── state/      # providers, selected date, runtime wiring
├── ui/         # Day page, planning modal, timeline, editors
└── util/
```

The shared day-plan aggregate lives in `lib/classes/day_plan.dart` and is extended
here rather than duplicated.

## Performance envelope

The deterministic full-workflow benchmark stays flat from 1 to 12 simulated
months: aggregate parse / draft / refine / digest provider requests remain
3,587 / 10,315 / 29,167 / 24,906 UTF-8 bytes, with 27 / 25 / 29 / 34
agent-repository reads. Refine and digest include their production continuation
turn. Provider turns are bounded to 4,096 output tokens, except full day drafts
at 8,192; a truncated tool call is discarded and retried rather than becoming a
partial plan. Ordinary CI compares 1- and 12-month corpora and rejects growth in
current-day SQL statements, returned rows, wake prompt bytes, or repository
reads; stopwatch measurements remain an opt-in diagnostic report. The complete
baseline and live Melious evidence are in
[day-planning evaluation and benchmarks](../../../knowledge/features/daily_os_next/evaluation.md).

## How it works

The runtime architecture — agent identities and the per-day cutover, the wake
prompt and its caching contract, the capture and planning tools, the durable
outbox, the coordinator protocol, dependency-aware planning, the UI surfaces and
the evaluation harness — is documented in the knowledge bundle:

**→ [knowledge/features/daily_os_next/](../../../knowledge/features/daily_os_next/)**
