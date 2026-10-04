# ADR 0121: A Confirmed Change Is Finished After a Crash

- Status: Accepted
- Date: 2026-10-04

## Context

Confirming a change item claims it — `pending` to `confirmed`, with its
decision, in one transaction — and then dispatches its tool
(`ChangeSetConfirmationService`). A create-style tool writes several rows:
`create_follow_up_task` writes the task, its link to the source task, the
source's project and the new task's agent; the project agent's `create_task`
writes the task, its project link and its agent; the event agent's
`suggest_follow_up_task` writes the task and its link to the event;
`create_time_entry` writes the entry and its link to the task. ADR 0075 made
each tool idempotent per item, so a second dispatch — another device's,
before the two synced — creates nothing twice.

Two gaps remained, and `ChangeSetConfirm`'s README named the first one as a
known residual:

- An app that died between the claim and the end of the dispatch left the
  item `confirmed` without its whole effect. Nothing applied it again: only
  a `pending` item can be confirmed, and the confirmation did not record
  that it was in flight.
- A dispatch that found its entity already there reported success and wrote
  nothing more. The other device's dispatch of an item whose first device
  died after the task therefore did not repair it either.

We modelled the dispatch in `specs/tla/ChangeDispatchRecovery.tla`. With
either fix switched off, TLC breaks `ConfirmedMeansComplete` — an item
shown confirmed, with nothing in flight, has its task, link, project and
agent — in five or six states.

## Decision

- **A dispatch is recorded before its claim.** `ChangeDispatchIntents`
  writes a device-local settings row naming the set and the item before the
  claim, and clears it once the outcome is written, or when the claim is
  lost. The record never syncs: another device that dispatches the item does
  so under its own claim.
- **The next start resumes what is still confirmed.** Agent initialization
  calls `resumeInterrupted` on the task, project and event agents'
  confirmation services, after the runtime is restored. A recorded dispatch
  whose item is still `confirmed` is dispatched again with the item's stored
  arguments and effect key; one whose item is `pending`, decided otherwise,
  or gone is dropped. A resume that fails keeps its record for the next
  start and does not hold the agents back.
- **A tool that finds its entity writes what is missing.** The follow-up
  task's link, project and agent; the project agent's task's project link
  and agent; the event follow-up's link to its event; the time entry's link.
  Each write is a no-op where it landed: a link takes its triple's derived
  id, and the project and agent are written only where there is none. A
  task filed in another project since, or deleted since, is left as it is.
- **A chat set's dispatch is not resumed.** It carries the approval the user
  gave in the chat, which only that confirmation can attach.

## Consequences

- A crash during a confirmation no longer leaves a follow-up task detached
  from its source or event, outside its project or without its agent, nor a
  time entry off its task; the next start finishes it, and so does the other
  device's dispatch.
- The confirmed-decision hook of a resumed dispatch does not run again: the
  decision was persisted with the claim, and the hook ran in the run that
  died, or not at all.
- The goal and relationship agents' confirmations record nothing. A goal
  revision writes its version and head in one transaction. A relationship
  task's dispatch links a task it finds, but that confirmation also mints an
  undo receipt and is not resumed: a crash between the task and its link
  leaves the task without its link to the person, and nothing repairs it yet.
