import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:mocktail/mocktail.dart';

import '../classes/task_document_fixtures.dart';
import '../mocks/mocks.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  TaskDocumentVersionEntry version(
    String id, {
    required int number,
    String documentId = 'doc-1',
    int second = 0,
    bool deleted = false,
  }) {
    final entry = taskDocumentVersionEntry(
      id: id,
      number: number,
      documentId: documentId,
    );
    final at = taskDocFixtureEpoch.add(Duration(seconds: second));
    return entry.copyWith(
      meta: entry.meta.copyWith(
        createdAt: at,
        updatedAt: at,
        deletedAt: deleted ? at : null,
      ),
    );
  }

  group('JournalDb task document queries -', () {
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
    });

    test(
      "getTaskDocumentVersions returns only that document's live versions, "
      'newest first by number, then by when they were written',
      () async {
        for (final entry in [
          version('v1', number: 1),
          version('v3', number: 3),
          // Two v2s, written over v1 on two devices at once.
          version('v2-early', number: 2, second: 1),
          version('v2-late', number: 2, second: 5),
          version('v4-deleted', number: 4, deleted: true),
          version('other-doc', number: 9, documentId: 'doc-2'),
        ]) {
          await db!.updateJournalEntity(entry);
        }
        // The document itself is a different type and never listed.
        await db!.updateJournalEntity(
          taskDocumentEntry(clock: {'a': 1}, id: 'doc-1'),
        );

        final versions = await db!.getTaskDocumentVersions('doc-1');

        expect(versions.map((v) => v.id), ['v3', 'v2-late', 'v2-early', 'v1']);
      },
    );

    test('getTaskDocumentVersions is empty for a document with none', () async {
      expect(await db!.getTaskDocumentVersions('doc-1'), isEmpty);
    });
  });
}
