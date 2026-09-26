# ADR 0089: Checklist Membership Is Written on the Stored Row

- Status: Accepted
- Date: 2026-09-26

## Context

A task's checklists and a checklist's items are stored as whole id lists on
the parent: `TaskData.checklistIds` and `ChecklistData.linkedChecklistItems`.
Every reader resolves membership from those lists — the task page,
`ChecklistRepository.getChecklistItemsForTask`, the agent's context — so an
id missing from its parent's list is an item or a checklist nobody sees any
more, though its row is alive. Each item also names its checklist
(`ChecklistItemData.linkedChecklists`), which the agent's checklist tools
read to authorise an update.

Many writers replace those rows: the checklist and item screens
(`ChecklistController`, `ChecklistItemController`), `ChecklistsWidget`'s
reorder of a task's checklists, every task field edit (status, priority,
estimate, due date, title, cover art) that saves the whole `TaskData`, the
agent's task field and checklist item tools, and `ChecklistRepository`'s own
`createChecklist` and `addItemToChecklist`. Each built its row from a copy —
the screen's state, refreshed by an update notification some time after the
row changes, or a row read several awaits earlier — and wrote it under a
clock built on the row read just before the write. The write decision (ADR
0083) takes that clock as the newer version, so a row built on an older copy
silently replaced whatever was stored in between. And an operation that
writes several rows — create an item, then list it; move an item across
three rows; unlist a deleted item, then delete it when its undo window
closes — was left half done if the app died.

We modelled one device's membership in `specs/tla/ChecklistMembership.tla`
— the stored rows, the screens' copies and their refreshes, the screen's and
the agent's operations split at every await, versions landing by sync, and
the app dying mid-operation — and model-checked it. TLC found:

1. **An item dropped from its checklist** (`NoLostItem`, six steps): a
   checklist screen, or the agent's `addItemToChecklist`, writes the list it
   read plus its new item after another device's item synced in.
2. **A checklist dropped from its task** (`NoLostChecklist`, five steps): a
   checklist syncs in, and a task field edit — from the task screen's copy,
   or the agent's status tool writing the task it read — saves the old list.
3. **An item's back-link reverted** (`BackLinkAgrees`, eight steps): another
   device moves an item, and a check saved from the item screen's stale
   state writes the old checklist back.
4. **A checklist hidden from the task page** (`PageShowsChecklists`, eight
   steps): after a drag, `ChecklistsWidget` rendered its own order until the
   task changed, so a checklist added afterwards was not shown — and the next
   drag saved that order, dropping it.
5. **An operation left half done by a crash** (`NoLostItem`, five steps): the
   agent creates an item and the app dies before the checklist lists it.

## Decision

- **Rows are changed, not replaced.** A writer states its intent — add an
  id, remove one, show these in this order
  (`lib/features/tasks/model/membership_list.dart`), set these fields of an
  item — and the change is applied to the row as stored. `inVisibleOrder`
  keeps an id the screen never saw rather than dropping it.
- **The change is written on the stored row.** `writeOnStored`
  (`lib/logic/write_on_stored.dart`, extracted from the labels repository of
  ADR 0083) reads the row, builds the change on it, and writes it under a
  precondition — checked in the write's transaction — that the row is still
  the version read. A refused write is built again for as long as the row
  keeps moving; a refusal that finds the row unchanged was refused for
  another reason (a concurrent version from another device, which becomes a
  conflict for the user) and ends the attempt.
  `ChecklistRepository.updateChecklist`, `updateChecklistItem` and
  `updateTaskChecklistIds` take changes of the stored data;
  `updateTaskChecklistIds` is the one writer of a task's checklist list.
- **Other task writes keep the stored list.** `updateTaskImpl` writes on the
  stored task with the stored `checklistIds`, whatever the caller's
  `TaskData` holds. `JournalRepository.updateJournalEntity` — the agent's
  task field tools, which carry the caller's clock — takes the list from the
  stored row and writes under the same precondition. Conflict resolution
  (`ConflictResolutionService`) writes through `PersistenceLogic` directly
  and keeps the side the user chose.
- **Multi-row operations record their intent first.**
  `ChecklistMembershipIntents` saves one device-local settings row per
  operation before its first write and removes it after its last:
  listing new items, moving an item, deleting an item across its undo
  window, creating and deleting a checklist. At startup
  `ChecklistRepository.replayMembershipIntents` applies every intent left
  behind. Each is a set of idempotent changes to stored rows, so replaying an
  operation that did finish, or a replay that dies too, is harmless.
- **The task page follows the task.** `ChecklistsWidget` drops its dragged
  order when the task's list changes.

Each is a design switch in the spec (`RebaseLists`, `RebaseTask`,
`RebaseItems`, `IntentLog`, `WidgetFollowsTask`); turning one off reproduces
its counterexample.

## Consequences

- A membership write reports failure honestly: `updateChecklist`,
  `updateChecklistItem` return `null` and `updateTaskChecklistIds` `false`
  for a write the clock comparison refused, rather than success.
- An item deleted with a swipe is deleted. Before, the swiped row timed its
  undo window and cancelled the delete when it left the screen — which it
  does as soon as the item is unlisted — so swiped items stayed alive,
  unlisted, forever. The repository now times the window, and if the app
  dies during it, the next start completes the deletion the user last saw.
- An operation whose writes were refused or failed keeps its intent, and
  the next start finishes it; only a completed operation drops its intent.
- Two devices changing the same row concurrently still raise a conflict for
  the user (ADR 0083); membership is not merged across devices.
