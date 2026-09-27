# ADR 0105: A Checklist Shows the Items Naming It

- Status: Accepted
- Date: 2026-09-27

## Context

Checklist membership is held three times over, in three kinds of journal
row: a task lists its checklists (`TaskData.checklistIds`), a checklist lists
its items (`ChecklistData.linkedChecklistItems`), and each item names its
checklist (`ChecklistItemData.linkedChecklists`, its back-link). Every reader
resolved which items a checklist shows from the checklist's list.

ADR 0089 made one device write those rows on what is stored and finish an
operation it died in. Across devices each row is still replaced whole by
sync, one row at a time, in any order, and concurrent versions of one row
become a Conflict row the user resolves by keeping a side (ADR 0083).
`specs/tla/ChecklistReplication.tla` models two devices doing this — adds,
moves, checks and deletions of items, checklists added and deleted, task
edits, every row delivered on its own, conflicts resolved, an app dying
mid-operation — and TLC found that membership did not survive it:

1. **An item shown, and counted, twice** (`ShownOnce`). Moving an item writes
   its back-link, the target's list and the source's in turn; a device that
   receives the target's list first shows it in both. Two devices moving one
   item to different checklists leave both targets listing it for good. The
   migration handler's derived copy, created on two devices in the checklist
   each sees first, does the same.
2. **An item lost** (`NoLostItem`). Two devices add an item to one checklist;
   resolving its conflict keeps one side's list, and the other's item is
   listed nowhere. The same after a swipe-deletion meets a concurrent check
   and the user keeps the check.
3. **A checklist lost** (`NoLostChecklist`). A checklist added on one device
   while the task is edited on another: resolving the task's conflict keeps
   one side's `checklistIds`.
4. **A deleted checklist's items left alive** (`NoOrphanItem`). Deleting a
   checklist never touched its items; they stayed in the journal, search and
   the agent's crawl, naming a checklist nobody shows.

Relisting what a resolution revives, and cascading a deletion over the
checklist's list, both looked sufficient and were not: TLC found a relisting
that finds the id still listed writes nothing, and loses to an unlisting in
flight; and two concurrent deletions of one checklist merge into one side's
row, whose list lacks the other side's items.

## Decision

- **A checklist shows the live items whose back-link names it**
  (`homeChecklistId`: the first checklist `linkedChecklists` names). They are
  found by the back-link — `JournalDb.checklistItemsNaming`, served by the
  expression index `idx_journal_checklist_item_home` (schema v51) — and
  ordered by the checklist's list, the ones it does not list yet after, oldest
  first (`shownItemIds`, `readShownChecklistItems`). Every reader goes through
  it: the checklist screen, completion counts, `getChecklistItemsForTask`, the
  Plaza, the AI and agent contexts, the knowledge graph. An item names one
  checklist, so it is shown once; the lists only order. A move writes the
  back-link naming the target alone.
- **A resolved membership list keeps every id either side listed**
  (`joinMembers`, in `conflict_merge.dart`'s `_resolved`), the kept side's
  order first — for a task's checklists, and for a checklist's items, which
  older builds still read.
- **Keeping a checklist in a conflict writes it onto its task again**, in a
  new version even when the task lists it (`resolveConflict`,
  `updateTaskChecklistIds(restate:)`). An unlisting this device has not
  received yet then meets it as a concurrent version — a conflict whose join
  keeps it — instead of silently replacing it.
- **Deleting a checklist unlists it from its task first, then deletes it, then
  its items.** A device can keep the checklist only after seeing its
  deletion, so the unlisting always precedes the relisting.
- **A checklist's items go with it.** The deletion deletes every live item
  naming it, found by the back-link, not by its list. So does a resolution
  that keeps a checklist's deletion, listing an item on a checklist deleted
  meanwhile, and — since the item's version and the deletion arrive in either
  order — the sync processor after it applies either one
  (`settleReceived`). Each is recorded as a membership intent first.
- **A replay does not repeat a write of its own that landed.** A move and the
  two deletions record this device's counter on the row that decides them
  (`mark`); a replay that finds it has moved on skips that write, because a
  later version there is another device's choice.

Each is a design switch in the spec (`ItemsByHome`, `JoinOnResolve`,
`RelistOnResolve`, `UnlistFirst`, `Cascade`, `ReplayGuard`); turning one off
reproduces its counterexample (`specs/tla/README.md`).

## Consequences

- Deleting a checklist deletes its items, on every device, including an item
  another device added or moved into it concurrently. Keeping an item's edit
  in a delete-versus-edit conflict whose checklist is gone does not bring it
  back: the item goes with its checklist.
- Keeping a checklist when resolving its deletion brings it back with the
  items added since; the items it held when it was deleted stay deleted.
- A resolved list can name a deleted checklist again (the kept side had
  unlisted it). Readers already skip a deleted checklist.
- An expression index is new to this schema: v51 builds it at upgrade. It
  covers only rows holding valid JSON, since `json_extract` raises on anything
  else, and the query repeats that condition.
- Mixed builds: a build without this change still reads the lists. It
  shows a moved item in the target once the source's unlisting arrives, as
  before, and cannot lose what the join keeps; it does not delete a deleted
  checklist's items itself, but deletes them when their deletions arrive.
