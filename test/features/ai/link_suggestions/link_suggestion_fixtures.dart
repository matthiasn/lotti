import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

import '../../../helpers/entity_factories.dart';

/// A log entry of a task, written [minutesAfter] the fixed test date.
JournalEntry logEntry(
  String id,
  String text, {
  int minutesAfter = 0,
  DateTime? deletedAt,
}) {
  final at = testFixedDate.add(Duration(minutes: minutesAfter));
  return JournalEntry(
    meta: TestMetadataFactory.create(
      id: id,
      dateFrom: at,
    ).copyWith(deletedAt: deletedAt),
    entryText: EntryText(plainText: text),
  );
}

/// A task, open unless [closed].
Task linkTask(
  String id,
  String title, {
  String notes = '',
  bool closed = false,
  DateTime? deletedAt,
}) {
  final task = TestTaskFactory.create(
    id: id,
    title: title,
    plainText: notes,
    status: closed
        ? TaskStatus.done(
            id: 'done-$id',
            createdAt: testFixedDate,
            utcOffset: 0,
          )
        : null,
  );
  return task.copyWith(meta: task.meta.copyWith(deletedAt: deletedAt));
}

/// A live plain link from [fromId] to [toId].
EntryLink plainLink(String fromId, String toId, {bool hidden = false}) =>
    EntryLink.basic(
      id: '$fromId-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: testFixedDate,
      updatedAt: testFixedDate,
      vectorClock: null,
      hidden: hidden,
    );
