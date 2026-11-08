# ADR 0160: A Dictated Task Is Filled From the Words

- Status: Accepted
- Date: 2026-11-08
- Concepts: [front agent](../../knowledge/features/front_agent.md#a-task-from-her-words)
- Keeps: decision 1 of the [single-entry-point plan](../implementation_plans/2026-10-23_single_agent_entry_point.md) ("always confirm before filing")

## Context

Telling the front agent "make a task to recalibrate the hatchery heaters,
high priority, due Tuesday, I began ten minutes ago" left an inbox item
titled with every word of it. *Make it a task* made a task named after the
sentence, and the user typed the priority, the due day, the category and
the timer in again. The point of talking to her was lost on that second
pass.

The owner's rule still holds: nothing is created, and no timer started,
before the user confirms. The confirmation should be enough on its own,
with nothing to retype afterwards.

## Decision

1. **The router reads the task from the words.** A `new` segment with
   `newKind: task` may carry a `task` object: title, instructions, category,
   priority, due day, estimate, and `startedMinutesAgo`. The model fills it.
   The code validates it leniently. A field it got wrong is left out and
   never fails the dispatch. A category stands only when the routing index
   lists it, and only among the chosen chips when the conversation is
   narrowed. The start is resolved to an instant against the routing turn's
   clock, the `<current_local_time>` the model saw, so neither a slow
   inference nor a tap hours later moves it.
2. **The tap is still the approval.** Whether the user asked for the task
   or only mentioned it, the segment waits in the inbox with its draft on
   the door record. *Make it a task* makes it from the draft. A segment with
   no draft is still titled with the words.
3. **What the tap writes.** The task carries the draft's fields. It is
   *in progress* only when the user said the work began; otherwise it is
   open, with no timer. The user's verbatim words are filed under it as a
   linked text entry: the provenance, and what its agent reads. A start
   opens a timer entry from that instant and runs the timer. The category's
   default agent is assigned. *Undo* deletes the task and that copy of the
   words, and stops its running timer. The timer entry stays, because logged
   time outlives a deleted task.
4. **Duplicates are routed, not proposed.** The prompt has her compare a
   new task with the open tasks in the index, and `match_to_corpus` only
   when the index is truncated. When one looks like the same work she asks
   with `ask_user` and those tasks as the options.
5. **She says what she read.** Her one-line `reply_to_user` with the
   dispatch, spoken on a spoken turn, says the task is ready to confirm and
   what will start. She names it by its title, never as a link, because it
   has no id yet. She never says it was created.

## Consequences

- No audio is linked. Her recorder transcribes and deletes the clip. Keeping
  recordings would make every question to her a stored, synced audio entry.
  That is a privacy decision for its own change.
- Nothing she says confirms the creation itself. The card's *Made into a
  task* is the receipt.
- The extras after the task (words, timer, agent) run once, when the task is
  first written. A crash between them leaves a task without them.
- A timer runs on the device where the user tapped.
