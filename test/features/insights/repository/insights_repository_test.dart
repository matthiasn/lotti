import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/repository/insights_repository.dart';
import 'package:lotti/get_it.dart';

void main() {
  late JournalDb db;
  late InsightsRepository repository;
  Directory? previousDirectory;

  setUp(() {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    } else {
      previousDirectory = null;
    }
    getIt.registerSingleton<Directory>(Directory.systemTemp);
    db = JournalDb(inMemoryDatabase: true);
    repository = InsightsRepository(db);
  });

  tearDown(() async {
    await db.close();
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
  });

  test('maps database records to InsightsTimeRow values', () async {
    await db.updateJournalEntity(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: DateTime(2024, 3, 1, 9),
          updatedAt: DateTime(2024, 3, 1, 9),
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 10, 30),
          categoryId: 'cat-1',
        ),
        entryText: const EntryText(plainText: 'work'),
      ),
    );

    final rows = await repository.fetchTimeRows(
      start: DateTime(2024, 3),
      end: DateTime(2024, 4),
    );

    expect(rows, [
      InsightsTimeRow(
        dateFrom: DateTime(2024, 3, 1, 9),
        dateTo: DateTime(2024, 3, 1, 10, 30),
        categoryId: 'cat-1',
      ),
    ]);
  });

  test('returns an empty list when the window has no entries', () async {
    final rows = await repository.fetchTimeRows(
      start: DateTime(2024, 3),
      end: DateTime(2024, 4),
    );
    expect(rows, isEmpty);
  });
}
