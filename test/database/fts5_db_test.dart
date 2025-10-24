import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:research_package/model.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

class _MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

Metadata _buildMetadata(String id) {
  final timestamp = DateTime(2024, 1, 1, 12);
  return Metadata(
    id: id,
    createdAt: timestamp,
    updatedAt: timestamp,
    dateFrom: timestamp,
    dateTo: timestamp,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fts5Db Tests', () {
    test(
      'initializes in-memory database and exposes schema version 1',
      () async {
        final db = Fts5Db(inMemoryDatabase: true);

        expect(db.schemaVersion, equals(1));

        await db.insertJournalEntry(
          'plain text',
          'title',
          'summary',
          '',
          'uuid-1',
        );

        final results = await db.watchFullTextMatches('"uuid-1"').first;
        expect(results, contains('uuid-1'));

        await db.close();
      },
    );
    test(
      'creates file-based database at expected location when inMemoryDatabase is false',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('fts5_db_test_');
        final originalPathProvider = PathProviderPlatform.instance;
        final mockPathProvider = _MockPathProviderPlatform();

        PathProviderPlatform.instance = mockPathProvider;
        addTearDown(
          () => PathProviderPlatform.instance = originalPathProvider,
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        when(mockPathProvider.getApplicationDocumentsPath)
            .thenAnswer((_) async => tempDir.path);
        when(mockPathProvider.getApplicationSupportPath)
            .thenAnswer((_) async => tempDir.path);
        when(mockPathProvider.getTemporaryPath)
            .thenAnswer((_) async => tempDir.path);

        final db = Fts5Db();
        addTearDown(() async => db.close());

        await db.insertJournalEntry(
          'file plain text',
          'file title',
          'file summary',
          '',
          'uuid-file',
        );

        final dbFile = File(p.join(tempDir.path, fts5DbFileName));
        expect(dbFile.existsSync(), isTrue);
      },
    );

    group('insertText', () {
      late Fts5Db db;
      late MockTagsService tagsService;
      late MockEntitiesCacheService entitiesCacheService;

      setUp(() async {
        await getIt.reset();

        tagsService = MockTagsService();
        entitiesCacheService = MockEntitiesCacheService();

        when(() => tagsService.getTagById(any())).thenReturn(null);
        when(() => entitiesCacheService.getDataTypeById(any()))
            .thenReturn(null);

        getIt
          ..registerSingleton<TagsService>(tagsService)
          ..registerSingleton<EntitiesCacheService>(entitiesCacheService);

        db = Fts5Db(inMemoryDatabase: true);
      });

      tearDown(() async {
        await db.close();
        await getIt.reset();
      });

      test('insertText with basic journal entry indexes plain text', () async {
        await db.insertText(testTextEntry);

        final rows = await db.select(db.journalFts).get();
        expect(rows, hasLength(1));

        final matches = await db.watchFullTextMatches('test entry text').first;
        expect(matches, contains(testTextEntry.meta.id));
      });

      test('insertText with task entry indexes the task title', () async {
        when(() => tagsService.getTagById(any())).thenReturn(null);

        await db.insertText(testTask);

        final matches = await db.watchFullTextMatches('Add tests').first;
        expect(matches, contains(testTask.meta.id));
      });

      test('insertText with survey entry indexes identifier and scores',
          () async {
        final surveyEntry = SurveyEntry(
          meta: _buildMetadata('survey-id'),
          data: SurveyData(
            taskResult: RPTaskResult(identifier: 'panasSurveyTask'),
            scoreDefinitions: {
              'Positive Affect': {'q1', 'q2'},
              'Negative Affect': {'q3'},
            },
            calculatedScores: const {
              'Positive Affect': 10,
              'Negative Affect': 2,
            },
          ),
        );

        await db.insertText(surveyEntry);

        final identifierMatches =
            await db.watchFullTextMatches('panasSurveyTask').first;
        expect(identifierMatches, contains('survey-id'));

        final scoreMatches =
            await db.watchFullTextMatches('"Positive Affect: 10"').first;
        expect(scoreMatches, contains('survey-id'));
      });

      test('insertText with measurement entry indexes measurement summary',
          () async {
        when(() => entitiesCacheService.getDataTypeById(measurableChocolate.id))
            .thenReturn(measurableChocolate);

        await db.insertText(testMeasurementChocolateEntry);

        final matches =
            await db.watchFullTextMatches('"Chocolate 100 g"').first;
        expect(matches, contains(testMeasurementChocolateEntry.meta.id));
      });

      test('insertText with quantitative entry indexes health data', () async {
        await db.insertText(testWeightEntry);

        final weightMatches = await db.watchFullTextMatches('Weight').first;
        expect(weightMatches, contains(testWeightEntry.meta.id));

        final valueMatches =
            await db.watchFullTextMatches('"94.49400329589844"').first;
        expect(valueMatches, contains(testWeightEntry.meta.id));
      });

      test('insertText with tags indexes tag names for search', () async {
        when(() => tagsService.getTagById(testStoryTag1.id))
            .thenReturn(testStoryTag1);
        when(() => tagsService.getTagById(testPersonTag1.id))
            .thenReturn(testPersonTag1);

        await db.insertText(testTextEntryWithTags);

        final tagMatches = await db.watchFullTextMatches('Reading').first;
        expect(tagMatches, contains(testTextEntryWithTags.meta.id));

        final personMatches = await db.watchFullTextMatches('Jane Doe').first;
        expect(personMatches, contains(testTextEntryWithTags.meta.id));
      });

      test('insertText removes previous entry when removePrevious is true',
          () async {
        await db.insertText(testTextEntry);

        final updatedEntry = testTextEntry.copyWith(
          entryText: const EntryText(plainText: 'updated content'),
        );

        await db.insertText(updatedEntry, removePrevious: true);

        final rows = await db.select(db.journalFts).get();
        expect(rows, hasLength(1));

        final newMatches =
            await db.watchFullTextMatches('updated content').first;
        expect(newMatches, contains(testTextEntry.meta.id));

        final oldMatches =
            await db.watchFullTextMatches('test entry text').first;
        expect(oldMatches, isEmpty);
      });

      test('insertText keeps previous entry when removePrevious is false',
          () async {
        await db.insertText(testTextEntry);

        final duplicateEntry = testTextEntry.copyWith(
          entryText: const EntryText(plainText: 'duplicate content'),
        );

        await db.insertText(duplicateEntry);

        final rows = await db.select(db.journalFts).get();
        expect(rows, hasLength(2));
        expect(rows.every((row) => row.uuid == testTextEntry.meta.id), isTrue);

        final originalMatches =
            await db.watchFullTextMatches('test entry text').first;
        expect(originalMatches, isNotEmpty);

        final duplicateMatches =
            await db.watchFullTextMatches('duplicate content').first;
        expect(duplicateMatches, isNotEmpty);
      });

      test('insertText skips empty entries', () async {
        final emptyEntry = JournalEntry(
          meta: _buildMetadata('empty-entry'),
          entryText: const EntryText(plainText: ''),
        );

        await db.insertText(emptyEntry);

        final rows = await db.select(db.journalFts).get();
        expect(rows, isEmpty);
      });

      test('insertText skips whitespace-only content', () async {
        final whitespaceEntry = JournalEntry(
          meta: _buildMetadata('whitespace-entry'),
          entryText: const EntryText(plainText: '   \n\t  '),
        );

        await db.insertText(whitespaceEntry);

        final rows = await db.select(db.journalFts).get();
        expect(rows, isEmpty);
      });

      test('insertText with null entryText stores empty plain text', () async {
        final taskWithoutText = testTask.copyWith(entryText: null);

        await db.insertText(taskWithoutText);

        final rows = await db.select(db.journalFts).get();
        expect(rows, hasLength(1));
        expect(rows.first.plainText, isEmpty);

        final titleMatches = await db.watchFullTextMatches('Add tests').first;
        expect(titleMatches, contains(taskWithoutText.meta.id));
      });

      test('insertText handles missing tag references gracefully', () async {
        await db.insertText(testTextEntryWithTags);

        final matches = await db.watchFullTextMatches('test entry text').first;
        expect(matches, contains(testTextEntryWithTags.meta.id));

        final tagMatches = await db.watchFullTextMatches('Reading').first;
        expect(tagMatches, isEmpty);
      });
    });

    group('watchFullTextMatches', () {
      late Fts5Db db;
      late MockTagsService tagsService;
      late MockEntitiesCacheService entitiesCacheService;

      setUp(() async {
        await getIt.reset();

        tagsService = MockTagsService();
        entitiesCacheService = MockEntitiesCacheService();

        when(() => tagsService.getTagById(any())).thenReturn(null);
        when(() => entitiesCacheService.getDataTypeById(any()))
            .thenReturn(null);

        getIt
          ..registerSingleton<TagsService>(tagsService)
          ..registerSingleton<EntitiesCacheService>(entitiesCacheService);

        db = Fts5Db(inMemoryDatabase: true);
      });

      tearDown(() async {
        await db.close();
        await getIt.reset();
      });

      test('returns matching entry ids for query', () async {
        await db.insertText(testTextEntry);
        await db.insertText(testTask);

        final matches = await db.watchFullTextMatches('test entry text').first;
        expect(matches, equals([testTextEntry.meta.id]));
      });

      test('returns empty list when no entries match', () async {
        await db.insertText(testTask);

        final matches = await db.watchFullTextMatches('nothing here').first;
        expect(matches, isEmpty);
      });

      test('match queries are case insensitive', () async {
        final mixedEntry = JournalEntry(
          meta: _buildMetadata('mixed-entry'),
          entryText: const EntryText(plainText: 'MiXeD CaSe Content'),
        );

        await db.insertText(mixedEntry);

        final lower = await db.watchFullTextMatches('mixed').first;
        final upper = await db.watchFullTextMatches('MIXED').first;
        final camel = await db.watchFullTextMatches('Mixed').first;

        expect(lower, contains(mixedEntry.meta.id));
        expect(upper, contains(mixedEntry.meta.id));
        expect(camel, contains(mixedEntry.meta.id));
      });

      test('handles special characters safely', () async {
        final specialEntry = JournalEntry(
          meta: _buildMetadata('special-entry'),
          entryText: const EntryText(plainText: 'Learning C++ (2024)!'),
        );

        await db.insertText(specialEntry);

        final matches = await db.watchFullTextMatches('"C++"').first;
        expect(matches, contains(specialEntry.meta.id));
      });

      test('emits updates when new matching entry is inserted', () async {
        final stream = db.watchFullTextMatches('update');
        final firstEmission = Completer<List<String>>();
        final secondEmission = Completer<List<String>>();
        var count = 0;

        late final StreamSubscription<List<String>> sub;
        sub = stream.listen((event) {
          count += 1;
          if (count == 1 && !firstEmission.isCompleted) {
            firstEmission.complete(event);
          } else if (count == 2 && !secondEmission.isCompleted) {
            secondEmission.complete(event);
            sub.cancel();
          }
        });

        addTearDown(() async {
          if (!firstEmission.isCompleted) {
            firstEmission.complete(const <String>[]);
          }
          if (!secondEmission.isCompleted) {
            secondEmission.complete(const <String>[]);
          }
          await sub.cancel();
        });

        final initial = await firstEmission.future;
        expect(initial, isEmpty);

        final entry = JournalEntry(
          meta: _buildMetadata('update-entry'),
          entryText: const EntryText(plainText: 'needs update soon'),
        );

        await db.insertText(entry);

        final updated = await secondEmission.future;
        expect(updated, contains('update-entry'));
      });
    });
  });
}
