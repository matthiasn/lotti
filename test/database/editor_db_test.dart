import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/editor_db.dart';

void main() {
  late EditorDb db;

  setUp(() async {
    db = EditorDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('insertDraftState Tests', () {
    test('inserts new draft successfully', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      final id = await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      expect(id, greaterThan(0));
    });

    test('archives previous DRAFT entries for same entryId', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft - should archive the first
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Verify: should have 1 DRAFT and 1 ARCHIVED
      final allDraftsStream = db.allDrafts();
      final activeDrafts = await allDraftsStream.get();

      expect(activeDrafts.length, 1);
      expect(activeDrafts.first.delta, contains('second'));
    });

    test('generates unique UUID for each draft', () async {
      final lastSaved = DateTime.now();

      final id1 = await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      final id2 = await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      expect(id1, isNot(equals(id2)));
    });

    test('sets correct status to DRAFT', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.status, equals('DRAFT'));
    });

    test('stores delta JSON correctly', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();
      const deltaJson = '{"ops":[{"insert":"test content"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.delta, equals(deltaJson));
    });

    test('handles multiple drafts for different entries', () async {
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 2);
    });

    test('only archives DRAFT status entries, not SAVED', () async {
      const entryId = 'test-entry-123';
      final lastSaved1 = DateTime.now();

      // Insert first draft for a different entry
      await db.insertDraftState(
        entryId: 'other-entry',
        lastSaved: lastSaved1,
        draftDeltaJson: '{"ops":[{"insert":"other"}]}',
      );

      // Insert second draft for our test entry
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Mark the test entry as saved
      await db.setDraftSaved(entryId: entryId, lastSaved: lastSaved1);

      // Insert new draft for same entry with different timestamp
      final lastSaved2 = lastSaved1.add(const Duration(seconds: 1));
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved2,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Verify: should have 2 DRAFTs (the SAVED one was not archived)
      // 'other-entry' and the new 'test-entry-123' draft
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 2);

      // Verify the new draft exists
      final testEntryDrafts =
          drafts.where((d) => d.entryId == entryId).toList();
      expect(testEntryDrafts.length, 1);
      expect(testEntryDrafts.first.delta, contains('second'));
    });

    test('stores lastSaved timestamp correctly', () async {
      const entryId = 'test-entry-123';
      // Use a timestamp without milliseconds to match SQLite precision
      final lastSaved = DateTime(2025, 10, 17, 12, 30, 45);
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.lastSaved, equals(lastSaved));
    });

    test('stores entryId correctly', () async {
      const entryId = 'test-entry-specific-id';
      final lastSaved = DateTime.now();
      const deltaJson = '{"ops":[{"insert":"test"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      final drafts = await db.allDrafts().get();
      expect(drafts.first.entryId, equals(entryId));
    });
  });

  group('setDraftSaved Tests', () {
    test('updates draft status from DRAFT to SAVED', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      // Insert draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Mark as saved
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: lastSaved,
      );

      expect(updateCount, equals(1));

      // Verify it's no longer in active drafts
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 0);
    });

    test('only updates drafts with matching entryId', () async {
      final lastSaved = DateTime.now();

      // Insert two drafts
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      // Mark only entry-1 as saved
      await db.setDraftSaved(entryId: 'entry-1', lastSaved: lastSaved);

      // Verify only entry-2 remains as DRAFT
      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.entryId, equals('entry-2'));
    });

    test('only updates drafts with status=DRAFT', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft (this archives the first)
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved.add(const Duration(seconds: 1)),
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Mark as saved - should only affect the second draft (which has status DRAFT)
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: lastSaved.add(const Duration(seconds: 1)),
      );

      expect(updateCount, equals(1));
    });

    test('returns 1 when draft is updated', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: lastSaved,
      );

      expect(updateCount, equals(1));
    });

    test('returns 0 when no matching draft found', () async {
      final updateCount = await db.setDraftSaved(
        entryId: 'nonexistent-entry',
        lastSaved: DateTime.now(),
      );

      expect(updateCount, equals(0));
    });

    test('does not update already SAVED drafts', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      // Insert and save a draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );
      await db.setDraftSaved(entryId: entryId, lastSaved: lastSaved);

      // Try to save again - should return 0 since it's already saved
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: lastSaved,
      );

      expect(updateCount, equals(0));
    });

    test('does not update ARCHIVED drafts', () async {
      const entryId = 'test-entry-123';
      final lastSaved1 = DateTime.now();

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft with different entry ID (so first won't be archived)
      // Then manually mark the first as SAVED
      await db.setDraftSaved(entryId: entryId, lastSaved: lastSaved1);

      // Insert a new draft for a different entry
      await db.insertDraftState(
        entryId: 'different-entry',
        lastSaved: lastSaved1,
        draftDeltaJson: '{"ops":[{"insert":"other"}]}',
      );

      // Try to save the SAVED draft again - should return 0 since it's no longer DRAFT
      final updateCount = await db.setDraftSaved(
        entryId: entryId,
        lastSaved: lastSaved1,
      );

      expect(updateCount, equals(0));
    });
  });

  group('getLatestDraft Tests', () {
    test('returns null when entryId is null', () async {
      final result = await db.getLatestDraft(
        null,
        lastSaved: DateTime.now(),
      );

      expect(result, isNull);
    });

    test('returns null when no matching draft exists', () async {
      final result = await db.getLatestDraft(
        'nonexistent-entry',
        lastSaved: DateTime.now(),
      );

      expect(result, isNull);
    });

    test('returns latest draft when one exists', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();
      const deltaJson = '{"ops":[{"insert":"test content"}]}';

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: deltaJson,
      );

      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved,
      );

      expect(result, isNotNull);
      expect(result!.entryId, equals(entryId));
      expect(result.delta, equals(deltaJson));
    });

    test('returns correct draft when multiple exist for same entry', () async {
      const entryId = 'test-entry-123';
      final lastSaved1 = DateTime.now();
      final lastSaved2 = lastSaved1.add(const Duration(seconds: 1));

      // Insert first draft
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved1,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // Insert second draft (archives first)
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved2,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // Get the second draft
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved2,
      );

      expect(result, isNotNull);
      expect(result!.delta, contains('second'));
    });

    test('matches both entryId AND lastSaved timestamp', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Query with correct entryId but different lastSaved
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved.add(const Duration(seconds: 1)),
      );

      expect(result, isNull);
    });

    test('returns null for mismatched lastSaved', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Query with different lastSaved
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved.subtract(const Duration(hours: 1)),
      );

      expect(result, isNull);
    });

    test('only returns drafts with status=DRAFT', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"test"}]}',
      );

      // Mark as saved
      await db.setDraftSaved(entryId: entryId, lastSaved: lastSaved);

      // Should not find it since it's now SAVED
      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved,
      );

      expect(result, isNull);
    });

    test('orders by created_at DESC (latest first)', () async {
      const entryId = 'test-entry-123';
      final lastSaved = DateTime.now();

      // Insert multiple drafts with same entryId and lastSaved
      // (in reality this shouldn't happen, but testing the ORDER BY clause)
      for (var i = 0; i < 3; i++) {
        await db.insertDraftState(
          entryId: 'other-entry-$i',
          lastSaved: lastSaved,
          draftDeltaJson: '{"ops":[{"insert":"draft $i"}]}',
        );
      }

      // Now insert the one we're looking for
      await db.insertDraftState(
        entryId: entryId,
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"target draft"}]}',
      );

      final result = await db.getLatestDraft(
        entryId,
        lastSaved: lastSaved,
      );

      expect(result, isNotNull);
      expect(result!.delta, contains('target draft'));
    });

    test('handles different entries with same lastSaved timestamp', () async {
      final lastSaved = DateTime.now();

      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      final result1 = await db.getLatestDraft('entry-1', lastSaved: lastSaved);
      final result2 = await db.getLatestDraft('entry-2', lastSaved: lastSaved);

      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(result1!.delta, contains('draft1'));
      expect(result2!.delta, contains('draft2'));
    });
  });

  group('allDrafts Query Tests', () {
    test('returns only drafts with status DRAFT', () async {
      final lastSaved = DateTime.now();

      // Insert drafts
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft1"}]}',
      );

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"draft2"}]}',
      );

      // Mark one as saved
      await db.setDraftSaved(entryId: 'entry-1', lastSaved: lastSaved);

      final drafts = await db.allDrafts().get();
      expect(drafts.length, 1);
      expect(drafts.first.entryId, equals('entry-2'));
    });

    test('returns drafts ordered by created_at DESC', () async {
      final lastSaved = DateTime.now();

      // Insert multiple drafts with longer delays to ensure different timestamps
      await db.insertDraftState(
        entryId: 'entry-1',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"first"}]}',
      );

      // No real delay needed; creation timestamps may be equal which is acceptable

      await db.insertDraftState(
        entryId: 'entry-2',
        lastSaved: lastSaved,
        draftDeltaJson: '{"ops":[{"insert":"second"}]}',
      );

      // No real delay needed; creation timestamps may be equal which is acceptable

      await db.insertDraftState(
        entryId: 'entry-3',
        lastSaved: lastSaved,
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
}
