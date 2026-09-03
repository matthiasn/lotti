# Daily OS

Daily OS is Lotti's day planner. Instead of dragging tasks onto a calendar, the
user talks: a short spoken check-in about what's on their mind, and an agent turns
it into an actual plan for the day.

It is the `/calendar` tab. On desktop, one piece of it also lives outside the
tab: the docked day-view column on the right edge of the app shell
(`ui/widgets/day_view_side_panel.dart`) reuses the day timeline to keep a day's
planned-vs-recorded time visible beside the tasks list while the Tasks tab is
active. It opens on today and steps through days with the same compact date
strip the planner header uses. It starts hidden as a slim rail, is brought up
via the rail's calendar button and resized by its edge; both survive restarts.

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
- **Opens on the calendar.** The Day timeline is the default view, plan or no
  plan: recorded time, imported workouts and events with a start and end sit on
  its recorded lane, and an event opens from its block. Agenda and Activity are
  a tap away.
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

## The week a recording belongs to

Weekly totals bucket each recorded entry by the wall clock of the device that
recorded it, so an hour worked at 9am in Tokyo counts to that Tokyo Monday on
every device the user owns — rather than shifting with whichever device happens
to be doing the summing.

The mechanism, the convergence argument it rests on, and how older registers are
migrated are in
[the coordination protocol concept](../../../knowledge/features/daily_os_next/coordination-protocol.md).

## Performance envelope

Daily OS carries deterministic offline regression gates and live model
evaluations so planning cost and quality remain visible as the feature evolves.
The authoritative performance contract, current baselines, commands, and live
Melious evidence are in
[day-planning evaluation and benchmarks](../../../knowledge/features/daily_os_next/evaluation.md).

## How it works

The runtime architecture — agent identities and the per-day cutover, the wake
prompt and its caching contract, the capture and planning tools, the durable
outbox, the coordinator protocol, dependency-aware planning, the UI surfaces and
the evaluation harness — is documented in the knowledge bundle:

**→ [knowledge/features/daily_os_next/](../../../knowledge/features/daily_os_next/)**
