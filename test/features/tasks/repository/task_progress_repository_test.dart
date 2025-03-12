import 'package:flutter_test/flutter_test.dart';
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
