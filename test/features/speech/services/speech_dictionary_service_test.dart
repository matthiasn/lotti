import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late SpeechDictionaryService service;
  late MockCategoryRepository mockCategoryRepository;
  late MockJournalRepository mockJournalRepository;

  final testCategory = CategoryDefinition(
    id: 'category-1',
    name: 'Test Category',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#FF0000',
    speechDictionary: ['existingTerm'],
  );

  final testCategoryNoDict = CategoryDefinition(
    id: 'category-2',
    name: 'Category Without Dictionary',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
    vectorClock: null,
    private: false,
    active: true,
    color: '#00FF00',
  );

  final testTask = Task(
    data: TaskData(
      title: 'Test Task',
      checklistIds: const [],
      status: TaskStatus.open(
        id: 'status',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    meta: Metadata(
      id: 'task-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
      categoryId: 'category-1',
    ),
  );

  final testTaskNoCategory = Task(
    data: TaskData(
      title: 'Task Without Category',
      checklistIds: const [],
      status: TaskStatus.open(
        id: 'status',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    meta: Metadata(
      id: 'task-2',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  );

  final testAudio = JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: AudioData(
      audioFile: 'test.m4a',
      audioDirectory: '/tmp',
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      duration: const Duration(seconds: 30),
    ),
  );

  final testImage = JournalImage(
    meta: Metadata(
      id: 'image-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    data: ImageData(
      imageId: 'image-1',
      imageFile: 'test.jpg',
      imageDirectory: '/tmp',
      capturedAt: DateTime(2025),
    ),
  );

  final testTextEntry = JournalEntry(
    meta: Metadata(
      id: 'entry-1',
      createdAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  );

  setUpAll(() {
    registerFallbackValue(testCategory);
  });

  setUp(() {
    mockCategoryRepository = MockCategoryRepository();
    mockJournalRepository = MockJournalRepository();

    service = SpeechDictionaryService(
      categoryRepository: mockCategoryRepository,
      journalRepository: mockJournalRepository,
    );
  });

  group('SpeechDictionaryService', () {
    group('addTermForEntry', () {
      test('successfully adds term to task category', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-1'))
            .thenAnswer((_) async => testTask);
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments[0] as CategoryDefinition);

        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: 'newTerm',
        );

        expect(result, equals(SpeechDictionaryResult.success));

        // Verify category was updated with new term
        final captured = verify(
          () => mockCategoryRepository.updateCategory(captureAny()),
        ).captured;
        final updatedCategory = captured.first as CategoryDefinition;
        expect(
          updatedCategory.speechDictionary,
          equals(['existingTerm', 'newTerm']),
        );
      });

      test('successfully adds term to category without existing dictionary',
          () async {
        final taskWithCategory2 = Task(
          data: testTask.data,
          meta: testTask.meta.copyWith(categoryId: 'category-2'),
        );

        when(() => mockJournalRepository.getJournalEntityById('task-1'))
            .thenAnswer((_) async => taskWithCategory2);
        when(() => mockCategoryRepository.getCategoryById('category-2'))
            .thenAnswer((_) async => testCategoryNoDict);
        when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments[0] as CategoryDefinition);

        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: 'firstTerm',
        );

        expect(result, equals(SpeechDictionaryResult.success));

        // Verify category was updated with new term
        final captured = verify(
          () => mockCategoryRepository.updateCategory(captureAny()),
        ).captured;
        final updatedCategory = captured.first as CategoryDefinition;
        expect(updatedCategory.speechDictionary, equals(['firstTerm']));
      });

      test('adds term from audio entry linked to task', () async {
        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => testAudio);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => [testTask]);
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments[0] as CategoryDefinition);

        final result = await service.addTermForEntry(
          entryId: 'audio-1',
          term: 'audioTerm',
        );

        expect(result, equals(SpeechDictionaryResult.success));
      });

      test('adds term from image entry linked to task', () async {
        when(() => mockJournalRepository.getJournalEntityById('image-1'))
            .thenAnswer((_) async => testImage);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'image-1'))
            .thenAnswer((_) async => [testTask]);
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments[0] as CategoryDefinition);

        final result = await service.addTermForEntry(
          entryId: 'image-1',
          term: 'imageTerm',
        );

        expect(result, equals(SpeechDictionaryResult.success));
      });

      test('returns emptyTerm for empty string', () async {
        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: '',
        );

        expect(result, equals(SpeechDictionaryResult.emptyTerm));
        verifyNever(() => mockJournalRepository.getJournalEntityById(any()));
      });

      test('returns emptyTerm for whitespace-only string', () async {
        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: '   ',
        );

        expect(result, equals(SpeechDictionaryResult.emptyTerm));
        verifyNever(() => mockJournalRepository.getJournalEntityById(any()));
      });

      test('returns termTooLong for term exceeding max length', () async {
        final longTerm = 'a' * (kMaxTermLength + 1);

        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: longTerm,
        );

        expect(result, equals(SpeechDictionaryResult.termTooLong));
        verifyNever(() => mockJournalRepository.getJournalEntityById(any()));
      });

      test('returns entryNotFound when entry does not exist', () async {
        when(() => mockJournalRepository.getJournalEntityById('nonexistent'))
            .thenAnswer((_) async => null);

        final result = await service.addTermForEntry(
          entryId: 'nonexistent',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.entryNotFound));
      });

      test('returns noCategory when task has no category', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-2'))
            .thenAnswer((_) async => testTaskNoCategory);

        final result = await service.addTermForEntry(
          entryId: 'task-2',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.noCategory));
      });

      test('returns noCategory for text entry (not task/audio/image)',
          () async {
        when(() => mockJournalRepository.getJournalEntityById('entry-1'))
            .thenAnswer((_) async => testTextEntry);

        final result = await service.addTermForEntry(
          entryId: 'entry-1',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.noCategory));
      });

      test('returns noCategory when audio has no linked task', () async {
        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => testAudio);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => []);

        final result = await service.addTermForEntry(
          entryId: 'audio-1',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.noCategory));
      });

      test('returns noCategory when linked task has no category', () async {
        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => testAudio);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => [testTaskNoCategory]);

        final result = await service.addTermForEntry(
          entryId: 'audio-1',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.noCategory));
      });

      test('returns categoryNotFound when category does not exist', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-1'))
            .thenAnswer((_) async => testTask);
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => null);

        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: 'term',
        );

        expect(result, equals(SpeechDictionaryResult.categoryNotFound));
      });

      test('trims whitespace from term before adding', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-1'))
            .thenAnswer((_) async => testTask);
        when(() => mockCategoryRepository.getCategoryById('category-1'))
            .thenAnswer((_) async => testCategory);
        when(() => mockCategoryRepository.updateCategory(any())).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments[0] as CategoryDefinition);

        final result = await service.addTermForEntry(
          entryId: 'task-1',
          term: '  trimmed  ',
        );

        expect(result, equals(SpeechDictionaryResult.success));

        final captured = verify(
          () => mockCategoryRepository.updateCategory(captureAny()),
        ).captured;
        final updatedCategory = captured.first as CategoryDefinition;
        expect(
          updatedCategory.speechDictionary,
          equals(['existingTerm', 'trimmed']),
        );
      });
    });

    group('canAddTermForEntry', () {
      test('returns true for task with category', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-1'))
            .thenAnswer((_) async => testTask);

        final result = await service.canAddTermForEntry('task-1');

        expect(result, isTrue);
      });

      test('returns false for task without category', () async {
        when(() => mockJournalRepository.getJournalEntityById('task-2'))
            .thenAnswer((_) async => testTaskNoCategory);

        final result = await service.canAddTermForEntry('task-2');

        expect(result, isFalse);
      });

      test('returns false for non-existent entry', () async {
        when(() => mockJournalRepository.getJournalEntityById('nonexistent'))
            .thenAnswer((_) async => null);

        final result = await service.canAddTermForEntry('nonexistent');

        expect(result, isFalse);
      });

      test('returns true for audio linked to task with category', () async {
        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => testAudio);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => [testTask]);

        final result = await service.canAddTermForEntry('audio-1');

        expect(result, isTrue);
      });

      test('returns false for audio not linked to any task', () async {
        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => testAudio);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'audio-1'))
            .thenAnswer((_) async => []);

        final result = await service.canAddTermForEntry('audio-1');

        expect(result, isFalse);
      });

      test('returns true for image linked to task with category', () async {
        when(() => mockJournalRepository.getJournalEntityById('image-1'))
            .thenAnswer((_) async => testImage);
        when(() =>
                mockJournalRepository.getLinkedToEntities(linkedTo: 'image-1'))
            .thenAnswer((_) async => [testTask]);

        final result = await service.canAddTermForEntry('image-1');

        expect(result, isTrue);
      });

      test('returns false for text entry', () async {
        when(() => mockJournalRepository.getJournalEntityById('entry-1'))
            .thenAnswer((_) async => testTextEntry);

        final result = await service.canAddTermForEntry('entry-1');

        expect(result, isFalse);
      });
    });
  });

  group('SpeechDictionaryResult enum', () {
    test('has all expected values', () {
      expect(SpeechDictionaryResult.values, hasLength(6));
      expect(
        SpeechDictionaryResult.values,
        containsAll([
          SpeechDictionaryResult.success,
          SpeechDictionaryResult.emptyTerm,
          SpeechDictionaryResult.termTooLong,
          SpeechDictionaryResult.entryNotFound,
          SpeechDictionaryResult.noCategory,
          SpeechDictionaryResult.categoryNotFound,
        ]),
      );
    });
  });
}
