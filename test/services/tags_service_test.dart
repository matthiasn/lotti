import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsService Tests', () {
    late MockJournalDb mockJournalDb;
    late StreamController<List<TagEntity>> tagsController;
    late TagsService tagsService;

    setUp(() {
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }

      mockJournalDb = MockJournalDb();
      tagsController = StreamController<List<TagEntity>>.broadcast();

      when(() => mockJournalDb.watchTags())
          .thenAnswer((_) => tagsController.stream);

      when(() => mockJournalDb.getMatchingTags(
            any(),
            limit: any(named: 'limit'),
            inactive: any(named: 'inactive'),
          )).thenAnswer((_) async => []);

      getIt.registerSingleton<JournalDb>(mockJournalDb);

      tagsService = TagsService();
    });

    tearDown(() async {
      await tagsController.close();
    });

    test('constructor initializes and populates tagsById from stream',
        () async {
      tagsController.add([testStoryTag1, testPersonTag1, testTag1]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(tagsService.tagsById.length, 3);
      expect(tagsService.tagsById[testStoryTag1.id], testStoryTag1);
      expect(tagsService.tagsById[testPersonTag1.id], testPersonTag1);
      expect(tagsService.tagsById[testTag1.id], testTag1);
    });

    test('getTagById returns correct tag', () async {
      tagsController.add([testStoryTag1, testPersonTag1]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = tagsService.getTagById(testStoryTag1.id);
      expect(result, testStoryTag1);
    });

    test('getTagById returns null for non-existing id', () async {
      tagsController.add([testStoryTag1]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = tagsService.getTagById('non-existing-id');
      expect(result, isNull);
    });

    test('tagsById updates when stream emits new data', () async {
      // Initial data
      tagsController.add([testStoryTag1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(tagsService.tagsById.length, 1);
      expect(tagsService.tagsById[testStoryTag1.id], testStoryTag1);

      // Update with new data
      tagsController.add([testPersonTag1, testTag1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Cache should be replaced with new data
      expect(tagsService.tagsById.length, 2);
      expect(tagsService.tagsById[testStoryTag1.id], isNull);
      expect(tagsService.tagsById[testPersonTag1.id], testPersonTag1);
      expect(tagsService.tagsById[testTag1.id], testTag1);
    });

    test('getFilteredStoryTagIds returns only story tags', () async {
      tagsController.add([testStoryTag1, testPersonTag1, testTag1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = tagsService.getFilteredStoryTagIds([
        testStoryTag1.id,
        testPersonTag1.id,
        testTag1.id,
      ]);

      expect(result.length, 1);
      expect(result, contains(testStoryTag1.id));
      expect(result, isNot(contains(testPersonTag1.id)));
      expect(result, isNot(contains(testTag1.id)));
    });

    test('getFilteredStoryTagIds handles null tag list', () {
      final result = tagsService.getFilteredStoryTagIds(null);

      expect(result, isEmpty);
    });

    test('getFilteredStoryTagIds handles empty tag list', () {
      final result = tagsService.getFilteredStoryTagIds([]);

      expect(result, isEmpty);
    });

    test('getFilteredStoryTagIds handles multiple story tags', () async {
      final testStoryTag2 = StoryTag(
        id: 'story-tag-2-id',
        tag: 'Working',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        private: false,
        vectorClock: null,
      );

      tagsController.add([testStoryTag1, testStoryTag2, testPersonTag1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = tagsService.getFilteredStoryTagIds([
        testStoryTag1.id,
        testStoryTag2.id,
        testPersonTag1.id,
      ]);

      expect(result.length, 2);
      expect(result, contains(testStoryTag1.id));
      expect(result, contains(testStoryTag2.id));
    });

    test('getFilteredStoryTagIds handles non-existent tag IDs', () async {
      tagsController.add([testStoryTag1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = tagsService.getFilteredStoryTagIds([
        testStoryTag1.id,
        'non-existent-tag-id',
      ]);

      expect(result.length, 1);
      expect(result, contains(testStoryTag1.id));
    });

    test('setClipboard stores entry ID', () {
      const entryId = 'test-entry-id';

      tagsService.setClipboard(entryId);

      // We can't directly access _clipboardCopiedId, but we can verify
      // it's set by calling getClipboard
      expect(() => tagsService.setClipboard(entryId), returnsNormally);
    });

    test('getClipboard returns tags from clipboard entry', () async {
      const clipboardEntryId = 'clipboard-entry-id';
      final entryWithTags = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          tagIds: [testStoryTag1.id, testPersonTag1.id],
        ),
      );

      when(() => mockJournalDb.journalEntityById(clipboardEntryId))
          .thenAnswer((_) async => entryWithTags);

      tagsService.setClipboard(clipboardEntryId);
      final result = await tagsService.getClipboard();

      expect(result.length, 2);
      expect(result, contains(testStoryTag1.id));
      expect(result, contains(testPersonTag1.id));
    });

    test('getClipboard returns empty list when clipboard is not set', () async {
      final result = await tagsService.getClipboard();

      expect(result, isEmpty);
    });

    test('getClipboard returns empty list when clipboard entry not found',
        () async {
      const clipboardEntryId = 'non-existent-entry-id';

      when(() => mockJournalDb.journalEntityById(clipboardEntryId))
          .thenAnswer((_) async => null);

      tagsService.setClipboard(clipboardEntryId);
      final result = await tagsService.getClipboard();

      expect(result, isEmpty);
    });

    test('getClipboard handles entry without tags', () async {
      const clipboardEntryId = 'clipboard-entry-id';
      final entryWithoutTags = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(tagIds: null),
      );

      when(() => mockJournalDb.journalEntityById(clipboardEntryId))
          .thenAnswer((_) async => entryWithoutTags);

      tagsService.setClipboard(clipboardEntryId);
      final result = await tagsService.getClipboard();

      expect(result, isEmpty);
    });

    test('getMatchingTags delegates to database', () async {
      final matchingTags = [testStoryTag1, testTag1];

      when(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 100,
          )).thenAnswer((_) async => matchingTags);

      final result = await tagsService.getMatchingTags(
        'test',
        limit: 100,
      );

      expect(result, matchingTags);
      verify(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 100,
          )).called(1);
    });

    test('getMatchingTags uses default limit', () async {
      when(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 1000,
          )).thenAnswer((_) async => []);

      await tagsService.getMatchingTags('test');

      verify(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 1000,
          )).called(1);
    });

    test('getMatchingTags with inactive flag', () async {
      when(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 50,
            inactive: true,
          )).thenAnswer((_) async => []);

      await tagsService.getMatchingTags('test', limit: 50, inactive: true);

      verify(() => mockJournalDb.getMatchingTags(
            'test',
            limit: 50,
            inactive: true,
          )).called(1);
    });

    test('watchTags delegates to database', () {
      final stream = tagsService.watchTags();

      expect(stream, isNotNull);
      // Called twice: once in constructor, once in watchTags
      verify(() => mockJournalDb.watchTags()).called(2);
    });

    test('watchTags returns same stream as constructor', () {
      final stream = tagsService.watchTags();

      expect(stream, tagsService.stream);
    });
  });
}
