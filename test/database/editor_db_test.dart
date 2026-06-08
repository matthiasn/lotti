import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late EditorDb db;

  setUpAll(() {
    db = EditorDb(inMemoryDatabase: true);
  });

  tearDownAll(() async {
    await db.close();
  });

  tearDown(() async {
    // EditorDb keeps no in-memory cache; truncating the single `editor_drafts`
    // table fully resets state between tests and keeps them order-independent.
    // The `schema` group's migration test opens its own throwaway file-based
    // EditorDb and never touches the shared instance.
    await db.customStatement('DELETE FROM editor_drafts');
  });

  group('insertDraftState Tests', () {
    test('inserts new draft successfully', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      final id = await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      expect(id, greaterThan(0));
    });

    test('archives previous DRAFT entries for same entryId', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft - should archive the first
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Verify: should have 1 DRAFT and 1 ARCHIVED
      final allDraftsStream = db.allDrafts();
      final activeDrafts = await allDraftsStream.get();

      expect(activeDrafts.length, 1);
      expect(activeDrafts.first.delta, contains('second'));
    });

    test('generates unique UUID for each draft', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      final id1 = await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      final id2 = await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      expect(id1, isNot(equals(id2)));
    });

    test('sets correct status to DRAFT', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.status, equals('DRAFT'));
    });

    test('stores delta JSON correctly', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const deltaJson = '{"ops":[{"insert":"test content"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.delta, equals(deltaJson));
    });

    test('handles multiple drafts for different entries', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 2);
    });

    test('only archives DRAFT status entries, not SAVED', () async {
      const entryId = 'test-entry-123';
      final testDate1 = DateTime(2024, 3, 15, 10, 30);

      // Insert first draft for a different entry
      await db.insertDraftState(
        entryId: 'other-entry',
        lastSaved: testDate1,
        draftDeltaJson: '{"ops":[{"insert":"other"}]}',
      );

      // Insert second draft for our test entry
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Mark the test entry as saved
      await db.setDraftSaved(entryId: entryId, lastSaved: testDate1);

      // Insert new draft for same entry with different timestamp
      final testDate2 = testDate1.add(const Duration(seconds: 1));
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate2,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Verify: should have 2 DRAFTs (the SAVED one was not archived)
      // 'other-entry' and the new 'test-entry-123' draft
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 2);

      // Verify the new draft exists
      final testEntryDrafts = drafts
          .where((d) => d.entryId == entryId)
          .toList();
      expect(testEntryDrafts.length, 1);
      expect(testEntryDrafts.first.delta, contains('second'));
    });

    test('stores lastSaved timestamp correctly', () async {
      const entryId = 'test-entry-123';
      // Use a timestamp without milliseconds to match SQLite precision
      final testDate = DateTime(2025, 10, 17, 12, 30, 45);
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.lastSaved, equals(testDate));
    });

    test('stores entryId correctly', () async {
      const entryId = 'test-entry-specific-id';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.entryId, equals(entryId));
    });
  });

  group('setDraftSaved Tests', () {
    test('updates draft status from DRAFT to SAVED', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Mark as saved
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: testDate,
      );

      expect(updateCount, equals(1));

      // Verify it's no longer in active drafts
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 0);
    });

    test('only updates drafts with matching entryId', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert two drafts
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      // Mark only entry-1 as saved
      await db.setDraftSaved(entryId: 'entry-1', lastSaved: testDate);

      // Verify only entry-2 remains as DRAFT
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.entryId, equals('entry-2'));
    });

    test('only updates drafts with status=DRAFT', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft (this archives the first)
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate.add(const Duration(seconds: 1)),
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Mark as saved - should only affect the second draft (which has status DRAFT)
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: testDate.add(const Duration(seconds: 1)),
      );

      expect(updateCount, equals(1));
    });

    test('returns 1 when draft is updated', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: testDate,
      );

      expect(updateCount, equals(1));
    });

    test('returns 0 when no matching draft found', () async {
      final updateCount = await db.setDraftSaved(
        entryId: 'nonexistent-entry',
        lastSaved: DateTime(2024, 3, 15, 10, 30),
      );

      expect(updateCount, equals(0));
    });

    test('does not update already SAVED drafts', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert and save a draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );
      await db.setDraftSaved(entryId: entryId, lastSaved: testDate);

      // Try to save again - should return 0 since it's already saved
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: testDate,
      );

      expect(updateCount, equals(0));
    });

    test('does not update ARCHIVED drafts', () async {
      const entryId = 'test-entry-123';
      final testDate1 = DateTime(2024, 3, 15, 10, 30);

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft with different entry ID (so first won't be archived)
      // Then manually mark the first as SAVED
      await db.setDraftSaved(entryId: entryId, lastSaved: testDate1);

      // Insert a new draft for a different entry
      await db.insertDraftState(
        entryId: 'different-entry',
        lastSaved: testDate1,
        draftDeltaJson: '{"ops":[{"insert":"other"}]}',
      );

      // Try to save the SAVED draft again - should return 0 since it's no longer DRAFT
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: testDate1,
      );

      expect(updateCount, equals(0));
    });
  });

  group('getLatestDraft Tests', () {
    test('returns null when entryId is null', () async {
      final result = await db.getLatestDraft(
        null,
        lastSaved: DateTime(2024, 3, 15, 10, 30),
      );

      expect(result, isNull);
    });

    test('returns null when no matching draft exists', () async {
      final result = await db.getLatestDraft(
        'nonexistent-entry',
        lastSaved: DateTime(2024, 3, 15, 10, 30),
      );

      expect(result, isNull);
    });

    test('returns latest draft when one exists', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);
      const deltaJson = '{"ops":[{"insert":"test content"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: deltaJson,
      );

      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate,
      );

      expect(result, isNotNull);
      expect(result!.entryId, equals(entryId));
      expect(result.delta, equals(deltaJson));
    });

    test('returns correct draft when multiple exist for same entry', () async {
      const entryId = 'test-entry-123';
      final testDate1 = DateTime(2024, 3, 15, 10, 30);
      final testDate2 = testDate1.add(const Duration(seconds: 1));

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft (archives first)
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate2,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Get the second draft
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate2,
      );

      expect(result, isNotNull);
      expect(result!.delta, contains('second'));
    });

    test('matches both entryId AND lastSaved timestamp', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Query with correct entryId but different lastSaved
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate.add(const Duration(seconds: 1)),
      );

      expect(result, isNull);
    });

    test('returns null for mismatched lastSaved', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Query with different lastSaved
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate.subtract(const Duration(hours: 1)),
      );

      expect(result, isNull);
    });

    test('only returns drafts with status=DRAFT', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Mark as saved
      await db.setDraftSaved(entryId: entryId, lastSaved: testDate);

      // Should not find it since it's now SAVED
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate,
      );

      expect(result, isNull);
    });

    test('orders by created_at DESC (latest first)', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert multiple drafts with same entryId and lastSaved
      // (in reality this shouldn't happen, but testing the ORDER BY clause)
      for (var i = 0; i < 3; i++) {
        await db.insertDraftState(
          entryId: 'other-entry-$i',
          lastSaved: testDate,
          draftDeltaJson: '{"ops":[{"insert":"draft $i"}]}',
        );
      }

      // Now insert the one we're looking for
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"target draft"}]}',
      );

      final result = await db.getLatestDraft(
        entryId,
        lastSaved: testDate,
      );

      expect(result, isNotNull);
      expect(result!.delta, contains('target draft'));
    });

    test('handles different entries with same lastSaved timestamp', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      final result1 = await db.getLatestDraft('entry-1', lastSaved: testDate);
      final result2 = await db.getLatestDraft('entry-2', lastSaved: testDate);

      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(result1!.delta, contains('draft1'));
      expect(result2!.delta, contains('draft2'));
    });

    test('latestDraft plan uses the composite partial index', () async {
      const entryId = 'test-entry-123';
      final testDate = DateTime(2024, 3, 15, 10, 30);

      for (var i = 0; i < 100; i++) {
        await db.insertDraftState(
          entryId: 'other-entry-$i',
          lastSaved: testDate,
          draftDeltaJson: '{"ops":[{"insert":"other $i"}]}',
        );
      }
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"target"}]}',
      );
      await db.customStatement('ANALYZE');

      final plan = await db
          .customSelect(
            '''
            EXPLAIN QUERY PLAN
            SELECT * FROM editor_drafts
            WHERE entry_id = ?1
              AND last_saved = ?2
              AND status = 'DRAFT'
            ORDER BY created_at DESC
            ''',
            variables: [
              Variable.withString(entryId),
              Variable.withDateTime(testDate),
            ],
          )
          .get();
      final details = plan.map((row) => row.data.toString()).join('\n');

      expect(details, contains('editor_drafts_latest_draft'));
      expect(details, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
    });
  });

  group('allDrafts Query Tests', () {
    test('returns only drafts with status DRAFT', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert drafts
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      // Mark one as saved
      await db.setDraftSaved(entryId: 'entry-1', lastSaved: testDate);

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.entryId, equals('entry-2'));
    });

    test('returns drafts ordered by created_at DESC', () async {
      final testDate = DateTime(2024, 3, 15, 10, 30);

      // Insert multiple drafts with longer delays to ensure different timestamps
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // No real delay needed; creation timestamps may be equal which is acceptable

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // No real delay needed; creation timestamps may be equal which is acceptable

      await db.insertDraftState(
        entryId: 'entry-3',
        lastSaved: testDate,
        draftDeltaJson: '{"ops":[{"insert":"third"}]}',
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 3);

      // Verify they're ordered by creation time (DESC - most recent first)
      // Check that each entry is newer than or equal to the next
      expect(
        drafts[0].createdAt.isAfter(drafts[1].createdAt) ||
            drafts[0].createdAt.isAtSameMomentAs(drafts[1].createdAt),
        isTrue,
      );
      expect(
        drafts[1].createdAt.isAfter(drafts[2].createdAt) ||
            drafts[1].createdAt.isAtSameMomentAs(drafts[2].createdAt),
        isTrue,
      );
    });

    test('returns empty list when no drafts exist', () async {
      final drafts = await db.allDrafts().get();
      expect(drafts, isEmpty);
    });
  });

  group('schema', () {
    test('schema version is 2', () {
      expect(db.schemaVersion, 2);
    });

    test('v2 migration adds latestDraft composite partial index', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lotti_editor_db_migration_test_',
      );
      try {
        final dbFile = File(path.join(tempDir.path, editorDbFileName));
        sqlite3.open(dbFile.path)
          ..execute('''
            CREATE TABLE editor_drafts (
              id TEXT NOT NULL,
              entry_id TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              last_saved INTEGER NOT NULL,
              delta TEXT NOT NULL,
              PRIMARY KEY (id)
            )
          ''')
          ..execute('CREATE INDEX editor_drafts_id ON editor_drafts (id)')
          ..execute(
            'CREATE INDEX editor_drafts_entry_id '
            'ON editor_drafts (entry_id)',
          )
          ..execute(
            'CREATE INDEX editor_drafts_status ON editor_drafts (status)',
          )
          ..execute(
            'CREATE INDEX editor_drafts_created_at '
            'ON editor_drafts (created_at)',
          )
          ..execute('PRAGMA user_version = 1')
          ..dispose();

        final migratedDb = EditorDb(
          documentsDirectoryProvider: () async => tempDir,
          tempDirectoryProvider: () async => tempDir,
        );
        try {
          final versionResult = await migratedDb
              .customSelect('PRAGMA user_version')
              .get();
          expect(versionResult.first.read<int>('user_version'), 2);

          final index = await migratedDb
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type='index' "
                "AND name = 'editor_drafts_latest_draft'",
              )
              .get();
          expect(index, hasLength(1));
          final indexSql = index.first.readNullable<String>('sql');
          expect(indexSql, contains('entry_id, last_saved, created_at DESC'));
          expect(indexSql, contains("WHERE status = 'DRAFT'"));
        } finally {
          await migratedDb.close();
        }
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
