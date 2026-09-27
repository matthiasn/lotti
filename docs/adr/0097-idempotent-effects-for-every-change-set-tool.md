# ADR 0097: Idempotent Effects for Every Change-Set Tool

- Status: Accepted
- Date: 2026-09-27

## Context

[ADR 0075](./0075-idempotent-change-set-tools.md) made the effects of the
change-set tools idempotent across devices, so that a suggestion confirmed on
two devices before they sync changes the journal once. It covered the tools
that create entities and the tools that set a task field, and listed the rest
under its Consequences as not covered:

- `assign_task_label(s)` — "a set-add, so a late add can bring back a label
  removed in between";
- `update_checklist_item(s)` and `update_time_entry` — "record no base";
- the project agent's `create_task` and `update_project_status` — "keep
  random ids and no base". `create_task` was left out on purpose: its Undo
  deletes the created task, "and a derived id would need a re-confirm to bring
  the deleted task back".

Each of these applies twice when two devices confirm the same item: the
project agent creates two tasks; a late time-entry or checklist update
overwrites an edit the user made after the first application — the checklist
one even through the sovereignty guard, because the proposal carries the
reason that overrides it; a late status update overwrites a status the user
set since.

We extended `specs/tla/ChangeSetLifecycle.tla` with what was missing to
express these: the project agent's Undo (the confirmed entity deleted, the item
reopened), deletions syncing as tombstones, and a set-style item that adds a
label rather than set a field, with the user's removal as the edit. TLC found:

1. **A label the user took off could come back.** One device applies the
   label; the user takes it off; the other device, which had confirmed the
   same suggestion before they synced, receives the removal and applies its
   add (`NoClobber`, 7 states, with `RemoveWins = FALSE`).
2. **An Undo left its item unable to apply again.** With the task's id
   derived from the item, confirming after the Undo finds the undone task's
   tombstone and creates nothing: the item reads confirmed and the project
   has no task (`ConfirmedIsLive`, 6 states, with `UndoRekeys = FALSE`). The
   ADR 0075 key is "the same for every decision of the item", which is
   right for a reopen that leaves its effect standing and wrong for an Undo
   that takes it back.
3. **An Undo could undo a decision it did not make.** The project agent's
   Undo remembers, for the session, the task its own confirmation created.
   Two devices confirm the same item; one undoes it and confirms it again,
   creating the task anew under the new key; the other, whose memo names
   the first task, receives that later confirmation and undoes it — deleting
   the first task, already gone, and reopening the item under yet another
   key, whose confirmation creates a third task beside the second
   (`NoDuplicateEffects`, 12 states, `ChangeSetLifecycleRaceUndo` with
   `UndoOwnKey = FALSE`). The memo was keyed by the item's position, not by
   the decision.

Reading the label code against (1), the guard already exists:
`LabelsRepository.setLabels` — the only path that takes a label off a task —
adds it to the task's `aiSuppressedLabelIds`, and
`LabelAssignmentProcessor` reads that set fresh before it adds and skips a
suppressed label. A late add on a device that has received the removal
therefore adds nothing. The processor's comment called the read
"defense-in-depth"; it is the guard.

## Decision

1. **A set-add is guarded by the removal it could undo.** A label add applies
   only while the label is not suppressed on the task, and taking a label off
   suppresses it — the remove-wins set the model's `RemoveWins` checks. No
   base is needed; the processor's suppression read is documented as
   load-bearing, and a test proves a late add after a removal leaves the
   label off.
2. **A proposal that edits another entity records its base there.**
   `ChangeItem.targetBase` holds the fields the proposal changes, as the
   edited entity held them when it was proposed, keyed as the tool's
   arguments, next to ADR 0075's `base` for the task:
   - `update_checklist_item`: `title`, `isChecked` and `isArchived`, each
     with the stamp the item keeps of its last change — `titleSetAt`,
     `checkedAt`, `archivedSetAt` — under `title@`, `isChecked@` and
     `isArchived@`;
   - `update_time_entry`: `startTime`, `endTime` and `summary`, as the
     journal holds them;
   - `update_project_status`: the canonical status word, with the id of the
     status entry under `status@`.

   The task agent records it (`checklistItemBaseResolver`,
   `resolveTimeEntryFields`), the task's query chat records it from the
   context it loaded (the item data as stored, `timeEntryFields`), and the
   project agent from the status the wake read. The confirmation service
   hands it to the dispatch as `ChangeEffect.targetBase`; `TaskToolDispatcher`
   and `ProjectToolDispatcher` compare it with the entity before any handler
   runs, and a field that moved on is left alone with a successful "Nothing
   applied", as ADR 0075 does for task fields.
3. **A stamp closes the ABA where the entity keeps one.** A value
   compare-and-set cannot see the user restoring the base value (ADR 0075's
   residual, closed for task fields by
   [ADR 0098](./0098-field-changes-record-their-effect.md), which records the
   effect key on the task). A checklist item stamps `checkedAt` on every
   check or uncheck, `titleSetAt` on every rename and `archivedSetAt` on
   every archive or restore, and every project status change mints a
   new status entry id, so recording those makes a restored value a changed
   field. The commonest edit after an agent checks an item off — the user
   unchecking it — is exactly that ABA. A time entry keeps no such stamp and
   keeps the residual.
4. **Kept apart from `base`.** A build that predates this change compares
   every entry of `base` with the task and would take an entry it does not
   know as an edit, applying nothing; it drops the unknown `targetBase` field
   instead, and applies the change unconditionally, as before.
5. **The project agent's `create_task` derives its task id** from the item's
   effect key (`change-effect:<key>:task`), like `create_follow_up_task`, and
   does nothing when the task exists — written here, synced from the other
   device, or deleted since. A replay does not relink: the creator's project
   link is on its way, and a second link written concurrently would be a
   second row. A creation whose project link fails is rolled back, as
   before, and with a derived id that failure is non-retryable: a retry
   would find the rolled-back task's tombstone and create nothing, so the
   item is retracted rather than left pending forever.
6. **An Undo that takes the effect back gives the item a new key.**
   `ChangeSetConfirmationService.reopenItem` with a `revert` — the Undo of the
   project and relationship agents — writes the reopened item with
   `ChangeItemEffect.undoneIn`: `<key>/undone@<revision>`, from the key and
   the revision the Undo read, so two devices that undo the same decision
   agree. Confirming it again derives a new id and creates the task anew. A
   late application of the undone decision on a device that confirmed it
   before they synced still carries the old key and finds the tombstone once
   it has it. A refused revert restores the old key with the status. A plain
   reopen keeps the key, as ADR 0075 requires.
7. **An Undo names the decision it undoes.** `ProjectProposalService`
   remembers the effect key its confirmation claimed the item under — read
   from the stored set through `confirmItem(onClaimed:)`, not from the
   caller's snapshot, which may predate a rekey — offers
   the Undo only while the item still carries it, and passes it to
   `reopenItem`, which reopens nothing — and runs no revert — when the item
   shows another key: a later decision, synced from another device, whose
   task the memo does not name.
8. As before, the model gates the code. `ChangeSetLifecycle` gains the key
   generation of an item, deletions and their sync, `Undo`, and `AddStyle`
   for a label; the switches `RemoveWins`, `UndoRekeys` and `UndoOwnKey` are
   mutation points; `NoDuplicateEffects` counts entities that are not deleted, and
   `ConfirmedIsLive` is new. Three configurations are added:
   `ChangeSetLifecycleRaceAdd` (a label added on two devices and taken off),
   `ChangeSetLifecycleUndo` (confirm, Undo, confirm again) and
   `ChangeSetLifecycleRaceUndo` (an Undo under the race). The Glados
   trace over a real journal database applies eight confirmed items, the new
   ones included, any number of times with the user's edits in between, and a
   generated trace of confirms, Undos and reopens drives the real
   confirmation service against a fake journal.

## Consequences

- ADR 0075's per-tool list of tools that are not covered is closed: every
  change-set tool now has an idempotent effect or needs none (`link_task`,
  the relationship agent's `create_and_link_task`, the project agent's
  `recommend_next_steps`, which only records).
- A confirmed update that finds its entity moved on reports success and
  changes nothing, for checklist items, time entries and project statuses as
  for task fields: a user who edits the item and then confirms the older
  suggestion sees it confirmed and the item as they left it.
- A time entry restored to the proposal's base between the two applications
  gets the proposed value again — the ADR 0075 ABA, which ADR 0098 closed
  for task fields and this ADR for checklist items and project statuses.
  Recording the effect key on the entry, as ADR 0098 does on the task,
  would close it; left for a later change.
- A label add has no base: a label the user takes off and then re-adds by
  hand is unsuppressed, and a late add then finds it present and adds
  nothing. A label unsuppressed without being re-added (no UI does this
  today) could be added again by a late application.
- The project agent's `create_task` whose project link fails is retracted,
  not reverted to pending: the user cannot retry that suggestion, and the
  agent can propose it again.
- The Undo's key suffix grows with each Undo of the same item; an item is
  undone a handful of times at most.
- A device whose confirmation was superseded by a later one from another
  device no longer offers Undo for the item: the later decision's effect is
  not in its memo.
- A proposal made by a build that predates this change carries no
  `targetBase` and applies unconditionally, as it did.
- The project agent's `recommend_next_steps` rows turned into tasks by
  `ProjectRecommendationService.createTask` are not change items: they
  dispatch `create_task` without an effect key and keep random ids.
- ADR 0075's other residuals stand: both devices creating before either has
  the other's entity (one id, a `Conflict` row), and the status recording the
  dispatch rather than the effect.

## Related

- [ADR 0075: Idempotent change-set tools](./0075-idempotent-change-set-tools.md)
- [ADR 0067: Model-checked change-set lifecycle](./0067-model-checked-change-set-lifecycle.md)
- `specs/tla/ChangeSetLifecycle.tla`, `specs/tla/README.md`
- `lib/features/agents/tools/change_effect.dart`
- [Task agents](../../knowledge/features/agents/task-agents.md)
- [Project and event agents](../../knowledge/features/agents/project-and-event-agents.md)
