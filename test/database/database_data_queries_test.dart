// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb data queries - ', () {
    // The expensive ~40-step migration ladder runs once for the whole file;
    // each test re-uses the instance and starts clean via clearAllTables.
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
      await getIt.reset();
    });

    group('Day plan queries -', () {
      test(
        'day plan reads respect the private flag without a config subquery',
        () async {
          final publicPlanDate = DateTime(2026, 1, 15);
          final privatePlanDate = publicPlanDate.add(const Duration(days: 1));
          final publicPlan = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(publicPlanDate),
              createdAt: publicPlanDate,
              updatedAt: publicPlanDate,
              dateFrom: publicPlanDate,
              dateTo: publicPlanDate.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: publicPlanDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );
          final privatePlan = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(privatePlanDate),
              createdAt: privatePlanDate,
              updatedAt: privatePlanDate,
              dateFrom: privatePlanDate,
              dateTo: privatePlanDate.add(const Duration(days: 1)),
              private: true,
            ),
            data: DayPlanData(
              planDate: privatePlanDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicPlan));
          await db!.upsertJournalDbEntity(toDbEntity(privatePlan));

          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          expect(await db!.getDayPlanById(publicPlan.meta.id), isNotNull);
          expect(await db!.getDayPlanById(privatePlan.meta.id), isNull);

          final visiblePlans = await db!.getDayPlansInRange(
            rangeStart: publicPlanDate.subtract(const Duration(days: 1)),
            rangeEnd: privatePlanDate.add(const Duration(days: 2)),
          );

          expect(visiblePlans.map((e) => e.meta.id), [publicPlan.meta.id]);

          // Enable private flag → allPrivate path returns both plans
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: true,
            ),
          );

          expect(await db!.getDayPlanById(privatePlan.meta.id), isNotNull);

          final allPlans = await db!.getDayPlansInRange(
            rangeStart: publicPlanDate.subtract(const Duration(days: 1)),
            rangeEnd: privatePlanDate.add(const Duration(days: 2)),
          );
          expect(allPlans, hasLength(2));
        },
      );

      test('getDayPlansByIds returns empty list for empty input', () async {
        expect(await db!.getDayPlansByIds(const <String>[]), isEmpty);
      });

      test(
        'getDayPlansByIds batch-fetches matching plans and honors private flag',
        () async {
          final baseDate = DateTime(2026, 2, 10);
          final publicA = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(baseDate),
              createdAt: baseDate,
              updatedAt: baseDate,
              dateFrom: baseDate,
              dateTo: baseDate.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: baseDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );
          final publicB = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(baseDate.add(const Duration(days: 1))),
              createdAt: baseDate.add(const Duration(days: 1)),
              updatedAt: baseDate.add(const Duration(days: 1)),
              dateFrom: baseDate.add(const Duration(days: 1)),
              dateTo: baseDate.add(const Duration(days: 2)),
            ),
            data: DayPlanData(
              planDate: baseDate.add(const Duration(days: 1)),
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );
          final privatePlan = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(baseDate.add(const Duration(days: 2))),
              createdAt: baseDate.add(const Duration(days: 2)),
              updatedAt: baseDate.add(const Duration(days: 2)),
              dateFrom: baseDate.add(const Duration(days: 2)),
              dateTo: baseDate.add(const Duration(days: 3)),
              private: true,
            ),
            data: DayPlanData(
              planDate: baseDate.add(const Duration(days: 2)),
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicA));
          await db!.upsertJournalDbEntity(toDbEntity(publicB));
          await db!.upsertJournalDbEntity(toDbEntity(privatePlan));

          // Filtered path: privateFlag = false → private plan is excluded
          // from the batch, missing ids are silently skipped, and the two
          // public plans come back.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final filtered = await db!.getDayPlansByIds([
            publicA.meta.id,
            publicB.meta.id,
            privatePlan.meta.id,
            'dayplan-does-not-exist',
          ]);
          expect(
            filtered.map((e) => e.meta.id).toSet(),
            {publicA.meta.id, publicB.meta.id},
          );

          // allPrivate path: privateFlag = true → all three plans come back.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: true,
            ),
          );

          final all = await db!.getDayPlansByIds([
            publicA.meta.id,
            publicB.meta.id,
            privatePlan.meta.id,
          ]);
          expect(
            all.map((e) => e.meta.id).toSet(),
            {publicA.meta.id, publicB.meta.id, privatePlan.meta.id},
          );
        },
      );
    });

    group('Time-range queries -', () {
      test('getMeasurementsByType filters by type and range', () async {
        final measurementDate = DateTime(2024, 3, 5);
        final inRangeWater = testMeasurementChocolateEntry.copyWith(
          meta: testMeasurementChocolateEntry.meta.copyWith(
            id: 'measurement-water',
            createdAt: measurementDate,
            updatedAt: measurementDate,
            dateFrom: measurementDate,
            dateTo: measurementDate,
          ),
          data: testMeasurementChocolateEntry.data.copyWith(
            dataTypeId: measurableWater.id,
            dateFrom: measurementDate,
            dateTo: measurementDate,
          ),
        );
        final oldMeasurementDate = DateTime(2023, 12, 1);
        final outOfRangeWater = inRangeWater.copyWith(
          meta: inRangeWater.meta.copyWith(
            id: 'measurement-water-old',
            createdAt: oldMeasurementDate,
            updatedAt: oldMeasurementDate,
            dateFrom: oldMeasurementDate,
            dateTo: oldMeasurementDate,
          ),
        );
        final otherType = inRangeWater.copyWith(
          meta: inRangeWater.meta.copyWith(
            id: 'measurement-chocolate',
          ),
          data: inRangeWater.data.copyWith(dataTypeId: measurableChocolate.id),
        );

        await db!.updateJournalEntity(inRangeWater);
        await db!.updateJournalEntity(outOfRangeWater);
        await db!.updateJournalEntity(otherType);

        final rangeStart = DateTime(2024, 3, 1);
        final rangeEnd = DateTime(2024, 3, 31);
        final results = await db!.getMeasurementsByType(
          type: measurableWater.id,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(results, hasLength(1));
        expect(results.first.meta.id, 'measurement-water');
      });

      test('getHabitCompletionsByHabitId filters correctly', () async {
        final habitId = habitFlossing.id;
        final inRange = buildHabitCompletionEntry(
          id: 'habit-complete-1',
          habitId: habitId,
          timestamp: DateTime(2024, 4, 15),
        );
        final outsideRange = buildHabitCompletionEntry(
          id: 'habit-complete-old',
          habitId: habitId,
          timestamp: DateTime(2024, 1, 1),
        );
        final otherHabit = buildHabitCompletionEntry(
          id: 'habit-other',
          habitId: 'other-habit',
          timestamp: DateTime(2024, 4, 16),
        );

        await db!.updateJournalEntity(inRange);
        await db!.updateJournalEntity(outsideRange);
        await db!.updateJournalEntity(otherHabit);

        final rangeStart = DateTime(2024, 4, 1);
        final rangeEnd = DateTime(2024, 4, 30);
        final results = await db!.getHabitCompletionsByHabitId(
          habitId: habitId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(results.map((e) => e.meta.id), equals(['habit-complete-1']));
      });

      test(
        'habit completion reads return the latest write for each habit day',
        () async {
          final habitId = habitFlossing.id;
          final day = DateTime(2024, 4, 15, 21);
          final older = buildHabitCompletionEntry(
            id: 'habit-complete-older-success',
            habitId: habitId,
            timestamp: day,
            writtenAt: DateTime(2024, 4, 15, 22),
            completionType: HabitCompletionType.success,
          );
          final newer = buildHabitCompletionEntry(
            id: 'habit-complete-newer-fail',
            habitId: habitId,
            timestamp: day,
            writtenAt: DateTime(2024, 4, 15, 23),
            completionType: HabitCompletionType.fail,
          );

          // Insert newest first so the query must choose by stored recency,
          // not insertion order.
          await db!.upsertJournalDbEntity(toDbEntity(newer));
          await db!.upsertJournalDbEntity(toDbEntity(older));

          final rangeStart = DateTime(2024, 4);
          final rangeEnd = DateTime(2024, 4, 30);
          final byHabit = await db!.getHabitCompletionsByHabitId(
            habitId: habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );
          final inRange = await db!.getHabitCompletionRecordsInRange(
            rangeStart: rangeStart,
          );

          expect(byHabit, hasLength(1));
          expect(byHabit.single.meta.id, 'habit-complete-newer-fail');
          expect(
            (byHabit.single as HabitCompletionEntry).data.completionType,
            HabitCompletionType.fail,
          );

          // The record read carries no entity id, so the winning row is
          // identified by the fields it does project — which is exactly what
          // the consumers use.
          expect(inRange, hasLength(1));
          expect(inRange.single.habitId, habitId);
          expect(inRange.single.completionType, HabitCompletionType.fail);
        },
      );

      test(
        'getHabitCompletionRecordsInRange preserves write-recency tie breakers',
        () async {
          final habitId = habitFlossing.id;
          final day = DateTime(2024, 4, 16, 21);
          final updatedAt = DateTime(2024, 4, 16, 23);
          final earlierCreatedAt = JournalEntity.habitCompletion(
            meta: Metadata(
              id: 'habit-created-earlier',
              createdAt: DateTime(2024, 4, 16, 21),
              updatedAt: updatedAt,
              dateFrom: day,
              dateTo: DateTime(2024, 4, 16, 21),
              private: false,
            ),
            data: HabitCompletionData(
              habitId: habitId,
              dateFrom: day,
              dateTo: DateTime(2024, 4, 16, 21),
              completionType: HabitCompletionType.success,
            ),
          );
          final laterCreatedAt = JournalEntity.habitCompletion(
            meta: Metadata(
              id: 'habit-created-later',
              createdAt: DateTime(2024, 4, 16, 22),
              updatedAt: updatedAt,
              dateFrom: day,
              dateTo: DateTime(2024, 4, 16, 21),
              private: false,
            ),
            data: HabitCompletionData(
              habitId: habitId,
              dateFrom: day,
              dateTo: DateTime(2024, 4, 16, 21),
              completionType: HabitCompletionType.fail,
            ),
          );

          await db!.updateJournalEntity(earlierCreatedAt);
          await db!.updateJournalEntity(laterCreatedAt);

          final result = await db!.getHabitCompletionRecordsInRange(
            rangeStart: DateTime(2024, 4),
          );

          expect(result, hasLength(1));
          expect(result.single.habitId, habitId);
          expect(result.single.completionType, HabitCompletionType.fail);
        },
      );

      test(
        'getHabitCompletionRecordsInRange decodes an unknown completion type '
        'as null rather than throwing',
        () async {
          // Forward compatibility: a newer peer can sync a completion type
          // this build does not know. Decoding to null keeps it in the same
          // bucket as a legacy entry — recorded and streak-extending, but not
          // counted as a success — rather than throwing and taking out the
          // whole heatmap for one unrecognised row.
          const serialized =
              '{"data":{"habitId":"habit-future",'
              '"completionType":"teleported"},'
              '"meta":{"id":"future-type",'
              '"dateFrom":"2024-04-16T21:00:00.000"}}';
          await db!.customStatement(
            'INSERT INTO journal (id, created_at, updated_at, date_from, '
            'date_to, type, subtype, serialized, deleted, starred, private, '
            'task, flag) VALUES (?1, 1713000000, 1713000000, 1713000000, '
            '1713000000, ?2, ?3, ?4, 0, 0, 0, 0, 0)',
            ['future-type', 'HabitCompletionEntry', '', serialized],
          );

          final result = await db!.getHabitCompletionRecordsInRange(
            rangeStart: DateTime(2024),
          );

          final future = result.where((r) => r.habitId == 'habit-future');
          expect(future, hasLength(1));
          expect(
            future.single.completionType,
            isNull,
            reason: 'an unrecognised type must decode to null, not throw',
          );
        },
      );

      test(
        'getHabitCompletionRecordsInRange reports the recorded wall-clock day, '
        'not the day the epoch column reconstructs to',
        () async {
          // `date_from` is stored as a Unix epoch and reconstructed in the
          // reader's zone; `meta.dateFrom` is a naive local timestamp that
          // keeps the wall clock it was recorded with. A completion entered at
          // 23:30 in Berlin and read later in Auckland reconstructs from the
          // column as 11:30 the NEXT day, which would move it between heatmap
          // cells, "completed today" buckets and streak windows.
          //
          // Rather than switch the test process's timezone, the two are given
          // deliberately different values: whichever one the projection reads
          // is then unambiguous.
          const serialized =
              '{"data":{"habitId":"habit-tz","completionType":"success"},'
              '"meta":{"id":"tz-row","dateFrom":"2024-04-18T23:30:00.000"}}';
          await db!.customStatement(
            'INSERT INTO journal (id, created_at, updated_at, date_from, '
            'date_to, type, subtype, serialized, deleted, starred, private, '
            'task, flag) VALUES (?1, 1713470000, 1713470000, 1713480000, '
            '1713480000, ?2, ?3, ?4, 0, 0, 0, 0, 0)',
            ['tz-row', 'HabitCompletionEntry', '', serialized],
          );

          final result = await db!.getHabitCompletionRecordsInRange(
            rangeStart: DateTime(2024),
          );
          final row = result.singleWhere((r) => r.habitId == 'habit-tz');

          expect(
            row.dateFrom,
            DateTime.parse('2024-04-18T23:30:00.000'),
            reason:
                'the projection must carry the recorded meta.dateFrom, '
                'not the value the date_from epoch column reconstructs to',
          );
        },
      );

      test('getQuantitativeByType filters correctly', () async {
        final weightEntry = buildQuantitativeEntry(
          id: 'weight-1',
          dataType: 'weight',
          timestamp: DateTime(2024, 5, 10),
        );
        final weightOutsideRange = buildQuantitativeEntry(
          id: 'weight-old',
          dataType: 'weight',
          timestamp: DateTime(2023, 5, 10),
        );
        final otherType = buildQuantitativeEntry(
          id: 'blood-pressure',
          dataType: 'bp',
          timestamp: DateTime(2024, 5, 10),
        );

        await db!.updateJournalEntity(weightEntry);
        await db!.updateJournalEntity(weightOutsideRange);
        await db!.updateJournalEntity(otherType);

        final quantStart = DateTime(2024, 5, 1);
        final quantEnd = DateTime(2024, 5, 31);
        final results = await db!.getQuantitativeByType(
          type: 'weight',
          rangeStart: quantStart,
          rangeEnd: quantEnd,
        );

        expect(results.map((e) => e.meta.id), equals(['weight-1']));
      });

      test('latestQuantitativeByType returns most recent entry', () async {
        final older = buildQuantitativeEntry(
          id: 'quant-old',
          dataType: 'coverage',
          timestamp: DateTime(2024, 6, 1),
        );
        final newer = buildQuantitativeEntry(
          id: 'quant-new',
          dataType: 'coverage',
          timestamp: DateTime(2024, 6, 2),
        );
        await db!.updateJournalEntity(older);
        await db!.updateJournalEntity(newer);

        final result = await db!.latestQuantitativeByType('coverage');
        expect(result, isNotNull);
        expect(result!.meta.id, 'quant-new');
      });

      test('latestQuantitativeByType returns null when none exist', () async {
        DevLogger.clear();

        final result = await db!.latestQuantitativeByType('missing-type');
        expect(result, isNull);
        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('no result for missing-type'),
          ),
          isTrue,
        );
      });

      test('latestWorkout returns most recent workout', () async {
        final first = buildWorkoutEntry(
          id: 'workout-1',
          start: DateTime(2024, 7, 1, 8),
          end: DateTime(2024, 7, 1, 9),
        );
        final latest = buildWorkoutEntry(
          id: 'workout-2',
          start: DateTime(2024, 7, 2, 7),
          end: DateTime(2024, 7, 2, 8),
        );
        await db!.updateJournalEntity(first);
        await db!.updateJournalEntity(latest);

        final result = await db!.latestWorkout();
        expect(result, isNotNull);
        expect(result!.meta.id, 'workout-2');
      });

      test('latestWorkout returns null when none exist', () async {
        DevLogger.clear();

        final result = await db!.latestWorkout();
        expect(result, isNull);
        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('no workout found'),
          ),
          isTrue,
        );
      });
    });

    group('getSurveyCompletionsByType -', () {
      test('returns survey entries matching type in range', () async {
        final base = DateTime(2024, 11, 7, 10);
        final taskResult = RPTaskResult(identifier: 'phq9')
          ..startDate = base
          ..endDate = base.add(const Duration(minutes: 10));
        final surveyEntry = JournalEntity.survey(
          meta: Metadata(
            id: 'survey-phq9-1',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base.add(const Duration(minutes: 10)),
            starred: false,
            private: false,
          ),
          data: SurveyData(
            taskResult: taskResult,
            scoreDefinitions: const {
              'Total': {'q1', 'q2'},
            },
            calculatedScores: const {'Total': 5},
          ),
        );
        await db!.updateJournalEntity(surveyEntry);

        final results = await db!.getSurveyCompletionsByType(
          type: 'phq9',
          rangeStart: base.subtract(const Duration(hours: 1)),
          rangeEnd: base.add(const Duration(hours: 1)),
        );
        expect(results.map((e) => e.meta.id), contains('survey-phq9-1'));
      });

      test('returns empty list when none exist', () async {
        final base = DateTime(2024, 11, 7, 11);
        final results = await db!.getSurveyCompletionsByType(
          type: 'nonexistent-survey',
          rangeStart: base,
          rangeEnd: base.add(const Duration(hours: 1)),
        );
        expect(results, isEmpty);
      });
    });

    group('getWorkouts -', () {
      test(
        'returns workouts fully inside the range, newest first, and '
        'excludes deleted or out-of-range entries',
        () async {
          final rangeStart = DateTime(2024, 5);
          final rangeEnd = DateTime(2024, 5, 8);

          await db!.updateJournalEntity(
            buildWorkoutEntry(
              id: 'workout-early',
              start: DateTime(2024, 5, 2, 8),
              end: DateTime(2024, 5, 2, 9),
            ),
          );
          await db!.updateJournalEntity(
            buildWorkoutEntry(
              id: 'workout-late',
              start: DateTime(2024, 5, 6, 18),
              end: DateTime(2024, 5, 6, 19),
            ),
          );
          await db!.updateJournalEntity(
            buildWorkoutEntry(
              id: 'workout-outside',
              start: DateTime(2024, 4, 20, 8),
              end: DateTime(2024, 4, 20, 9),
            ),
          );
          await db!.updateJournalEntity(
            buildWorkoutEntry(
              id: 'workout-deleted',
              start: DateTime(2024, 5, 3, 8),
              end: DateTime(2024, 5, 3, 9),
              deletedAt: DateTime(2024, 5, 4),
            ),
          );

          final workouts = await db!.getWorkouts(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          );

          // date_from DESC ordering: latest workout first.
          expect(
            workouts.map((w) => w.meta.id).toList(),
            ['workout-late', 'workout-early'],
          );
          expect(workouts.first, isA<WorkoutEntry>());
        },
      );

      test('returns empty list when no workouts fall in range', () async {
        final workouts = await db!.getWorkouts(
          rangeStart: DateTime(2030),
          rangeEnd: DateTime(2030, 2),
        );
        expect(workouts, isEmpty);
      });
    });
  });
}
