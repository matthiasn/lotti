import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late TaskProgressRepository repository;
  late MockJournalDb mockJournalDb;

  setUp(() {
    mockJournalDb = MockJournalDb();
    getIt.registerSingleton<JournalDb>(mockJournalDb);
    repository = TaskProgressRepository();
  });

  tearDown(getIt.reset);

  group('getTaskProgressData', () {
    test('returns null when entity is not a Task', () async {
      // Arrange
      const nonTaskId = 'non-task-id';
      when(() => mockJournalDb.journalEntityById(nonTaskId))
          .thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.getTaskProgressData(id: nonTaskId);

      // Assert
      expect(result, isNull);
      verify(() => mockJournalDb.journalEntityById(nonTaskId)).called(1);
    });

    test('returns task progress data with no linked entities', () async {
      // Arrange
      final taskId = testTask.id;
      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockJournalDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => []);

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$1, equals(testTask.data.estimate));
      expect(result?.$2, isEmpty);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
    });

    test('returns task progress data with linked entries', () async {
      // Arrange
      final taskId = testTask.id;
      final linkedEntry = testTextEntry;

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockJournalDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => [linkedEntry]);

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$1, equals(testTask.data.estimate));
      expect(result?.$2, isNotEmpty);
      expect(result?.$2.containsKey(linkedEntry.id), isTrue);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
    });

    test('ignores linked tasks when calculating duration', () async {
      // Arrange
      final taskId = testTask.id;
      final linkedTask = Task(
        meta: Metadata(
          id: 'linked-task-id',
          createdAt: DateTime(2022, 7, 8, 9),
          dateFrom: DateTime(2022, 7, 8, 9),
          dateTo: DateTime(2022, 7, 8, 11),
          updatedAt: DateTime(2022, 7, 8, 11),
        ),
        entryText: const EntryText(plainText: 'linked task text'),
        data: testTask.data.copyWith(
          title: 'Linked task',
        ),
      );

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockJournalDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => [linkedTask, testTextEntry]);

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$2.containsKey(linkedTask.id), isFalse);
      expect(result?.$2.containsKey(testTextEntry.id), isTrue);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
    });

    test('ignores audio entries when calculating duration to prevent double-counting', () async {
      // Arrange
      final taskId = testTask.id;
      // Create audio entry with unique ID (testAudioEntry shares ID with testTextEntry)
      final audioEntry = JournalAudio(
        meta: Metadata(
          id: 'unique-audio-entry-id',
          createdAt: DateTime(2022, 7, 7, 13),
          dateFrom: DateTime(2022, 7, 7, 13),
          dateTo: DateTime(2022, 7, 7, 14),
          updatedAt: DateTime(2022, 7, 7, 13),
        ),
        entryText: const EntryText(plainText: 'audio entry text'),
        data: AudioData(
          dateFrom: DateTime(2022, 7, 7, 13),
          dateTo: DateTime(2022, 7, 7, 14),
          duration: const Duration(hours: 1),
          audioFile: '',
          audioDirectory: '',
        ),
      );

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockJournalDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => [audioEntry, testTextEntry]);

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      // Audio entry should be excluded (to prevent double-counting meeting time)
      expect(result?.$2.containsKey(audioEntry.id), isFalse);
      // Text entry should still be included
      expect(result?.$2.containsKey(testTextEntry.id), isTrue);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      verify(() => mockJournalDb.getLinkedEntities(taskId)).called(1);
    });
  });

  group('sumTimeSpentFromEntities', () {
    // Create audio entry with unique ID for these tests
    final uniqueAudioEntry = JournalAudio(
      meta: Metadata(
        id: 'unique-audio-id-for-sum-tests',
        createdAt: DateTime(2022, 7, 7, 13),
        dateFrom: DateTime(2022, 7, 7, 13),
        dateTo: DateTime(2022, 7, 7, 14),
        updatedAt: DateTime(2022, 7, 7, 13),
      ),
      entryText: const EntryText(plainText: 'audio entry'),
      data: AudioData(
        dateFrom: DateTime(2022, 7, 7, 13),
        dateTo: DateTime(2022, 7, 7, 14),
        duration: const Duration(hours: 1),
        audioFile: '',
        audioDirectory: '',
      ),
    );

    test('returns zero for empty list', () {
      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities([]);

      // Assert
      expect(total, equals(Duration.zero));
    });

    test('returns zero when only audio entries present', () {
      // Arrange
      final entities = [uniqueAudioEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert
      expect(total, equals(Duration.zero));
    });

    test('excludes audio entries from total time calculation', () {
      // Arrange
      final entities = [uniqueAudioEntry, testTextEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - should only include testTextEntry duration, not audio
      final expectedDuration = testTextEntry.meta.dateTo.difference(
        testTextEntry.meta.dateFrom,
      );
      expect(total, equals(expectedDuration));
    });

    test('excludes tasks from total time calculation', () {
      // Arrange
      final entities = [testTask, testTextEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - should only include testTextEntry duration
      final expectedDuration = testTextEntry.meta.dateTo.difference(
        testTextEntry.meta.dateFrom,
      );
      expect(total, equals(expectedDuration));
    });

    test('excludes AiResponseEntry from total time calculation', () {
      // Arrange
      final aiResponse = AiResponseEntry(
        meta: Metadata(
          id: 'ai-response-id',
          createdAt: DateTime(2022, 7, 7, 13),
          dateFrom: DateTime(2022, 7, 7, 13),
          dateTo: DateTime(2022, 7, 7, 14),
          updatedAt: DateTime(2022, 7, 7, 13),
        ),
        data: AiResponseData(
          model: 'test-model',
          systemMessage: 'system',
          prompt: 'prompt',
          thoughts: '',
          response: 'response',
        ),
      );
      final entities = [aiResponse, testTextEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - should only include testTextEntry duration
      final expectedDuration = testTextEntry.meta.dateTo.difference(
        testTextEntry.meta.dateFrom,
      );
      expect(total, equals(expectedDuration));
    });

    test('returns zero when all entries are excluded types', () {
      // Arrange
      final entities = [uniqueAudioEntry, testTask];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert
      expect(total, equals(Duration.zero));
    });

    test('handles mix of audio, text, and image entries correctly', () {
      // Arrange - create unique image entry
      final imageEntry = JournalImage(
        meta: Metadata(
          id: 'unique-image-id',
          createdAt: DateTime(2022, 7, 7, 15),
          dateFrom: DateTime(2022, 7, 7, 15),
          dateTo: DateTime(2022, 7, 7, 15, 30), // 30 min duration
          updatedAt: DateTime(2022, 7, 7, 15),
        ),
        entryText: const EntryText(plainText: 'image entry'),
        data: ImageData(
          imageId: '',
          imageFile: '',
          imageDirectory: '',
          capturedAt: DateTime(2022, 7, 7, 15),
        ),
      );
      final entities = [uniqueAudioEntry, testTextEntry, imageEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - should sum text (1hr) + image (30min), exclude audio
      final textDuration = testTextEntry.meta.dateTo.difference(
        testTextEntry.meta.dateFrom,
      );
      final imageDuration = imageEntry.meta.dateTo.difference(
        imageEntry.meta.dateFrom,
      );
      expect(total, equals(textDuration + imageDuration));
    });

    test('sums multiple text entries correctly', () {
      // Arrange
      final textEntry1 = JournalEntry(
        meta: Metadata(
          id: 'text-entry-1',
          createdAt: DateTime(2022, 7, 7, 9),
          dateFrom: DateTime(2022, 7, 7, 9),
          dateTo: DateTime(2022, 7, 7, 10), // 1 hour
          updatedAt: DateTime(2022, 7, 7, 10),
        ),
        entryText: const EntryText(plainText: 'entry 1'),
      );
      final textEntry2 = JournalEntry(
        meta: Metadata(
          id: 'text-entry-2',
          createdAt: DateTime(2022, 7, 7, 14),
          dateFrom: DateTime(2022, 7, 7, 14),
          dateTo: DateTime(2022, 7, 7, 14, 30), // 30 min
          updatedAt: DateTime(2022, 7, 7, 14, 30),
        ),
        entryText: const EntryText(plainText: 'entry 2'),
      );
      final entities = [textEntry1, textEntry2];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - 1 hour + 30 min = 1.5 hours
      expect(total, equals(const Duration(hours: 1, minutes: 30)));
    });
  });

  group('getTaskProgress', () {
    test('calculates progress correctly with no durations', () {
      // Arrange
      final durations = <String, Duration>{};
      const estimate = Duration(hours: 2);

      // Act
      final result = repository.getTaskProgress(
        durations: durations,
        estimate: estimate,
      );

      // Assert
      expect(result.progress, Duration.zero);
      expect(result.estimate, estimate);
    });

    test('calculates progress correctly with durations', () {
      // Arrange
      final durations = <String, Duration>{
        'entry1': const Duration(minutes: 30),
        'entry2': const Duration(minutes: 45),
      };
      const estimate = Duration(hours: 2);
      const expectedProgress = Duration(minutes: 75);

      // Act
      final result = repository.getTaskProgress(
        durations: durations,
        estimate: estimate,
      );

      // Assert
      expect(result.progress, expectedProgress);
      expect(result.estimate, estimate);
    });

    test('uses zero for estimate when null is provided', () {
      // Arrange
      final durations = <String, Duration>{
        'entry1': const Duration(minutes: 30),
      };

      // Act
      final result = repository.getTaskProgress(durations: durations);

      // Assert
      expect(result.progress, const Duration(minutes: 30));
      expect(result.estimate, Duration.zero);
    });
  });
}
