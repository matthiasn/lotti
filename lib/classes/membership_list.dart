/// Checklist membership: the id lists that order it — a task's
/// `TaskData.checklistIds` and a checklist's
/// `ChecklistData.linkedChecklistItems` — and the back-link that decides
/// which checklist an item is in (`ChecklistItemData.linkedChecklists`).
///
/// A list write applies one intent of the user or the agent to the list *as
/// it is stored*, rather than replacing it with a list a screen read earlier,
/// so a write never drops an id that another writer stored meanwhile
/// (`specs/tla/ChecklistMembership.tla`). Across devices each of these rows
/// is replaced whole by sync, so a checklist's list can lack an item or name
/// one twice with its neighbour; which items a checklist shows is therefore
/// read from the items' back-links, and the list only orders them
/// (`specs/tla/ChecklistReplication.tla`, ADR 0105).
library;

import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';

/// [ids] with [id] appended, unless it is listed already.
List<String> withMember(List<String> ids, String id) =>
    ids.contains(id) ? ids : [...ids, id];

/// [ids] without [id].
List<String> withoutMember(List<String> ids, String id) => [
  for (final other in ids)
    if (other != id) other,
];

/// [stored] in the order [visible] shows it.
///
/// An id [visible] lists that is no longer stored stays out, and a stored id
/// it does not list — stored after the screen last read the list — keeps its
/// place after the ordered ones rather than being dropped.
List<String> inVisibleOrder(List<String> stored, List<String> visible) {
  final storedIds = stored.toSet();
  final visibleIds = visible.toSet();
  return [
    ...visibleIds.where(storedIds.contains),
    ...stored.where((id) => !visibleIds.contains(id)),
  ];
}

/// Two versions of one membership list joined, as a conflict's resolution
/// writes it: [kept]'s order, then every id only [other] lists, in its
/// order. Whichever side the user keeps, an id either side listed stays, so
/// resolving a conflict never drops what the other device added.
List<String> joinMembers(List<String> kept, List<String> other) {
  final keptIds = kept.toSet();
  return [...kept, ...other.where((id) => !keptIds.contains(id))];
}

/// The checklist [item] is in: the first one its back-link names, or `null`
/// for an item that names none (written before back-links existed).
String? homeChecklistId(ChecklistItem item) =>
    item.data.linkedChecklists.firstOrNull;

/// Whether the checklist [checklistId] shows [item]: it is a live checklist
/// item naming that checklist — or naming none, when a list that holds it
/// decides.
bool isShownIn(JournalEntity? item, String checklistId) =>
    item is ChecklistItem &&
    !item.isDeleted &&
    (homeChecklistId(item) ?? checklistId) == checklistId;

/// Whether [checklist] shows [item] — as [shownItemIds] decides it, for a
/// reader holding one item: a live checklist, and a live item naming it, or
/// naming none and listed by it.
bool checklistShowsItem(Checklist checklist, JournalEntity? item) =>
    !checklist.isDeleted &&
    isShownIn(item, checklist.meta.id) &&
    (homeChecklistId(item! as ChecklistItem) != null ||
        checklist.data.linkedChecklistItems.contains(item.meta.id));

/// The ids of the items the checklist [checklistId] shows, in order.
///
/// [listed] is its stored list, which only orders; [items] maps ids to the
/// items read for it — those [listed] names and those whose back-link names
/// the checklist (`JournalDb.checklistItemsNaming`). An item is shown by the
/// checklist it names and by no other, so two checklists listing it (after
/// concurrent moves on two devices) show it once, and one whose listing has
/// not arrived, or was lost to a conflict, is shown all the same. Listed
/// items come first, in list order; the others follow, oldest first.
List<String> shownItemIds({
  required String checklistId,
  required List<String> listed,
  required Map<String, JournalEntity?> items,
}) {
  final listedIds = listed.toSet();
  final unlisted =
      items.values
          .whereType<ChecklistItem>()
          .where(
            (item) =>
                !listedIds.contains(item.meta.id) &&
                homeChecklistId(item) == checklistId &&
                !item.isDeleted,
          )
          .toList()
        ..sort((a, b) {
          final byDate = a.meta.dateFrom.compareTo(b.meta.dateFrom);
          return byDate != 0 ? byDate : a.meta.id.compareTo(b.meta.id);
        });
  return [
    for (final id in listedIds)
      if (isShownIn(items[id], checklistId)) id,
    for (final item in unlisted) item.meta.id,
  ];
}
