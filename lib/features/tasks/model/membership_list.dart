/// Changes to the id lists that hold checklist membership — a task's
/// `TaskData.checklistIds` and a checklist's
/// `ChecklistData.linkedChecklistItems`.
///
/// Each applies one intent of the user or the agent to the list *as it is
/// stored*, rather than replacing it with a list a screen read earlier, so a
/// write never drops an id that another writer stored meanwhile
/// (`specs/tla/ChecklistMembership.tla`).
library;

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
