import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

void main() {
  setUpAll(() async {
    await getIt.reset();
    registerFallbackValue(StackTrace.empty);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  group('JournalDb isolate-safe construction', () {
    late Directory documentsDirectory;
    late JournalDb db;
    final mockLoggingService = _MockLoggingService();

    setUp(() {
      documentsDirectory = Directory.systemTemp.createTempSync(
        'journaldb_actor_isolated_',
      );

      when(
        () => mockLoggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      db = JournalDb(
        inMemoryDatabase: true,
        documentsDirectory: documentsDirectory,
        loggingService: mockLoggingService,
      );
    });

    tearDown(() async {
      await db.close();

      if (documentsDirectory.existsSync()) {
        documentsDirectory.deleteSync(recursive: true);
      }
    });

    test(
      'updates journal entries and writes JSON without a global getIt directory',
      () async {
        final entry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'isolate-entry',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            starred: false,
            private: false,
          ),
          entryText: const EntryText(plainText: 'isolated write path'),
        );

        await initConfigFlags(db, inMemoryDatabase: true);
        final result = await db.updateJournalEntity(entry);

        final expectedPath = entityPath(entry, documentsDirectory);

        expect(result.applied, isTrue);
        expect(getIt.isRegistered<Directory>(), isFalse);
        expect(getIt.isRegistered<LoggingService>(), isFalse);
        expect(File(expectedPath).existsSync(), isTrue);
      },
    );
  });
}
