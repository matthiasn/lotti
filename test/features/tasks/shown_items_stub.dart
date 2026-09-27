import 'package:collection/collection.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// Stubs the two reads behind `readShownChecklistItems` on [db] — the
/// listed items by id, and the items naming a checklist — for a test whose
/// checklists are mocked.
///
/// A listed id resolves to what `db.journalEntityById` returns for it when
/// that is a checklist item; otherwise to a live item naming the checklist
/// [homeOf] gives for it, or else the first of [checklists] that lists it.
/// So a checklist shows its list as stored, unless a test says an item
/// names another checklist. No unlisted item names any checklist.
void stubListedItemsNameTheirChecklist(
  MockJournalDb db,
  Iterable<Checklist> Function() checklists, {
  String? Function(String itemId)? homeOf,
}) {
  when(() => db.journalEntitiesByIdsUnorderedAllPrivate(any())).thenAnswer((
    invocation,
  ) {
    final ids = invocation.positionalArguments.first as List<String>;
    return MockSelectable<JournalDbEntity>.lazy(() async {
      final rows = <JournalDbEntity>[];
      for (final id in ids) {
        final stored = await db.journalEntityById(id);
        if (stored is ChecklistItem) {
          if (!stored.isDeleted) rows.add(toDbEntity(stored));
          continue;
        }
        final home =
            homeOf?.call(id) ??
            checklists()
                .firstWhereOrNull(
                  (checklist) =>
                      checklist.data.linkedChecklistItems.contains(id),
                )
                ?.meta
                .id;
        if (home != null) rows.add(toDbEntity(listedItem(id, home)));
      }
      return rows;
    });
  });
  when(() => db.checklistItemsNaming(any())).thenAnswer((_) async => []);
}

/// Stubs the two reads behind `readShownChecklistItems` on [db] from
/// [rows], the entries a test holds by id: live rows by id, and the live
/// items whose back-link names a checklist.
void stubShownChecklistReads(
  MockJournalDb db,
  Map<String, JournalEntity> Function() rows,
) {
  when(() => db.journalEntitiesByIdsUnorderedAllPrivate(any())).thenAnswer(
    (invocation) => MockSelectable<JournalDbEntity>.lazy(
      () async => [
        for (final id in invocation.positionalArguments.first as List<String>)
          if (rows()[id] case final row? when !row.isDeleted) toDbEntity(row),
      ],
    ),
  );
  when(() => db.checklistItemsNaming(any())).thenAnswer((invocation) async {
    final checklistIds =
        (invocation.positionalArguments.first as Iterable<String>).toSet();
    return [
      for (final row in rows().values)
        if (row is ChecklistItem &&
            !row.isDeleted &&
            checklistIds.contains(row.data.linkedChecklists.firstOrNull))
          row,
    ];
  });
}

/// A live item [id] naming the checklist [checklistId].
ChecklistItem listedItem(String id, String checklistId) => ChecklistItem(
  meta: Metadata(
    id: id,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    dateFrom: DateTime(2025),
    dateTo: DateTime(2025),
  ),
  data: ChecklistItemData(
    title: id,
    isChecked: false,
    linkedChecklists: [checklistId],
  ),
);
