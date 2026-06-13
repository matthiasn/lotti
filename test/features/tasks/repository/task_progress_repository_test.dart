import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late TaskProgressRepository repository;
  late MockJournalDb mockJournalDb;

  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  setUp(() async {
    mockJournalDb = MockJournalDb();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb);
      },
    );
    repository = TaskProgressRepository();
  });

  tearDown(tearDownTestGetIt);

  group('getTaskProgressData', () {
    test('returns null when entity is not a Task', () async {
      // Arrange
      const nonTaskId = 'non-task-id';
      when(
        () => mockJournalDb.getTaskEstimatesByIds({nonTaskId}),
      ).thenAnswer((_) async => const <String, Duration?>{});
      when(
        () => mockJournalDb.getBulkLinkedTimeSpans({nonTaskId}),
      ).thenAnswer((_) async => {nonTaskId: const <LinkedEntityTimeSpan>[]});

      // Act
      final result = await repository.getTaskProgressData(id: nonTaskId);

      // Assert
      expect(result, isNull);
      verify(
        () => mockJournalDb.getTaskEstimatesByIds({nonTaskId}),
      ).called(1);
      verify(() => mockJournalDb.getBulkLinkedTimeSpans({nonTaskId})).called(1);
    });

    test('returns task progress data with no linked entities', () async {
      // Arrange
      final taskId = testTask.id;
      when(
        () => mockJournalDb.getTaskEstimatesByIds({taskId}),
      ).thenAnswer((_) async => {taskId: testTask.data.estimate});
      when(
        () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
      ).thenAnswer((_) async => {taskId: const <LinkedEntityTimeSpan>[]});

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$1, equals(testTask.data.estimate));
      expect(result?.$2, isEmpty);
      verify(() => mockJournalDb.getTaskEstimatesByIds({taskId})).called(1);
      verify(() => mockJournalDb.getBulkLinkedTimeSpans({taskId})).called(1);
    });

    test('returns task progress data with linked entries', () async {
      // Arrange
      final taskId = testTask.id;
      final linkedEntry = testTextEntry;

      when(
        () => mockJournalDb.getTaskEstimatesByIds({taskId}),
      ).thenAnswer((_) async => {taskId: testTask.data.estimate});
      when(
        () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
      ).thenAnswer(
        (_) async => {
          taskId: [
            (
              id: linkedEntry.id,
              dateFrom: linkedEntry.meta.dateFrom,
              dateTo: linkedEntry.meta.dateTo,
            ),
          ],
        },
      );

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$1, equals(testTask.data.estimate));
      expect(result?.$2, isNotEmpty);
      expect(result?.$2.containsKey(linkedEntry.id), isTrue);
      verify(() => mockJournalDb.getTaskEstimatesByIds({taskId})).called(1);
      verify(() => mockJournalDb.getBulkLinkedTimeSpans({taskId})).called(1);
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

      when(
        () => mockJournalDb.getTaskEstimatesByIds({taskId}),
      ).thenAnswer((_) async => {taskId: testTask.data.estimate});
      when(
        () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
      ).thenAnswer(
        (_) async => {
          taskId: [
            (
              id: testTextEntry.id,
              dateFrom: testTextEntry.meta.dateFrom,
              dateTo: testTextEntry.meta.dateTo,
            ),
          ],
        },
      );

      // Act
      final result = await repository.getTaskProgressData(id: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result?.$2.containsKey(linkedTask.id), isFalse);
      expect(result?.$2.containsKey(testTextEntry.id), isTrue);
      verify(() => mockJournalDb.getTaskEstimatesByIds({taskId})).called(1);
      verify(() => mockJournalDb.getBulkLinkedTimeSpans({taskId})).called(1);
    });

    test(
      'ignores audio entries when calculating duration to prevent double-counting',
      () async {
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

        when(
          () => mockJournalDb.getTaskEstimatesByIds({taskId}),
        ).thenAnswer((_) async => {taskId: testTask.data.estimate});
        when(
          () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
        ).thenAnswer(
          (_) async => {
            taskId: [
              (
                id: testTextEntry.id,
                dateFrom: testTextEntry.meta.dateFrom,
                dateTo: testTextEntry.meta.dateTo,
              ),
            ],
          },
        );

        // Act
        final result = await repository.getTaskProgressData(id: taskId);

        // Assert
        expect(result, isNotNull);
        // Audio entry should be excluded (to prevent double-counting meeting time)
        expect(result?.$2.containsKey(audioEntry.id), isFalse);
        // Text entry should still be included
        expect(result?.$2.containsKey(testTextEntry.id), isTrue);
        verify(() => mockJournalDb.getTaskEstimatesByIds({taskId})).called(1);
        verify(() => mockJournalDb.getBulkLinkedTimeSpans({taskId})).called(1);
      },
    );

    test(
      'batches concurrent task progress lookups across multiple task ids',
      () {
        fakeAsync((async) {
          final otherTask = Task(
            meta: Metadata(
              id: 'other-task-id',
              createdAt: DateTime(2022, 7, 8, 9),
              dateFrom: DateTime(2022, 7, 8, 9),
              dateTo: DateTime(2022, 7, 8, 10),
              updatedAt: DateTime(2022, 7, 8, 10),
            ),
            entryText: const EntryText(plainText: 'other task'),
            data: testTask.data.copyWith(title: 'Other Task'),
          );

          when(
            () => mockJournalDb.getTaskEstimatesByIds({
              testTask.id,
              otherTask.id,
            }),
          ).thenAnswer(
            (_) async => {
              testTask.id: testTask.data.estimate,
              otherTask.id: otherTask.data.estimate,
            },
          );
          when(
            () => mockJournalDb.getBulkLinkedTimeSpans({
              testTask.id,
              otherTask.id,
            }),
          ).thenAnswer(
            (_) async => {
              testTask.id: [
                (
                  id: testTextEntry.id,
                  dateFrom: testTextEntry.meta.dateFrom,
                  dateTo: testTextEntry.meta.dateTo,
                ),
              ],
              otherTask.id: const <LinkedEntityTimeSpan>[],
            },
          );

          (Duration?, Map<String, TimeRange>)? resultA;
          (Duration?, Map<String, TimeRange>)? resultB;

          repository
              .getTaskProgressData(id: testTask.id)
              .then((value) => resultA = value);
          repository
              .getTaskProgressData(id: otherTask.id)
              .then((value) => resultB = value);

          async.flushMicrotasks();

          // Assert both futures actually resolved before dereferencing record
          // fields; otherwise the null-safe `?.` access below would silently
          // pass on an undrained microtask queue.
          expect(resultA, isNotNull);
          expect(resultB, isNotNull);
          final (estimateA, rangesA) = resultA!;
          final (estimateB, rangesB) = resultB!;
          expect(estimateA, equals(testTask.data.estimate));
          expect(rangesA.containsKey(testTextEntry.id), isTrue);
          expect(estimateB, equals(otherTask.data.estimate));
          expect(rangesB, isEmpty);
          verify(
            () => mockJournalDb.getTaskEstimatesByIds({
              testTask.id,
              otherTask.id,
            }),
          ).called(1);
          verify(
            () => mockJournalDb.getBulkLinkedTimeSpans({
              testTask.id,
              otherTask.id,
            }),
          ).called(1);
          verifyNever(() => mockJournalDb.journalEntityById(any()));
          verifyNever(() => mockJournalDb.getLinkedEntities(any()));
        });
      },
    );

    test(
      'dedups in-flight requests for the same id, hitting the db only once',
      () {
        fakeAsync((async) {
          final taskId = testTask.id;
          when(
            () => mockJournalDb.getTaskEstimatesByIds({taskId}),
          ).thenAnswer((_) async => {taskId: testTask.data.estimate});
          when(
            () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
          ).thenAnswer(
            (_) async => {taskId: const <LinkedEntityTimeSpan>[]},
          );

          // Two synchronous lookups for the same id, before the batch flushes:
          // the second must reuse the in-flight future of the first.
          final futureA = repository.getTaskProgressData(id: taskId);
          final futureB = repository.getTaskProgressData(id: taskId);

          (Duration?, Map<String, TimeRange>)? resultA;
          (Duration?, Map<String, TimeRange>)? resultB;
          futureA.then((value) => resultA = value);
          futureB.then((value) => resultB = value);

          async.flushMicrotasks();

          expect(resultA, isNotNull);
          expect(resultB, isNotNull);
          expect(resultA!.$1, equals(testTask.data.estimate));
          expect(resultB!.$1, equals(testTask.data.estimate));
          // Same cached future, so the db sees the id only once.
          verify(
            () => mockJournalDb.getTaskEstimatesByIds({taskId}),
          ).called(1);
          verify(
            () => mockJournalDb.getBulkLinkedTimeSpans({taskId}),
          ).called(1);
        });
      },
    );

    test(
      'propagates the batch error to every pending waiter when the db throws',
      () {
        fakeAsync((async) {
          final taskId = testTask.id;
          final failure = Exception('estimates lookup failed');
          when(
            () => mockJournalDb.getTaskEstimatesByIds({taskId}),
          ).thenThrow(failure);

          Object? errorA;
          Object? errorB;
          repository.getTaskProgressData(id: taskId).catchError((Object e) {
            errorA = e;
            return null;
          });
          // Second waiter on the same id rides the shared in-flight future and
          // must observe the same error.
          repository.getTaskProgressData(id: taskId).catchError((Object e) {
            errorB = e;
            return null;
          });

          async.flushMicrotasks();

          expect(errorA, same(failure));
          expect(errorB, same(failure));
          // getBulkLinkedTimeSpans is never reached because the first await
          // throws before it.
          verifyNever(() => mockJournalDb.getBulkLinkedTimeSpans(any()));
        });
      },
    );
  });
}
