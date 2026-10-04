# ADR 0122: A Category Move Is Finished After a Crash

- Status: Accepted
- Date: 2026-10-04

## Context

Every row carries its category, and a task's project must be in the task's
category: `ProjectRepository.linkTaskToProject` refuses a cross-category
link. `EntryController.updateCategoryId` moved a task in several writes. It
wrote the task, then each entry linked from it (timers, recordings, images,
linked tasks), and last unlinked the project of each moved task whose
project was in another category.

Two gaps remained:

- **A crash mid-move was never repaired.** An app that died between those
  writes left the task in its new category, its entries in the old one, and
  the task still linked to a project of the old category. Nothing finished
  the move: the cascade ran only in the controller's call.
- **A task's checklists stayed behind.** Checklists and their items are not
  linked from the task through `EntryLink`, so the cascade never moved them.
  A new item takes its checklist's category, so a moved task kept filing new
  items under the category it left.

We modelled the move in `specs/tla/TaskCategoryMove.tla`. With either fix
switched off, TLC breaks `Consistent`: once no move is in flight,
everything belonging to the task, and its project, is in the task's
category.

## Decision

- **The move lives in `EntryCategoryMove`.** The controller delegates to it,
  and the next start can run it. The order of the writes is unchanged, and
  the project link is still dropped last, after the categories.
- **A move is recorded before its first write.** `CategoryMoveIntents`
  writes a device-local settings row naming the entry and the category. The
  row is removed once the last write is done. A later move of the same entry
  replaces the row.
- **The next start finishes a recorded move while the entry holds its
  category.** `EntryCategoryMove.replay` runs as a tracked startup task. It
  skips every write that already landed. An entry that no longer holds the
  recorded category drops the record without writing: either the move never
  began, or a later move overtook it, here or on another device, and a
  replay must not undo that.
- **A task's checklists and their items follow it.** A checklist that
  another task also shows stays where it is, and so does an item that
  another task's checklist lists.
- **Only the entry's own write decides the result.** If it does not land,
  nothing else moves. A failure after it is logged and keeps the record for
  the next start.

## Consequences

- A crash during a move no longer leaves a task split across categories or
  linked to a project of another category.
- Moving a task now also writes its checklists and items, one sync message
  each.
- The settings database reaches Riverpod through `settingsDbProvider`,
  overridden in the composition root like the journal database.
- The task agent's category scope (`allowedCategoryIds`) still does not
  follow its task. That is a separate decision about which agent a moved
  task should have.
