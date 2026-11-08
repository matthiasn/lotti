# ADR 0160: A Task Asked For Aloud Is Made at Once

- Status: Accepted
- Date: 2026-11-08
- Concepts: [front agent](../../knowledge/features/front_agent.md#a-task-from-her-words)
- Amends: decision 1 of the [single-entry-point plan](../implementation_plans/2026-10-23_single_agent_entry_point.md) ("always confirm before filing")

## Context

Telling the front agent "make a task to fix the login bug, high priority,
due Friday, I started ten minutes ago" left an inbox item titled with every
word of it. The user then tapped *Make it a task*, opened a task named with
a sentence, and typed in again the priority, the due day, the category and
the timer they had just said. The point of talking to her was lost on the
second tap.

Decision 1 says nothing is filed without the user's tap, so that a wrong
guess about *where* words belong never writes. A request for a task is not
a guess. The user has said what to write.

## Decision

1. **The router reads the task from the words.** A `new` segment with
   `newKind: task` may carry a `task` object: title, instructions, category,
   priority, due day, estimate, and `startedMinutesAgo`. The model fills it.
   The code validates it leniently. A field it got wrong is left out and
   never fails the dispatch. A category stands only when the routing index
   lists it, and only among the chosen chips when the conversation is
   narrowed. The start is resolved to an instant against the routing turn's
   clock, which is the `<current_local_time>` the model saw.
2. **An instruction is the approval.** A `new` task segment whose intent is
   `instruction` ("create a task…", "I'm starting on…") is made by the
   walker at once. It is made under the id the inbox's *Make it a task*
   would use (`frontDoorTaskId`), so its card is the same *Made into a task*
   card with *Open* and *Undo*. A task only mentioned, a `statement`, still
   waits in the inbox. Its tap makes the same filled task.
3. **What creation writes.** The task carries the draft's fields. It is
   *in progress* when the draft has a start. The user's verbatim words are
   filed under it as a linked text entry: the provenance, and what its agent
   reads. A start opens a timer entry from that instant and runs the timer.
   The category's default agent is assigned (`autoAssignCategoryAgentWith`).
   *Undo* deletes the task and stops its running timer.
4. **Duplicates are routed, not created.** The prompt has her compare a new
   task with the open tasks in the index and `match_to_corpus`. When one
   looks like the same work she asks with `ask_user` and those tasks as the
   options.
5. **She says so.** Her one-line `reply_to_user` with the dispatch is spoken
   on a spoken turn, as every spoken reply is.

## Consequences

- No audio is linked. Her recorder transcribes and deletes the clip. Keeping
  recordings would make every question to her a stored, synced audio entry.
  That is a privacy decision for its own change.
- The extras after the task (words, timer, agent) run once, when the task is
  first written. A crash between them leaves a task without them, which the
  user fills on the page.
- A timer runs on the device that walks the turn. A recovery walk on
  another device writes the timer entry there.
