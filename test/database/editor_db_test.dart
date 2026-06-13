import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/editor_db.dart';

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
}
