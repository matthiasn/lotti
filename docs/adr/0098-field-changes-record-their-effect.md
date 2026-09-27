# ADR 0098: Field Changes Record Their Effect on the Task

- Status: Accepted
- Date: 2026-09-27

## Context

[ADR 0075](./0075-idempotent-change-set-tools.md) made a confirmed change
item's effect idempotent across devices. A tool that creates an entity
derives the entity's id from the item's effect key. A tool that sets a task
field — title, status, priority, estimate, due date or language —
compares and sets: it applies only while the task still holds the value the
proposal was made against (`ChangeItem.base`). ADR 0075 left one residual
for the field tools: **a value compare-and-set cannot see an ABA.** If the
user puts the field back to the base after the change has landed, a later
application of the same change finds the base and applies the change again,
overwriting the user's decision.

In practice this needs the change to be applied twice: confirmed on two
devices before they sync, or reopened and confirmed again. TLC gives a
seven-step trace (`ChangeSetLifecycleRaceRestore` with `EffectMark = FALSE`):

1. Device 1 confirms the title change and applies it.
2. On device 1 the user sets the title back to what it was.
3. Device 2 receives that title, the newer version, before it receives the
   change set.
4. Device 2's change set still shows the item pending, so the user confirms
   it there.
5. Device 2's dispatch finds the base title and sets the proposed one again.

ADR 0075 said the residual violated `NoClobber` in 4 states. That trace was
different: confirm, the user writes the base value, dispatch. There the user
wrote the value the field already held, on a version that had never held the
change, and applying the change afterwards is the same as the serial order
"edit, then confirm". So this ADR states the property more precisely. A
dispatch clobbers the user if it writes over a value the user changed, or
over the base value the user wrote back **after seeing the change applied**:
a version whose vector clock covers one the dispatch wrote. The model tracks
the clocks of the dispatch's writes in a ghost (`appVcs`), independent of the
fix.

Two ways to see the second application were considered:

- **Compare a version, not a value.** Record the task's vector clock at
  proposal time and apply only while the task is at that version. This is too
  strict. The other items of the same set write the same task — a status
  change applied before the title change would make the title change stale —
  and so does every unrelated edit, such as a checklist added. The journal
  keeps no version per field.
- **Record the effect on the task.** Write the effect key into the task in
  the same write that sets the field. A second application of the same item
  finds its key and does nothing, whatever the field holds. The record is
  part of the version that carries the value, so it syncs with it: a device
  that has the restored value also has the record that the change landed.

## Decision

1. **`TaskData.appliedChangeEffects`** is a set of effect keys: the changes
   confirmed on this task that set one of its fields. It is optional, so
   existing tasks and older clients read it as empty.
2. **The dispatcher checks it before anything else.** For a field tool
   dispatched with an effect (`taskFieldSetBy`), `TaskToolDispatcher`
   returns success with nothing applied when the task already records the
   key (`ChangeEffect.recordedOn`). Otherwise it hands the handler the task
   with the key added (`ChangeEffect.recordOn`). Each field handler builds
   its write from the task it is given, so the key is written in the same
   version as the value, or not at all when the handler writes nothing. The
   value compare-and-set of ADR 0075 stays: it keeps a change from
   overwriting an edit made before the change landed anywhere.
3. **The record only grows.** Every write over a stored task keeps the stored
   keys and joins in the writer's (`TaskDataOnStored.onStored`, used by
   `PersistenceUpdateOps.updateTaskImpl` and
   `JournalRepository.updateJournalEntity`). This also covers a screen's copy
   read before the change was applied, just as those paths already keep the
   stored checklist list (ADR 0089). The common writer
   `PersistenceUpdates.updateJournalEntity` joins in the stored record for
   every task write that goes through it, such as a star or flag toggled from
   a screen's copy. Resolving a journal conflict keeps the records of both
   sides, whichever side's fields the user kept (`conflict_merge.dart`,
   `TaskDataOnStored.withEffectsOf`).
4. **Model.** `specs/tla/ChangeSetLifecycle.tla` gains the switch
   `EffectMark`. The field register carries the mark: a dispatch writes it
   with the value, and a user edit keeps the stored one. A dispatch applies
   only over the base and only when the mark is absent. The new configuration
   `ChangeSetLifecycleRaceRestore` (`UserRestoresBase = TRUE`) checks
   `NoClobber`, `Converged`, `EffectsConverge` and `TypeOK`. It passes with
   1,094,284 distinct states and fails in 7 states with `EffectMark = FALSE`.
   The eight other configurations keep their state counts.
5. **Conformance.** The dispatcher's real-database suite gains a generated
   trace for this ABA: one title change applied any number of times while
   the user edits the title and puts it back to the base. After every step
   the title must be what applying the change once, only over the base,
   leaves. The generated trace over all five tools now also includes putting
   the title or estimate back to the base.

## Consequences

- The ABA residual of ADR 0075 is closed for the six field tools:
  `ChangeSetLifecycleRaceRestore` holds `NoClobber`.
- **A reopened field item confirmed again does nothing once its change
  landed.** Before, confirming it again after the user had put the field
  back re-applied the change. Now the key is recorded, and the confirmation
  is a no-op that reports success, the way a reopened create-style item has
  behaved since ADR 0075, where a deleted entity counts as created. This is
  the choice that never overwrites what the user wrote. The item's key
  stays the same across every decision, so there is no way to tell a
  deliberate re-confirmation from a late replay. To apply the value again,
  the user edits the field or accepts a new proposal, which has a new key.
- **The record grows** by one key, about 40 bytes, for each field change
  applied to the task, and it is never pruned. A key can matter for as long
  as its item can be decided again, which has no bound.
- **Mixed versions.** A client older than this change ignores the record.
  Its dispatch does not check it, and when it rewrites a task it drops the
  unknown field, as it drops any field it does not know. A late application
  on such a client, or after such a rewrite, can still re-apply over a
  restored base.
- **Concurrent versions stay concurrent.** If the user's restore and the
  other device's application are concurrent, the journal keeps one of them
  as a `Conflict` row. The local version, and its record, stays. A
  restore made without having seen the change, as far as the clocks show,
  is not something the change overwrites (see Context).
- Out of scope, as in ADR 0075: label assignment, checklist item and time
  entry updates, and the project agent's tools. They carry no key or base.

## Related

- [ADR 0075](./0075-idempotent-change-set-tools.md) — the effect key and the
  value compare-and-set this builds on
- [ADR 0089](./0089-checklist-membership-on-the-stored-row.md) — writes
  built on the stored task row
- `specs/tla/ChangeSetLifecycle.tla`, `specs/tla/ChangeSetLifecycleRaceRestore.cfg`
- `lib/features/agents/tools/change_effect.dart`,
  `lib/features/agents/workflow/task_tool_dispatcher.dart`,
  `lib/classes/task.dart`
