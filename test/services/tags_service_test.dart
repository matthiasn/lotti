import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsService Tests', () {
    late MockJournalDb mockJournalDb;
    late MockUpdateNotifications mockUpdateNotifications;
    late StreamController<Set<String>> notificationsController;
    late TagsService tagsService;

    setUp(() async {
      await getIt.reset();

      mockJournalDb = MockJournalDb();
      mockUpdateNotifications = MockUpdateNotifications();
      notificationsController = StreamController<Set<String>>.broadcast();

      when(() => mockUpdateNotifications.updateStream)
          .thenAnswer((_) => notificationsController.stream);

      when(() => mockJournalDb.getAllTags())
          .thenAnswer((_) async => <TagEntity>[]);

      when(() => mockJournalDb.getMatchingTags(
            any(),
            limit: any(named: 'limit'),
            inactive: any(named: 'inactive'),
          )).thenAnswer((_) async => []);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    });

    tearDown(() async {
      await notificationsController.close();
      await getIt.reset();
    });

    test('constructor initializes and populates tagsById from stream', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1, testPersonTag1, testTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        expect(tagsService.tagsById.length, 3);
        expect(tagsService.tagsById[testStoryTag1.id], testStoryTag1);
        expect(tagsService.tagsById[testPersonTag1.id], testPersonTag1);
        expect(tagsService.tagsById[testTag1.id], testTag1);
      });
    });

    test('getTagById returns correct tag', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1, testPersonTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getTagById(testStoryTag1.id);
        expect(result, testStoryTag1);
      });
    });

    test('getTagById returns null for non-existing id', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getTagById('non-existing-id');
        expect(result, isNull);
      });
    });

    test('tagsById updates when notification triggers re-fetch', () {
      fakeAsync((async) {
        // Initial data
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        expect(tagsService.tagsById.length, 1);
        expect(tagsService.tagsById[testStoryTag1.id], testStoryTag1);

        // Update data and trigger re-fetch via notification
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testPersonTag1, testTag1]);
        notificationsController.add({tagsNotification});
        async.flushMicrotasks();

        // Cache should be replaced with new data
        expect(tagsService.tagsById.length, 2);
        expect(tagsService.tagsById[testStoryTag1.id], isNull);
        expect(tagsService.tagsById[testPersonTag1.id], testPersonTag1);
        expect(tagsService.tagsById[testTag1.id], testTag1);
      });
    });

    test('getFilteredStoryTagIds returns only story tags', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1, testPersonTag1, testTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

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
    });

    test('getFilteredStoryTagIds handles null tag list', () {
      fakeAsync((async) {
        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getFilteredStoryTagIds(null);
        expect(result, isEmpty);
      });
    });

    test('getFilteredStoryTagIds handles empty tag list', () {
      fakeAsync((async) {
        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getFilteredStoryTagIds([]);
        expect(result, isEmpty);
      });
    });

    test('getFilteredStoryTagIds handles multiple story tags', () {
      fakeAsync((async) {
        final testStoryTag2 = StoryTag(
          id: 'story-tag-2-id',
          tag: 'Working',
          createdAt: testEpochDateTime,
          updatedAt: testEpochDateTime,
          private: false,
          vectorClock: null,
        );

        when(() => mockJournalDb.getAllTags()).thenAnswer(
            (_) async => [testStoryTag1, testStoryTag2, testPersonTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getFilteredStoryTagIds([
          testStoryTag1.id,
          testStoryTag2.id,
          testPersonTag1.id,
        ]);

        expect(result.length, 2);
        expect(result, contains(testStoryTag1.id));
        expect(result, contains(testStoryTag2.id));
      });
    });

    test('getFilteredStoryTagIds handles non-existent tag IDs', () {
      fakeAsync((async) {
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testStoryTag1]);

        tagsService = TagsService();
        async.flushMicrotasks();

        final result = tagsService.getFilteredStoryTagIds([
          testStoryTag1.id,
          'non-existent-tag-id',
        ]);

        expect(result.length, 1);
        expect(result, contains(testStoryTag1.id));
      });
    });

    test('setClipboard stores entry ID', () {
      fakeAsync((async) {
        tagsService = TagsService();
        async.flushMicrotasks();

        const entryId = 'test-entry-id';
        tagsService.setClipboard(entryId);
        expect(() => tagsService.setClipboard(entryId), returnsNormally);
      });
    });

    test('getClipboard returns tags from clipboard entry', () async {
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

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
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

      final result = await tagsService.getClipboard();
      expect(result, isEmpty);
    });

    test('getClipboard returns empty list when clipboard entry not found',
        () async {
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

      const clipboardEntryId = 'non-existent-entry-id';
      when(() => mockJournalDb.journalEntityById(clipboardEntryId))
          .thenAnswer((_) async => null);

      tagsService.setClipboard(clipboardEntryId);
      final result = await tagsService.getClipboard();

      expect(result, isEmpty);
    });

    test('getClipboard handles entry without tags', () async {
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

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
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

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
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

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
      tagsService = TagsService();
      await Future<void>.delayed(Duration.zero);

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

    test('watchTags emits cached tags for late subscribers', () {
      fakeAsync((async) {
        final testTag = testStoryTag1;
        when(() => mockJournalDb.getAllTags())
            .thenAnswer((_) async => [testTag]);

        tagsService = TagsService();
        async.flushMicrotasks();

        // Tags are now cached in tagsById from the internal listener.
        expect(tagsService.tagsById, isNotEmpty);

        // A late subscriber should immediately receive cached tags,
        // even though the broadcast stream's initial emission already fired.
        final emissions = <List<TagEntity>>[];
        tagsService.watchTags().listen(emissions.add);
        async.flushMicrotasks();

        expect(emissions, hasLength(1));
        expect(emissions.first, contains(testTag));
      });
    });
  });
}
