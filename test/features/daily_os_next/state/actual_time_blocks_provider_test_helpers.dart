import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

EntryLink hLink(
  String id, {
  required String from,
  required String to,
  required DateTime day,
  DateTime? deletedAt,
}) {
  return EntryLink.basic(
    id: id,
    fromId: from,
    toId: to,
    createdAt: day,
    updatedAt: day,
    vectorClock: null,
    deletedAt: deletedAt,
  );
}

JournalEntry hEntry({
  required String id,
  required DateTime day,
  required int startHour,
  required int endHour,
  String? text,
  String? categoryId,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: day,
          updatedAt: day,
          dateFrom: day.add(Duration(hours: startHour)),
          dateTo: day.add(Duration(hours: endHour)),
          categoryId: categoryId,
          deletedAt: deletedAt,
        ),
        entryText: text == null ? null : EntryText(plainText: text),
      )
      as JournalEntry;
}

Task hTask({
  required String id,
  required String title,
  required String categoryId,
  required DateTime day,
}) {
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: day,
          updatedAt: day,
          dateFrom: day,
          dateTo: day,
          categoryId: categoryId,
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: '$id-status',
            createdAt: day,
            utcOffset: 0,
          ),
          dateFrom: day,
          dateTo: day,
          statusHistory: const [],
          title: title,
        ),
      )
      as Task;
}

CategoryDefinition hCategory({
  required String id,
  required String name,
  required String color,
}) {
  final now = DateTime(2026, 5, 27);
  return CategoryDefinition(
    id: id,
    createdAt: now,
    updatedAt: now,
    name: name,
    vectorClock: null,
    private: false,
    active: true,
    color: color,
  );
}
