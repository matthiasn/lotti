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

## The week a recording belongs to

Weekly totals bucket each recorded entry by **the wall clock of the device that
recorded it** — the UTC offset stamped on the entry at creation — not by the
zone of whichever device is reading. An hour worked at 9am in Tokyo counts to
that Tokyo Monday on every device the user owns.

The rule exists because these totals are a shared, synced register. Bucketing in
the reading device's zone meant a laptop and a phone in different zones computed
different totals for the same past week and overwrote each other indefinitely —
historical numbers that changed on their own. Bucketing by the recording zone is
a property of the data, so every device derives the same answer.

Entries written before the app stamped an offset have no recording zone to
honour and fall back to the reading device's. Weekly registers written under the
old rule are rewritten as their week comes back into the recompute window;
older ones keep their legacy values and are flagged as such in the store.

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
