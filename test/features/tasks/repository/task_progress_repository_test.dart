import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

/// Builds a [JournalEntry] whose time span runs from [from] to [to].
///
/// Used across the `sumTimeSpentFromEntities` cases so each test only states
/// the id and the interval it cares about instead of re-spelling a full
/// [Metadata] block.
JournalEntry _makeJournalEntry(String id, DateTime from, DateTime to) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: from,
      dateFrom: from,
      dateTo: to,
      updatedAt: to,
    ),
    entryText: EntryText(plainText: id),
  );
}

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
        data: const AiResponseData(
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

    test('sums multiple non-overlapping text entries correctly', () {
      // Arrange
      final textEntry1 = _makeJournalEntry(
        'text-entry-1',
        DateTime(2022, 7, 7, 9),
        DateTime(2022, 7, 7, 10), // 1 hour
      );
      final textEntry2 = _makeJournalEntry(
        'text-entry-2',
        DateTime(2022, 7, 7, 14),
        DateTime(2022, 7, 7, 14, 30), // 30 min
      );
      final entities = [textEntry1, textEntry2];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - 1 hour + 30 min = 1.5 hours (no overlap)
      expect(total, equals(const Duration(hours: 1, minutes: 30)));
    });

    test('merges overlapping entries to prevent double-counting', () {
      // Arrange - gym trip containing a fitness entry (like the Winter Walk bug)
      final gymTrip = _makeJournalEntry(
        'gym-trip',
        DateTime(2022, 7, 7, 10),
        DateTime(2022, 7, 7, 11, 30), // 1.5 hours
      );
      final fitnessEntry = _makeJournalEntry(
        'fitness-entry',
        DateTime(2022, 7, 7, 10, 30),
        DateTime(2022, 7, 7, 11, 15), // 45 min, inside gym trip
      );
      final entities = [gymTrip, fitnessEntry];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - should be 1.5 hours (union), NOT 2h 15m (simple sum)
      expect(total, equals(const Duration(hours: 1, minutes: 30)));
    });

    test('merges partially overlapping entries correctly', () {
      // Arrange - two entries that partially overlap
      final entry1 = _makeJournalEntry(
        'entry-1',
        DateTime(2022, 7, 7, 10),
        DateTime(2022, 7, 7, 11, 30), // 10:00-11:30
      );
      final entry2 = _makeJournalEntry(
        'entry-2',
        DateTime(2022, 7, 7, 11),
        DateTime(2022, 7, 7, 12), // 11:00-12:00
      );
      final entities = [entry1, entry2];

      // Act
      final total = TaskProgressRepository.sumTimeSpentFromEntities(entities);

      // Assert - union is 10:00-12:00 = 2 hours, not 1.5h + 1h = 2.5h
      expect(total, equals(const Duration(hours: 2)));
    });
  });

  group('getTaskProgress', () {
    test('calculates progress correctly with no time ranges', () {
      // Arrange
      final timeRanges = <String, TimeRange>{};
      const estimate = Duration(hours: 2);

      // Act
      final result = repository.getTaskProgress(
        timeRanges: timeRanges,
        estimate: estimate,
      );

      // Assert
      expect(result.progress, Duration.zero);
      expect(result.estimate, estimate);
    });

    test('calculates progress correctly with non-overlapping time ranges', () {
      // Arrange
      final timeRanges = <String, TimeRange>{
        'entry1': TimeRange(
          start: DateTime(2022, 7, 7, 9),
          end: DateTime(2022, 7, 7, 9, 30), // 30 min
        ),
        'entry2': TimeRange(
          start: DateTime(2022, 7, 7, 14),
          end: DateTime(2022, 7, 7, 14, 45), // 45 min
        ),
      };
      const estimate = Duration(hours: 2);
      const expectedProgress = Duration(minutes: 75);

      // Act
      final result = repository.getTaskProgress(
        timeRanges: timeRanges,
        estimate: estimate,
      );

      // Assert
      expect(result.progress, expectedProgress);
      expect(result.estimate, estimate);
    });

    test('uses zero for estimate when null is provided', () {
      // Arrange
      final timeRanges = <String, TimeRange>{
        'entry1': TimeRange(
          start: DateTime(2022, 7, 7, 9),
          end: DateTime(2022, 7, 7, 9, 30), // 30 min
        ),
      };

      // Act
      final result = repository.getTaskProgress(timeRanges: timeRanges);

      // Assert
      expect(result.progress, const Duration(minutes: 30));
      expect(result.estimate, Duration.zero);
    });

    test('merges overlapping time ranges to prevent double-counting', () {
      // Arrange - overlapping entries like a gym trip containing a fitness entry
      final timeRanges = <String, TimeRange>{
        'gym-trip': TimeRange(
          start: DateTime(2022, 7, 7, 10),
          end: DateTime(2022, 7, 7, 11, 30), // 1.5 hours
        ),
        'fitness-entry': TimeRange(
          start: DateTime(2022, 7, 7, 10, 30),
          end: DateTime(2022, 7, 7, 11, 15), // 45 min, fully inside gym trip
        ),
      };
      const estimate = Duration(hours: 3);

      // Act
      final result = repository.getTaskProgress(
        timeRanges: timeRanges,
        estimate: estimate,
      );

      // Assert - should be 1.5 hours (union), not 2.25 hours (simple sum)
      expect(result.progress, const Duration(hours: 1, minutes: 30));
      expect(result.estimate, estimate);
    });

    test('merges partially overlapping time ranges correctly', () {
      // Arrange - two entries that partially overlap
      final timeRanges = <String, TimeRange>{
        'entry1': TimeRange(
          start: DateTime(2022, 7, 7, 10),
          end: DateTime(2022, 7, 7, 11, 30), // 10:00-11:30
        ),
        'entry2': TimeRange(
          start: DateTime(2022, 7, 7, 11),
          end: DateTime(2022, 7, 7, 12), // 11:00-12:00
        ),
      };
      const estimate = Duration(hours: 3);

      // Act
      final result = repository.getTaskProgress(
        timeRanges: timeRanges,
        estimate: estimate,
      );

      // Assert - union is 10:00-12:00 = 2 hours, not 1.5h + 1h = 2.5h
      expect(result.progress, const Duration(hours: 2));
      expect(result.estimate, estimate);
    });
  });

  group('sumTimeSpentFromEntities — Glados properties', () {
    final base = DateTime.utc(2024, 3, 15, 8);

    JournalEntity entityFor(int seed) {
      final start = base.add(Duration(minutes: seed % 480));
      final end = start.add(Duration(minutes: 1 + (seed >> 4) % 120));
      final meta = Metadata(
        id: 'e-$seed',
        createdAt: start,
        updatedAt: start,
        dateFrom: start,
        dateTo: end,
      );
      switch (seed % 4) {
        case 0:
          return JournalEntity.journalEntry(meta: meta);
        case 1:
          // Excluded: structural task time must not count.
          return JournalEntity.task(
            meta: meta,
            data: TaskData(
              status: TaskStatus.open(
                id: 's-$seed',
                createdAt: start,
                utcOffset: 0,
              ),
              title: 't',
              statusHistory: const [],
              dateFrom: start,
              dateTo: end,
            ),
          );
        case 2:
          // Excluded: AI output is not logged work.
          return JournalEntity.aiResponse(
            meta: meta,
            data: const AiResponseData(
              model: 'm',
              systemMessage: '',
              prompt: '',
              thoughts: '',
              response: '',
            ),
          );
        default:
          // Excluded: audio duration would double-count logged time.
          return JournalEntity.journalAudio(
            meta: meta,
            data: AudioData(
              dateFrom: start,
              dateTo: end,
              duration: end.difference(start),
              audioFile: 'a.m4a',
              audioDirectory: '/audio',
            ),
          );
      }
    }

    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        12,
        glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      ),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'non-negative; bounded by the naive sum; excluded types contribute '
      'nothing; fully-contained intervals never increase the total',
      (seeds) {
        final entities = [for (final s in seeds) entityFor(s)];
        final counted = entities
            .where(
              (e) => e is! Task && e is! AiResponseEntry && e is! JournalAudio,
            )
            .toList();

        final result = TaskProgressRepository.sumTimeSpentFromEntities(
          entities,
        );

        // (a) Never negative.
        expect(result, greaterThanOrEqualTo(Duration.zero));

        // (c) Bounded by the naive (overlap-ignoring) sum of counted spans.
        final naive = counted.fold(
          Duration.zero,
          (sum, e) => sum + e.meta.dateTo.difference(e.meta.dateFrom),
        );
        expect(result, lessThanOrEqualTo(naive), reason: 'seeds=$seeds');

        // (d) Excluded types contribute nothing: filtering them out first
        // yields the identical union.
        expect(
          TaskProgressRepository.sumTimeSpentFromEntities(counted),
          result,
        );

        // (b) Adding an interval fully contained in an existing counted span
        // never increases the total.
        if (counted.isNotEmpty) {
          final host = counted.first;
          final contained = JournalEntity.journalEntry(
            meta: Metadata(
              id: 'contained',
              createdAt: host.meta.dateFrom,
              updatedAt: host.meta.dateFrom,
              dateFrom: host.meta.dateFrom,
              dateTo: host.meta.dateTo,
            ),
          );
          expect(
            TaskProgressRepository.sumTimeSpentFromEntities(
              [...entities, contained],
            ),
            result,
            reason: 'contained interval must not change the union',
          );
        }
      },
      tags: 'glados',
    );
  });

  group('buildTimeRanges — Glados properties', () {
    final base = DateTime.utc(2024, 3, 15, 8);

    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        10,
        glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      ),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'every unique span id appears exactly once with start/end preserved',
      (seeds) {
        final spans = <LinkedEntityTimeSpan>[
          for (final (i, seed) in seeds.indexed)
            (
              id: 'span-$i',
              dateFrom: base.add(Duration(minutes: seed % 480)),
              dateTo: base.add(Duration(minutes: seed % 480 + 1 + seed % 90)),
            ),
        ];

        final ranges = TaskProgressRepository.buildTimeRanges(spans);

        expect(ranges.keys.toSet(), {for (final s in spans) s.id});
        expect(ranges.length, spans.length);
        for (final span in spans) {
          expect(ranges[span.id]!.start, span.dateFrom, reason: span.id);
          expect(ranges[span.id]!.end, span.dateTo, reason: span.id);
        }
      },
      tags: 'glados',
    );

    test('duplicate ids: the later span wins (map overwrite)', () {
      final ranges = TaskProgressRepository.buildTimeRanges([
        (
          id: 'dup',
          dateFrom: base,
          dateTo: base.add(const Duration(minutes: 10)),
        ),
        (
          id: 'dup',
          dateFrom: base.add(const Duration(hours: 1)),
          dateTo: base.add(const Duration(hours: 2)),
        ),
      ]);

      expect(ranges, hasLength(1));
      expect(ranges['dup']!.start, base.add(const Duration(hours: 1)));
    });
  });
}
