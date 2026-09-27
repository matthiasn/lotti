# ADR 0103: Task Fields Are Changed on the Stored Row

- Status: Accepted
- Date: 2026-09-27

## Context

[ADR 0089](./0089-checklist-membership-on-the-stored-row.md) moved checklist
membership onto the stored row: a writer states its change, and
`writeOnStored` applies it to the row as stored, under a precondition that
the row is still the version read. It left the task's other fields as they
were. `PersistenceUpdateOps.updateTaskImpl` wrote on the stored task, but
took the caller's whole `TaskData` — only `checklistIds` and the applied
change effects (ADR 0098) came from the stored row. Every caller built that
`TaskData` from a copy: the task screen's `EntryController` state, refreshed
by an update notification some time after the row changes, for the status,
priority, language, cover art, title, estimate and due date. The agent's
field tools and the AI function handlers — status, title, language,
priority, estimate, due date — and the day agent's triage wrote the task
their call began with through `JournalRepository.updateJournalEntity`, under
a clock built on that copy's.

Either way the clock claims every version stored so far, so the write
decision (ADR 0083) keeps the write as the newer version, and whatever its
copy predated is silently put back — no conflict is raised, because by the
clock there is nothing to conflict with. The status history had its own
gaps: a status set from the task screen was never appended to
`statusHistory` (the agent's tool and the triage did append), and resolving
a conflict kept one side's `TaskData`, its history included.

We modelled one task's fields on two devices in
`specs/tla/TaskFieldWrites.tla` — the screen's and the agent's copies, their
writes, versions landing from the other device, conflicts and their
resolution — with a ghost per field of the writes its value derives from,
and model-checked it. TLC found:

1. **A field the agent set, put back by the screen** (`NoLostFieldEdit`, six
   states): the agent sets the status, then the user sets the priority on
   the screen, whose copy predates the agent's write — the status goes back.
   A version synced in from another device before the screen refreshed is
   lost the same way.
2. **A field the user set, put back by the agent** (`NoLostFieldEdit`, five
   states): the agent's tool reads the task, the user sets the status, the
   tool sets the priority — its copy's clock plus this device's next counter
   is newer, and the status goes back.
3. **The agent overwriting a value it never saw** (`NoBlindAgentWrite`, five
   states): ADR 0075's compare-and-set compares against the task the tool
   call read, not the stored row, so a status the user sets between the
   call's read and its write is overwritten.
4. **A status missing from the history** (`HistoryComplete`, four states):
   the user sets a status on the task screen.
5. **A resolution dropping a status from the history** (`HistoryComplete`,
   seven states): both devices set a status, and the user keeps the other
   device's side of the conflict.

## Decision

- **A task write is a change of the stored data.**
  `PersistenceLogic.updateTask` takes `change: TaskData Function(TaskData
  stored)` instead of a `TaskData`, and returns the task as stored
  afterwards. `updateTaskImpl` applies it to the stored data with
  `writeOnStored` — rebuilt on the new row whenever one landed between its
  read and its write — and skips the write when nothing changes. Each writer
  sets only the fields it sets: `EntryController.save` the title, estimate
  and due date it was given, and the body only while the editor holds
  unsaved edits; the status, priority, language and cover-art writers one
  field each.
- **An agent tool compares on the stored row, inside the write.**
  `writeTaskField` (`lib/features/tasks/repository/task_field_write.dart`)
  applies a tool's change only while its field on the stored row still reads
  what the tool's copy read, in the same transaction as the write, and joins
  the effect keys its copy records (ADR 0098). A moved field is reported as
  nothing applied — the newer value stands — which is how the dispatcher
  already reports a change whose base moved (ADR 0075). Every field tool
  and handler, the AI tool processor's language write, and the day agent's
  triage write through it or through `updateTask`. The triage compares no
  field — it acts on the task it just read, at the user's request — but it
  may only touch tasks in its planner's categories, so it passes that
  condition as `onlyIf`, which `updateTask` asks of the stored task inside
  the same write: a task moved out of scope since the read is left alone.
- **Every status is recorded.** `TaskData.withStatus` sets a status and
  appends it to `statusHistory` when it changes the status, and every status
  writer uses it: the task screen, the agent's status tool, the triage.
- **A resolution keeps both histories.** `conflict_merge.dart` joins both
  sides' `statusHistory` by status id, in the order the statuses were set
  (`TaskDataOnStored.withHistoryOf`), alongside the applied effects, whichever
  side's fields the user keeps.

Each is a design switch in the spec (`UiOnStored`, `AgentOnStored`,
`AgentCas`, `UiRecordsStatus`, `ResolveJoinsHistory`); turning one off
reproduces its counterexample. The conformance trace
(`test/features/tasks/repository/task_field_writes_model_conformance.dart`)
drives the real writers, tools and resolution over a real journal database
and pins the shortest trace each fix answers.

## Consequences

- A field written from a screen or by a tool never puts back a field it did
  not set. Setting the same field twice still keeps the newest write: the
  user's explicit choice is the newest, whatever the screen showed.
- An agent tool that finds its field moved reports that nothing was applied,
  and takes the stored task as its own for the rest of the run.
- A status set from the task screen now appears in the status history, which
  the task agent's report policy and the wake charts read.
- Two devices writing before they sync still raise a conflict the user
  resolves by keeping a side; merging status, priority, estimate or due date
  field by field on the conflict screen is not part of this decision.
- `updateTask` reports a failed write as `null`; before, an exception inside
  it was logged and reported as success.
