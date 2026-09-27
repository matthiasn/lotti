import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/model/membership_list.dart';

/// How many ids one bulk read binds, well below SQLite's variable cap.
const _chunk = 500;

/// The items each of [checklists] shows, in order, keyed by checklist id —
/// the one way every reader resolves a checklist's items (ADR 0105).
///
/// An item is shown by the checklist its back-link names
/// ([homeChecklistId]), found through `JournalDb.checklistItemsNaming`, and
/// ordered by that checklist's list ([shownItemIds]). So an item two
/// checklists list — after concurrent moves on two devices, or while a move
/// is half delivered — is shown once, and one no list holds yet is shown
/// all the same. A deleted checklist shows nothing. A listed row that
/// cannot be read is reported to [onUnreadable] and skipped, so one corrupt
/// row does not hide the rest.
Future<Map<String, List<ChecklistItem>>> readShownChecklistItems(
  JournalDb db,
  Iterable<Checklist> checklists, {
  void Function(Object error, StackTrace stackTrace)? onUnreadable,
}) async {
  final live = [
    for (final checklist in checklists)
      if (!checklist.isDeleted) checklist,
  ];
  if (live.isEmpty) return const {};
  final listedIds = {
    for (final checklist in live) ...checklist.data.linkedChecklistItems,
  }.toList();
  final items = <String, JournalEntity?>{};
  for (var i = 0; i < listedIds.length; i += _chunk) {
    final end = (i + _chunk).clamp(0, listedIds.length);
    for (final row
        in await db
            .journalEntitiesByIdsUnorderedAllPrivate(listedIds.sublist(i, end))
            .get()) {
      try {
        items[row.id] = fromDbEntity(row);
      } catch (error, stackTrace) {
        onUnreadable?.call(error, stackTrace);
      }
    }
  }
  for (final item in await db.checklistItemsNaming([
    for (final checklist in live) checklist.meta.id,
  ])) {
    items[item.meta.id] = item;
  }
  return {
    for (final checklist in live)
      checklist.meta.id: [
        for (final id in shownItemIds(
          checklistId: checklist.meta.id,
          listed: checklist.data.linkedChecklistItems,
          items: items,
        ))
          items[id]! as ChecklistItem,
      ],
  };
}
