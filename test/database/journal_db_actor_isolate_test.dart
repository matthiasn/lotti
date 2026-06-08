import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Stubs the standard `log`/`error` calls on a [MockDomainLogger] so the DB
/// can write through it without throwing on un-stubbed invocations.
void _stubDomainLogger(MockDomainLogger mock) {
  when(
    () => mock.log(
      any<LogDomain>(),
      any<String>(),
      subDomain: any<String?>(named: 'subDomain'),
    ),
  ).thenAnswer((_) async {});

  when(
    () => mock.error(
      any<LogDomain>(),
      any<Object>(),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
      subDomain: any<String?>(named: 'subDomain'),
    ),
  ).thenAnswer((_) async {});
}

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
    final mockLoggingService = MockDomainLogger();

    setUp(() {
      documentsDirectory = Directory.systemTemp.createTempSync(
        'journaldb_actor_isolated_',
      );

      _stubDomainLogger(mockLoggingService);

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
        expect(getIt.isRegistered<DomainLogger>(), isFalse);
        expect(File(expectedPath).existsSync(), isTrue);
      },
    );
  });
}
