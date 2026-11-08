# ADR 0161: A Follow-up Names the Task It Follows

- Status: Accepted
- Date: 2026-11-08
- Concepts: [front agent](../../knowledge/features/front_agent.md#a-task-from-her-words)
- Builds on: [ADR 0160](0160-a-dictated-task-is-filled-from-the-words.md) (the dictated task), [ADR 0042](0042-typed-task-relationship-links.md) (the `followsUp` link)

## Context

After the front agent lists a task, the user says "create a follow-up to
that one, start a timer five minutes ago, high priority, due today". The
dictated task (ADR 0160) already read the priority, the due day and the
backdated start. It had no way to name the task it followed. "That one"
pointed at nothing she could read: the recent turns are six rows, each
clipped to 400 characters, so a task linked earlier or late in a long reply
fell out. A finished task, which is what a follow-up usually follows, is not
in the routing index at all.

## Decision

1. **The conversation's tasks are listed.** A `<conversation_tasks>` block
   after `<recent_turns>` lists up to eight tasks this conversation named,
   most recently named first: tasks linked in her words or the user's,
   offered in her questions, routed to, or made by the user's tap. Closed
   tasks are listed too. The list is built from the whole conversation, not
   the clipped tail, through the privacy-filtered journal read, inside the
   turn's category scope. It is not part of the routing index. The index
   stays byte-stable for the provider's prefix cache.
2. **The model resolves the reference, and the code checks it.** "That one",
   "it" and "the previous task" mean the first row. A description means the
   row whose title and one-liner fit. When two fit, or none does, she asks.
   The draft's `followsUpTaskId` stands only for a task in the index, a
   lookup result this turn, or the conversation's list. Any other id is
   dropped like any misread field, and the task itself is kept.
3. **A listed closed task is not a destination.** It may be followed up on
   and offered as an option, but nothing is routed to it.
4. **The tap writes the link before the agent.** The new task is linked
   `followsUp` to the task it follows. It takes that task's category when the
   words named none, so the category's agent is the one assigned. The agent
   comes last, because its creation wake runs at once (a title is content
   for the gate) and should see the link, the words and the timer.

## Consequences

- No schema change: the `followsUp` link type exists, and timer entries
  already start at any instant.
- Resolution is the model's, over a list the code orders and bounds. A wrong
  pick is visible in her reply, which names the followed task as a link
  before the tap.
- The project of the followed task is not inherited, unlike the task
  agent's follow-up tool. The user sets it on the task page.
- A task named only in another conversation is not in the list. Another
  chat is another subject (ADR 0154).
