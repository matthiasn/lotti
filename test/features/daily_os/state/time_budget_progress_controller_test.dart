import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late StreamController<Set<String>> updateStreamController;

  final testDate = DateTime(2026, 1, 15);
  final planId = dayPlanId(testDate);

  DayPlanEntry createTestPlan({
    List<PlannedBlock> plannedBlocks = const [],
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: planId,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: const DayPlanStatus.draft(),
        plannedBlocks: plannedBlocks,
      ),
    );
  }

  JournalEntity createTestEntry({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) {
    return JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(testDate);
    registerFallbackValue(
      const AsyncValue<List<TimeBudgetProgress>>.loading(),
    );
    // Register fallback for JournalEntity (used in createDbEntity mock)
    registerFallbackValue(
      JournalEntity.journalEntry(
        meta: Metadata(
          id: 'fallback',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
      ),
    );

    getIt.allowReassignment = true;
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockUpdateNotifications = MockUpdateNotifications();
    mockEntitiesCacheService = MockEntitiesCacheService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockPersistenceLogic.createDbEntity(any()))
        .thenAnswer((_) async => true);

    when(() => mockEntitiesCacheService.getCategoryById(any()))
        .thenReturn(null);

    when(() => mockDb.getJournalEntitiesForIds(any()))
        .thenAnswer((_) async => []);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  group('TimeBudgetProgressController', () {
    test('returns empty list when no blocks defined', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result, isEmpty);
    });

    test('calculates progress for block with no recorded time', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.length, equals(1));
      expect(result.first.plannedDuration, equals(const Duration(hours: 2)));
      expect(result.first.recordedDuration, equals(Duration.zero));
      expect(result.first.status, equals(BudgetProgressStatus.underBudget));
      expect(result.first.progressFraction, equals(0.0));
    });

    test('calculates progress when recording partial time', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      // 1 hour entry for the work category
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.length, equals(1));
      expect(result.first.recordedDuration, equals(const Duration(hours: 1)));
      expect(result.first.progressFraction, equals(0.5));
      expect(result.first.remainingDuration, equals(const Duration(hours: 1)));
      expect(result.first.status, equals(BudgetProgressStatus.underBudget));
    });

    test('returns nearLimit status when within 15 minutes of budget', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 10)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      // 50 minutes recorded (10 minutes remaining)
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 9, minutes: 50)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.first.status, equals(BudgetProgressStatus.nearLimit));
    });

    test('returns exhausted status when exactly at budget', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 10)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      // Exactly 60 minutes recorded
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.first.status, equals(BudgetProgressStatus.exhausted));
    });

    test('returns overBudget status when exceeding budget', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 10)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      // 90 minutes recorded (30 over budget)
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.first.status, equals(BudgetProgressStatus.overBudget));
      expect(result.first.isOverBudget, isTrue);
    });

    test('aggregates multiple entries for same category', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)), // 3 hours
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      final entries = [
        createTestEntry(
          id: 'entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        ),
        createTestEntry(
          id: 'entry-2',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 14)),
          dateTo: testDate.add(const Duration(hours: 15, minutes: 30)),
        ),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      // 1 hour + 1.5 hours = 2.5 hours = 150 minutes
      expect(
        result.first.recordedDuration,
        equals(const Duration(hours: 2, minutes: 30)),
      );
      expect(result.first.contributingEntries.length, equals(2));
    });

    test('aggregates multiple blocks for same category', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      // Should aggregate to one budget with 3 hours total
      expect(result.length, equals(1));
      expect(result.first.plannedDuration, equals(const Duration(hours: 3)));
      expect(result.first.blocks.length, equals(2));
    });

    test('handles multiple categories correctly', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-personal',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      final entries = [
        createTestEntry(
          id: 'entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        ),
        createTestEntry(
          id: 'entry-2',
          categoryId: 'cat-personal',
          dateFrom: testDate.add(const Duration(hours: 12)),
          dateTo: testDate.add(const Duration(hours: 12, minutes: 45)),
        ),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await container.read(
        timeBudgetProgressControllerProvider(date: testDate).future,
      );

      expect(result.length, equals(2));

      final workBudget = result.firstWhere((p) => p.categoryId == 'cat-work');
      expect(workBudget.recordedDuration, equals(const Duration(hours: 1)));

      final personalBudget =
          result.firstWhere((p) => p.categoryId == 'cat-personal');
      expect(
        personalBudget.recordedDuration,
        equals(const Duration(minutes: 45)),
      );
    });
  });

  group('dayBudgetStats', () {
    test('calculates total stats correctly', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)), // 2 hours
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-personal',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)), // 1 hour
          ),
        ],
      );
      when(() => mockDb.getDayPlanById(planId)).thenAnswer((_) async => plan);

      final entries = [
        createTestEntry(
          id: 'entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        ),
        createTestEntry(
          id: 'entry-2',
          categoryId: 'cat-personal',
          dateFrom: testDate.add(const Duration(hours: 12)),
          dateTo: testDate.add(const Duration(hours: 13, minutes: 30)),
        ),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await container.read(
        dayBudgetStatsProvider(date: testDate).future,
      );

      expect(result.totalPlanned, equals(const Duration(hours: 3)));
      expect(
        result.totalRecorded,
        equals(const Duration(hours: 2, minutes: 30)),
      );
      expect(result.budgetCount, equals(2));
      expect(result.overBudgetCount, equals(1)); // personal is over by 30 mins
      expect(result.isOverBudget, isFalse); // total is still under
    });
  });
}
