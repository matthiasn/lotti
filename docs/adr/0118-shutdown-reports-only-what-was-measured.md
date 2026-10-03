# ADR 0118: Shutdown Reports Only What Was Measured

- Status: Accepted — implemented
- Date: 2026-10-03

## Context

Daily OS Shutdown shipped as a prototype backed by the scripted `MockDayAgent`
in production code: fixed "completed" and "carryover" rows, invented metrics
(energy 7.4, context switches 5), a canned tomorrow note, and reflection and
carryover calls that waited and discarded what the user entered. The
`enable_daily_os_page` flag kept it from most users, but anyone who turned it on
saw a success state while nothing was saved. The design notes
(`docs/implementation_plans/2026-05-25_day_agent_next_phases_handover.md`)
described the intended backends; this ADR records the choices made building
them.

## Decision

1. **Report only measured facts; show a gap rather than invent one.** Focus,
   sessions and context switches come from recorded time — the same Actual-lane
   blocks as the Day timeline. Energy comes only from the session ratings'
   energy dimension. A day without ratings shows a dash, never a default.
   Heuristics that have no source elsewhere — what a flow session and a context
   switch are — are named constants with their definitions beside them.

2. **Carryover decisions write through triage.** *Tomorrow* and *Pick a date*
   set the task's due date; *Drop* rejects it, via `DayAgentTriageService`. A due
   date is exactly how a task reaches tomorrow's Reconcile and drafting, so no
   separate decision record is needed, and a decided task simply stops being
   "meant for the day".

3. **The reflection is a journal entry, one per day.** A deterministic id per
   day makes typed reflections from several devices land in one entry, which
   shows in the Logbook. A spoken reflection is a recording linked under it,
   using the standard recorder and its transcription.

4. **The tomorrow note is a one-shot completion, cached by its facts.** It is
   one paragraph written while the user is looking at the screen. A
   durable-outbox wake (ADR 0032) would run the full planner context, around
   10K tokens, for it. A single generation on the day agent's resolved model,
   recorded in the consumption ledger, is enough. It is stored as a synced
   `TomorrowNoteEntity` keyed by day, with a fingerprint of the facts it was
   written from. Reopening Shutdown reuses it, and only changed facts — after
   decisions, at *Close the day* — buy a new one. Tomorrow's week context reads
   it.

5. **The prototype mock leaves production.** `MockDayAgent` moves to `test/`,
   and the never-surfaced `surfaceTaskCorpus` tool and `ReflectionSource` are
   removed.

## Consequences

- Shutdown can be trusted: every row, number and decision is backed by data or
  says that it isn't.
- The card stays honest about AI: no configured profile is a typed failure the
  card turns into a set-up prompt.
- If the note ever needs to be written in the background, for example at day
  handover, it can become an outbox job kind. The entity and fingerprint carry
  over unchanged.

## Related

- [Daily OS Shutdown](../../knowledge/features/daily_os_next/shutdown.md)
- ADR 0032 — hierarchical day-agent coordination and the processing outbox.
