import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

final testTextEntry = JournalEntry(
  meta: Metadata(
    id: '32ea936e-dfc6-43bd-8722-d816c35eb489',
    createdAt: DateTime(2022, 7, 7, 13),
    dateFrom: DateTime(2022, 7, 7, 13),
    dateTo: DateTime(2022, 7, 7, 14),
    updatedAt: DateTime(2022, 7, 7, 13),
    starred: true,
  ),
  entryText: EntryText(plainText: 'test entry text'),
);

final testTask = Task(
  data: TaskData(
    status: TaskStatus.open(
      id: 'status_id',
      createdAt: DateTime(2022, 7, 7, 11),
      utcOffset: 60,
    ),
    title: 'Add tests for journal page',
    statusHistory: [],
    dateTo: DateTime(2022, 7, 7, 11),
    dateFrom: DateTime(2022, 7, 7, 9),
    estimate: const Duration(hours: 3),
  ),
  meta: Metadata(
    id: '79ef5021-12df-4651-ac6e-c9a5b58a859c',
    createdAt: DateTime(2022, 7, 7, 9),
    dateFrom: DateTime(2022, 7, 7, 9),
    dateTo: DateTime(2022, 7, 7, 11),
    updatedAt: DateTime(2022, 7, 7, 11),
    starred: true,
  ),
  entryText: EntryText(plainText: '- test task text'),
);
