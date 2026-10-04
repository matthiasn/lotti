# ADR 0119: Every Task Write Is a Change of the Stored Row

- Status: Accepted
- Date: 2026-10-04

## Context

[ADR 0089](./0089-checklist-membership-on-the-stored-row.md) put checklist
membership on the stored row, and
[ADR 0103](./0103-task-fields-are-changed-on-the-stored-row.md) did the same
for a task's fields: a writer states its change, and `writeOnStored` applies
it to the row as stored, under a precondition that the row is still the
version read. Both left the writers that set none of those fields but still
write the task row:

- the star, flag and private toggles (`EntryController`), through
  `PersistenceLogic.updateJournalEntity` — which kept the stored labels,
  agent effects and pull request tracking, but took every task field and the
  checklist list from the row the toggle had read;
- the category and date changes (`JournalRepository.updateCategoryId`,
  `updateJournalEntityDate`);
- the geolocation added after an entry is created (`GeolocationService`),
  which reads the row only once the location fix arrives — exactly when a new
  task's checklist, title and labels are being written;
- the agent's label assignment (`LabelsRepository.addLabels`).

Each read the task, awaited further work, and wrote the whole row back with
no precondition. Its clock — the copy's, plus this device's next counter —
claims every version stored so far, so a write that landed in between (the
agent's status tool, `createChecklist` listing a checklist) is silently put
back. A version synced in during that window raises a conflict with a version
that never saw it.

The conflict screen had the same shape over a longer window. It reads this
device's side when it opens and builds the resolution from that pair, under
the join of both clocks plus this device's next counter. A version stored
while the user decides — the task agent setting a field — is replaced, and
the conflict screen never showed it.

We extended both models. `ChecklistMembership.tla` gained a task write that
sets no field (`MetaEdit`, run by the screen and by the agent);
`TaskFieldWrites.tla` gained that writer (`MetaDevices`) and a conflict
screen that resolves against the side it read when it opened (`StalePages`).
TLC found:

1. **A checklist dropped from its task by a label assignment**
   (`NoLostChecklist`, five states): the agent's label write reads the task,
   a checklist is listed on it, and the write puts the old list back.
2. **A status put back by a metadata write** (`NoLostFieldEdit`, five
   states): a toggle reads the task, a status is set, and the toggle writes
   its copy.
3. **A field put back by a resolution** (`NoLostFieldEdit`, ten states): the
   conflict screen opens, the agent sets the priority, and the user keeps a
   side — the priority goes back.

## Decision

- **Every write of a task row is a change of the stored entry.**
  `PersistenceLogic.updateEntity(id, change)` hands `change` the entry as
  stored and writes what it answers with `writeOnStored`; `null` means there
  is nothing to write. The toggles, the category and date changes and the
  geolocation write through it, and `LabelsRepository.addLabels` through its
  own `writeOnStored`, as `setLabels` already did. A task's own fields still
  go through `updateTask` (ADR 0103).
- **A resolution applies only over the side the user was shown.**
  `ConflictResolutionService` writes under a precondition, checked in the
  write's transaction, that the stored row — read with its soft deletion, as
  the screen read it — is still the local side of the pair. Refused, it
  answers false; the conflict screen reads the local side again, shows the
  difference as it now is, and says so ("The entry changed meanwhile").
- **`GeolocationService` no longer reads or writes the entry.** It fixes the
  location and hands `updateEntity` the change; it set geolocation once and
  never overwrites it, now judged on the row as stored.

The fixes are design switches (`MetaOnStored` in both specs,
`ResolveOnStored` in `TaskFieldWrites`); turning one off reproduces its
counterexample. The conformance traces drive the real writers over a real
journal database, with a status or a new checklist landing inside each
writer's read and write, and fail with either fix reverted.

## Consequences

- No local write of a task row puts back a field, a checklist or a label
  another writer stored meanwhile; a version synced in meanwhile is built on
  rather than raising a conflict.
- A toggle flips the flag as stored, not as the screen showed it. Two taps
  racing each other land as two flips.
- A conflict the user resolves on a stale screen is not applied; they decide
  again on the current difference. The screen does not yet follow the stored
  row while it is open.
- The category change still writes the task and then each linked entry, and
  the privacy toggle still unlinks a mismatched project in a second write. A
  crash between them is not repaired; that is a separate decision.
