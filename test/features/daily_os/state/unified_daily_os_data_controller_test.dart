import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockDayPlanRepository extends Mock implements DayPlanRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockLoggingService mockLoggingService;
  late MockDayPlanRepository mockDayPlanRepository;
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

  JournalEntity createTestTask({
    required String id,
    required String? categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
    String title = 'Test Task',
    TaskStatus? status,
  }) {
    return JournalEntity.task(
      meta: Metadata(
        id: id,
        createdAt: dateFrom,
        updatedAt: dateFrom,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      ),
      data: TaskData(
        title: title,
        dateFrom: dateFrom,
        dateTo: dateTo,
        statusHistory: [],
        status: status ??
            TaskStatus.inProgress(
              id: 'status-1',
              createdAt: dateFrom,
              utcOffset: 0,
            ),
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(testDate);
    registerFallbackValue(
      const AsyncValue<List<TimeBudgetProgress>>.loading(),
    );
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
    mockLoggingService = MockLoggingService();
    mockDayPlanRepository = MockDayPlanRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

    when(() => mockPersistenceLogic.createDbEntity(any()))
        .thenAnswer((_) async => true);

    when(() => mockEntitiesCacheService.getCategoryById(any()))
        .thenReturn(null);

    when(() => mockDb.getJournalEntitiesForIds(any()))
        .thenAnswer((_) async => []);

    when(() => mockDb.linksForEntryIds(any())).thenAnswer((_) async => []);

    when(() => mockDb.getTasksDueOnOrBefore(any())).thenAnswer((_) async => []);
    when(() => mockDb.getTasksDueOn(any())).thenAnswer((_) async => []);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<LoggingService>(mockLoggingService);

    container = ProviderContainer(
      overrides: [
        dayPlanRepositoryProvider.overrideWithValue(mockDayPlanRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    getIt.reset();
  });

  group('UnifiedDailyOsDataController - Budget Progress', () {
    test('returns empty budgetProgress when no blocks defined', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.budgetProgress, isEmpty);
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      expect(progress.length, equals(1));
      expect(progress.first.plannedDuration, equals(const Duration(hours: 2)));
      expect(progress.first.recordedDuration, equals(Duration.zero));
      expect(progress.first.status, equals(BudgetProgressStatus.underBudget));
      expect(progress.first.progressFraction, equals(0.0));
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      expect(progress.length, equals(1));
      expect(progress.first.recordedDuration, equals(const Duration(hours: 1)));
      expect(progress.first.progressFraction, equals(0.5));
      expect(
        progress.first.remainingDuration,
        equals(const Duration(hours: 1)),
      );
      expect(progress.first.status, equals(BudgetProgressStatus.underBudget));
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(
        result.budgetProgress.first.status,
        equals(BudgetProgressStatus.nearLimit),
      );
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(
        result.budgetProgress.first.status,
        equals(BudgetProgressStatus.exhausted),
      );
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.status, equals(BudgetProgressStatus.overBudget));
      expect(progress.isOverBudget, isTrue);
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      // 1 hour + 1.5 hours = 2.5 hours = 150 minutes
      expect(
        progress.recordedDuration,
        equals(const Duration(hours: 2, minutes: 30)),
      );
      expect(progress.contributingEntries.length, equals(2));
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      // Should aggregate to one budget with 3 hours total
      expect(progress.length, equals(1));
      expect(progress.first.plannedDuration, equals(const Duration(hours: 3)));
      expect(progress.first.blocks.length, equals(2));
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      expect(progress.length, equals(2));

      final workBudget = progress.firstWhere((p) => p.categoryId == 'cat-work');
      expect(workBudget.recordedDuration, equals(const Duration(hours: 1)));

      final personalBudget =
          progress.firstWhere((p) => p.categoryId == 'cat-personal');
      expect(
        personalBudget.recordedDuration,
        equals(const Duration(minutes: 45)),
      );
    });

    test('uses linked parent category for budget attribution', () async {
      // Budget for work category
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Time entry with NO category, but linked to a task WITH cat-work category
      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null, // Entry has no category
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      // Parent task with work category
      final parentTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work', // Parent has the category
        dateFrom: testDate,
        dateTo: testDate,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      // Set up link from task to time entry
      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      // Should attribute the time to cat-work via the linked parent
      expect(progress.length, equals(1));
      expect(progress.first.categoryId, equals('cat-work'));
      expect(progress.first.recordedDuration, equals(const Duration(hours: 1)));
    });

    test('prefers linked parent category over entry direct category', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-personal',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Entry has personal category, but is linked to work task
      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: 'cat-personal', // Entry has personal category
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      final parentTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work', // Parent has work category
        dateFrom: testDate,
        dateTo: testDate,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      // Time should be attributed to work (parent) not personal (entry)
      final workBudget = progress.firstWhere((p) => p.categoryId == 'cat-work');
      expect(workBudget.recordedDuration, equals(const Duration(hours: 1)));

      final personalBudget =
          progress.firstWhere((p) => p.categoryId == 'cat-personal');
      expect(personalBudget.recordedDuration, equals(Duration.zero));
    });
  });

  group('UnifiedDailyOsDataController - Timeline Data', () {
    test('builds planned time slots from day plan blocks', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-personal',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final timeline = result.timelineData;
      expect(timeline.plannedSlots.length, equals(2));

      final firstSlot = timeline.plannedSlots[0];
      expect(firstSlot.categoryId, equals('cat-work'));
      expect(
        firstSlot.startTime,
        equals(testDate.add(const Duration(hours: 9))),
      );
      expect(
        firstSlot.endTime,
        equals(testDate.add(const Duration(hours: 11))),
      );
      expect(firstSlot.duration, equals(const Duration(hours: 2)));
    });

    test('builds actual time slots from calendar entries', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final timeline = result.timelineData;
      expect(timeline.actualSlots.length, equals(2));

      final firstSlot = timeline.actualSlots[0];
      expect(firstSlot.entry.meta.id, equals('entry-1'));
      expect(firstSlot.categoryId, equals('cat-work'));
      expect(firstSlot.duration, equals(const Duration(hours: 1)));

      final secondSlot = timeline.actualSlots[1];
      expect(secondSlot.entry.meta.id, equals('entry-2'));
      expect(
          secondSlot.duration, equals(const Duration(hours: 1, minutes: 30)));
    });

    test('excludes zero-duration entries from actual slots', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final entries = [
        createTestEntry(
          id: 'entry-normal',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        ),
        // Zero-duration entry (start == end)
        createTestEntry(
          id: 'entry-zero',
          categoryId: 'cat-personal',
          dateFrom: testDate.add(const Duration(hours: 14)),
          dateTo: testDate.add(const Duration(hours: 14)),
        ),
        createTestEntry(
          id: 'entry-another',
          categoryId: 'cat-health',
          dateFrom: testDate.add(const Duration(hours: 15)),
          dateTo: testDate.add(const Duration(hours: 16)),
        ),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final timeline = result.timelineData;
      // Only 2 slots - zero-duration entry excluded
      expect(timeline.actualSlots.length, equals(2));
      expect(
        timeline.actualSlots.map((s) => s.entry.meta.id),
        equals(['entry-normal', 'entry-another']),
      );
    });

    test('actual slots include linked parent reference', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      final parentTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final timeline = result.timelineData;
      expect(timeline.actualSlots.length, equals(1));

      final slot = timeline.actualSlots.first;
      expect(slot.linkedFrom, isNotNull);
      expect(slot.linkedFrom!.meta.id, equals('task-1'));
      expect(slot.categoryId, equals('cat-work')); // From parent
    });

    test('sorts planned and actual slots by start time', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-personal',
            startTime: testDate.add(const Duration(hours: 14)),
            endTime: testDate.add(const Duration(hours: 15)),
          ),
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final entries = [
        createTestEntry(
          id: 'entry-2',
          categoryId: 'cat-personal',
          dateFrom: testDate.add(const Duration(hours: 14)),
          dateTo: testDate.add(const Duration(hours: 15)),
        ),
        createTestEntry(
          id: 'entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        ),
      ];

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => entries);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final timeline = result.timelineData;

      // Planned slots should be sorted
      expect(timeline.plannedSlots[0].block.id, equals('block-1'));
      expect(timeline.plannedSlots[1].block.id, equals('block-2'));

      // Actual slots should be sorted
      expect(timeline.actualSlots[0].entry.meta.id, equals('entry-1'));
      expect(timeline.actualSlots[1].entry.meta.id, equals('entry-2'));
    });
  });

  group('UnifiedDailyOsDataController - Day Bounds Calculation', () {
    test('returns default bounds when no slots', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.timelineData.dayStartHour, equals(8));
      expect(result.timelineData.dayEndHour, equals(18));
    });

    test('calculates start hour from earliest planned slot', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 6)),
            endTime: testDate.add(const Duration(hours: 8)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 6 - 1 (buffer) = 5
      expect(result.timelineData.dayStartHour, equals(5));
    });

    test('calculates start hour from earliest actual slot', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 5)),
        dateTo: testDate.add(const Duration(hours: 6)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 5 - 1 (buffer) = 4
      expect(result.timelineData.dayStartHour, equals(4));
    });

    test('start hour does not go below 0', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(minutes: 30)),
            endTime: testDate.add(const Duration(hours: 2)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.timelineData.dayStartHour, equals(0));
    });

    test('calculates end hour from latest planned slot', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 20)),
            endTime: testDate.add(const Duration(hours: 22)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 22 + 1 (next hour) + 1 (buffer) = 24
      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('calculates end hour from latest actual slot', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 18)),
        dateTo: testDate.add(const Duration(hours: 20)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 20 + 1 (next hour) + 1 (buffer) = 22
      expect(result.timelineData.dayEndHour, equals(22));
    });

    test('end hour capped at 24', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 22)),
            endTime: testDate.add(const Duration(hours: 23, minutes: 30)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('handles midnight crossing - entry ends next day', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Entry that crosses midnight
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 23)),
        dateTo: testDate.add(const Duration(hours: 25)), // 1am next day
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // Should treat as hour 24 since it ends on next day
      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('handles midnight crossing - planned block ends next day', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 22)),
            endTime: testDate.add(const Duration(hours: 26)), // 2am next day
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // Should treat as hour 24 since it ends on next day
      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('uses earliest from both planned and actual slots', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 10)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Actual entry starts earlier than planned
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 7)),
        dateTo: testDate.add(const Duration(hours: 8)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // Should use 7 (from actual) not 10 (from planned)
      // 7 - 1 (buffer) = 6
      expect(result.timelineData.dayStartHour, equals(6));
    });

    test('uses latest from both planned and actual slots', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 17)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Actual entry ends later than planned
      final entry = createTestEntry(
        id: 'entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 18)),
        dateTo: testDate.add(const Duration(hours: 20)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // Should use 20 (from actual) not 17 (from planned)
      // 20 + 1 (next hour) + 1 (buffer) = 22
      expect(result.timelineData.dayEndHour, equals(22));
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
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

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

  group('UnifiedDailyOsDataController - Task Progress Items', () {
    test('builds taskProgressItems from entries linked to tasks', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Time entry linked to a task
      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
      );

      final parentTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'My Task',
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.taskProgressItems.length, equals(1));

      final taskProgress = progress.taskProgressItems.first;
      expect(taskProgress.task.data.title, equals('My Task'));
      expect(
        taskProgress.timeSpentOnDay,
        equals(const Duration(hours: 1, minutes: 30)),
      );
      expect(taskProgress.wasCompletedOnDay, isFalse);
    });

    test('aggregates multiple entries for same task', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 17)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Two time entries linked to the same task
      final timeEntry1 = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );
      final timeEntry2 = createTestEntry(
        id: 'time-entry-2',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 14)),
        dateTo: testDate.add(const Duration(hours: 15, minutes: 30)),
      );

      final parentTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'My Task',
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry1, timeEntry2]);

      when(() => mockDb.linksForEntryIds({'time-entry-1', 'time-entry-2'}))
          .thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
          EntryLink.basic(
            id: 'link-2',
            fromId: 'task-1',
            toId: 'time-entry-2',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.taskProgressItems.length, equals(1));
      expect(
        progress.taskProgressItems.first.timeSpentOnDay,
        equals(const Duration(hours: 2, minutes: 30)),
      );
    });

    test('marks task as completed on day when done today', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      // Task marked done TODAY
      final doneTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'Completed Task',
        status: TaskStatus.done(
          id: 'status-done',
          createdAt: testDate.add(const Duration(hours: 11)), // Done today
          utcOffset: 0,
        ),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [doneTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final taskProgress = result.budgetProgress.first.taskProgressItems.first;
      expect(taskProgress.wasCompletedOnDay, isTrue);
    });

    test('does not mark task as completed when done on different day',
        () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      // Task marked done YESTERDAY (not today)
      final doneTask = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'Previously Completed',
        status: TaskStatus.done(
          id: 'status-done',
          createdAt:
              testDate.subtract(const Duration(days: 1)), // Done yesterday
          utcOffset: 0,
        ),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [doneTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final taskProgress = result.budgetProgress.first.taskProgressItems.first;
      expect(taskProgress.wasCompletedOnDay, isFalse);
    });

    test('sorts tasks by time descending', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 17)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Entries for two different tasks
      final entry1 = createTestEntry(
        id: 'entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)), // 1 hour
      );
      final entry2 = createTestEntry(
        id: 'entry-2',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 11)),
        dateTo: testDate.add(const Duration(hours: 14)), // 3 hours
      );

      final task1 = createTestTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'Short Task',
      );
      final task2 = createTestTask(
        id: 'task-2',
        categoryId: 'cat-work',
        dateFrom: testDate,
        dateTo: testDate,
        title: 'Long Task',
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [entry1, entry2]);

      when(() => mockDb.linksForEntryIds({'entry-1', 'entry-2'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
          EntryLink.basic(
            id: 'link-2',
            fromId: 'task-2',
            toId: 'entry-2',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1', 'task-2'}))
          .thenAnswer((_) async => [task1, task2]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final items = result.budgetProgress.first.taskProgressItems;
      expect(items.length, equals(2));
      // Sorted by time descending: Long Task (3h) first, then Short Task (1h)
      expect(items[0].task.data.title, equals('Long Task'));
      expect(items[0].timeSpentOnDay, equals(const Duration(hours: 3)));
      expect(items[1].task.data.title, equals('Short Task'));
      expect(items[1].timeSpentOnDay, equals(const Duration(hours: 1)));
    });

    test('returns empty taskProgressItems when no tasks linked', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Entry with NO links to tasks
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

      // No links
      when(() => mockDb.linksForEntryIds({'entry-1'}))
          .thenAnswer((_) async => []);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.taskProgressItems, isEmpty);
      // But the entry still contributes to the budget
      expect(progress.recordedDuration, equals(const Duration(hours: 1)));
    });
  });

  group('UnifiedDailyOsDataController - Due Task Visibility', () {
    JournalEntity createDueTask({
      required String id,
      required String? categoryId,
      required DateTime? dueDate,
      String title = 'Due Task',
      TaskStatus? status,
      TaskPriority priority = TaskPriority.p2Medium,
    }) {
      return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: categoryId,
        ),
        data: TaskData(
          title: title,
          dateFrom: testDate,
          dateTo: testDate,
          due: dueDate,
          priority: priority,
          statusHistory: [],
          status: status ??
              TaskStatus.open(
                id: 'status-1',
                createdAt: testDate,
                utcOffset: 0,
              ),
        ),
      );
    }

    test('includes due tasks in budget even without tracked time', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Task due today with no tracked time
      final dueTask = createDueTask(
        id: 'task-due',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Task Due Today',
      );

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [dueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.taskProgressItems.length, equals(1));
      expect(progress.taskProgressItems.first.task.data.title,
          equals('Task Due Today'));
      expect(progress.taskProgressItems.first.timeSpentOnDay,
          equals(Duration.zero));
      expect(progress.taskProgressItems.first.isDueOrOverdue, isTrue);
    });

    test('deduplicates tasks with both tracked time and due date', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);

      // Time entry linked to task
      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: null,
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      // Task with due date AND tracked time
      final taskWithDue = createDueTask(
        id: 'task-1',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Task With Both',
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.linksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-1',
            fromId: 'task-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(() => mockDb.getJournalEntitiesForIds({'task-1'}))
          .thenAnswer((_) async => [taskWithDue]);

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [taskWithDue as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      // Should have only ONE entry (deduplicated)
      expect(progress.taskProgressItems.length, equals(1));
      // Should have the tracked time
      expect(progress.taskProgressItems.first.timeSpentOnDay,
          equals(const Duration(hours: 1)));
      // Should also have due date status
      expect(progress.taskProgressItems.first.isDueOrOverdue, isTrue);
    });

    test('creates synthetic budget for category with due tasks but no budget',
        () async {
      // Plan with NO budget for cat-unplanned
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 11)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Due task in a category WITHOUT a budget
      final dueTask = createDueTask(
        id: 'task-unplanned',
        categoryId: 'cat-unplanned',
        dueDate: testDate,
        title: 'Unplanned Due Task',
      );

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [dueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // Should have 2 budgets: the planned one and a synthetic one
      expect(result.budgetProgress.length, equals(2));

      final syntheticBudget = result.budgetProgress
          .firstWhere((b) => b.categoryId == 'cat-unplanned');
      expect(syntheticBudget.plannedDuration, equals(Duration.zero));
      expect(syntheticBudget.hasNoBudgetWarning, isTrue);
      expect(syntheticBudget.taskProgressItems.length, equals(1));
      expect(syntheticBudget.taskProgressItems.first.task.data.title,
          equals('Unplanned Due Task'));
    });

    test('sorts overdue tasks before due-today tasks', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Task due today
      final dueTodayTask = createDueTask(
        id: 'task-today',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Due Today',
      );

      // Overdue task (due yesterday)
      final overdueTask = createDueTask(
        id: 'task-overdue',
        categoryId: 'cat-work',
        dueDate: testDate.subtract(const Duration(days: 1)),
        title: 'Overdue',
      );

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [dueTodayTask as Task, overdueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final items = result.budgetProgress.first.taskProgressItems;
      expect(items.length, equals(2));
      // Overdue should come first
      expect(items[0].task.data.title, equals('Overdue'));
      expect(items[1].task.data.title, equals('Due Today'));
    });

    test('ignores due tasks without category', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Due task with NULL category
      final dueTask = createDueTask(
        id: 'task-no-cat',
        categoryId: null,
        dueDate: testDate,
        title: 'Task Without Category',
      );

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [dueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // No budgets should be created for tasks without category
      expect(result.budgetProgress, isEmpty);
    });

    test('future dates use getTasksDueOn instead of getTasksDueOnOrBefore',
        () async {
      // Use a date that is definitely in the future (1000 days from now)
      final futureDate = DateTime.now().add(const Duration(days: 1000));
      final futureDateStart =
          DateTime(futureDate.year, futureDate.month, futureDate.day);

      final plan = DayPlanEntry(
        meta: Metadata(
          id: dayPlanId(futureDateStart),
          createdAt: futureDateStart,
          updatedAt: futureDateStart,
          dateFrom: futureDateStart,
          dateTo: futureDateStart.add(const Duration(days: 1)),
        ),
        data: DayPlanData(
          planDate: futureDateStart,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-work',
              startTime: futureDateStart.add(const Duration(hours: 9)),
              endTime: futureDateStart.add(const Duration(hours: 12)),
            ),
          ],
        ),
      );

      when(() => mockDayPlanRepository.getOrCreateDayPlan(futureDateStart))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Task due on the future date
      final futureDueTask = JournalEntity.task(
        meta: Metadata(
          id: 'task-future',
          createdAt: futureDateStart,
          updatedAt: futureDateStart,
          dateFrom: futureDateStart,
          dateTo: futureDateStart,
          categoryId: 'cat-work',
        ),
        data: TaskData(
          title: 'Future Task',
          dateFrom: futureDateStart,
          dateTo: futureDateStart,
          due: futureDateStart,
          statusHistory: [],
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: futureDateStart,
            utcOffset: 0,
          ),
        ),
      );

      // Mock getTasksDueOn (should be called for future dates)
      when(() => mockDb.getTasksDueOn(futureDateStart))
          .thenAnswer((_) async => [futureDueTask as Task]);

      // Mock getTasksDueOnOrBefore (should NOT be called for future dates)
      // If it is called, it would return an overdue task that should not appear
      final overdueTask = JournalEntity.task(
        meta: Metadata(
          id: 'task-overdue',
          createdAt: futureDateStart,
          updatedAt: futureDateStart,
          dateFrom: futureDateStart,
          dateTo: futureDateStart,
          categoryId: 'cat-work',
        ),
        data: TaskData(
          title: 'Overdue Task That Should Not Appear',
          dateFrom: futureDateStart,
          dateTo: futureDateStart,
          due: futureDateStart.subtract(const Duration(days: 5)),
          statusHistory: [],
          status: TaskStatus.open(
            id: 'status-2',
            createdAt: futureDateStart,
            utcOffset: 0,
          ),
        ),
      );

      when(() => mockDb.getTasksDueOnOrBefore(futureDateStart)).thenAnswer(
          (_) async => [futureDueTask as Task, overdueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: futureDateStart).future,
      );

      final items = result.budgetProgress.first.taskProgressItems;

      // Should only have 1 task (the future task), not the overdue task
      expect(items.length, equals(1));
      expect(items[0].task.data.title, equals('Future Task'));

      // Verify getTasksDueOn was called (not getTasksDueOnOrBefore)
      verify(() => mockDb.getTasksDueOn(futureDateStart)).called(1);
    });

    test('sorts tasks by priority (P0 before P1 before P2 before P3)',
        () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Create tasks with different priorities
      final p3Task = createDueTask(
        id: 'task-p3',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Low Priority',
        priority: TaskPriority.p3Low,
      );

      final p0Task = createDueTask(
        id: 'task-p0',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Urgent Priority',
        priority: TaskPriority.p0Urgent,
      );

      final p2Task = createDueTask(
        id: 'task-p2',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Medium Priority',
      );

      final p1Task = createDueTask(
        id: 'task-p1',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'High Priority',
        priority: TaskPriority.p1High,
      );

      // Return in unsorted order
      when(() => mockDb.getTasksDueOnOrBefore(testDate)).thenAnswer((_) async =>
          [p3Task as Task, p0Task as Task, p2Task as Task, p1Task as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final items = result.budgetProgress.first.taskProgressItems;
      expect(items.length, equals(4));

      // Should be sorted P0 -> P1 -> P2 -> P3
      expect(items[0].task.data.title, equals('Urgent Priority'));
      expect(items[0].task.data.priority, equals(TaskPriority.p0Urgent));

      expect(items[1].task.data.title, equals('High Priority'));
      expect(items[1].task.data.priority, equals(TaskPriority.p1High));

      expect(items[2].task.data.title, equals('Medium Priority'));
      expect(items[2].task.data.priority, equals(TaskPriority.p2Medium));

      expect(items[3].task.data.title, equals('Low Priority'));
      expect(items[3].task.data.priority, equals(TaskPriority.p3Low));
    });

    test('priority sorting comes after urgency sorting', () async {
      final plan = createTestPlan(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: testDate.add(const Duration(hours: 9)),
            endTime: testDate.add(const Duration(hours: 12)),
          ),
        ],
      );
      when(() => mockDayPlanRepository.getOrCreateDayPlan(testDate))
          .thenAnswer((_) async => plan);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // P0 due today vs P3 overdue
      final p0DueToday = createDueTask(
        id: 'task-p0-today',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'P0 Due Today',
        priority: TaskPriority.p0Urgent,
      );

      final p3Overdue = createDueTask(
        id: 'task-p3-overdue',
        categoryId: 'cat-work',
        dueDate: testDate.subtract(const Duration(days: 1)),
        title: 'P3 Overdue',
        priority: TaskPriority.p3Low,
      );

      when(() => mockDb.getTasksDueOnOrBefore(testDate))
          .thenAnswer((_) async => [p0DueToday as Task, p3Overdue as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final items = result.budgetProgress.first.taskProgressItems;
      expect(items.length, equals(2));

      // Within same priority tier (both have no time), priority comes first
      // P0 should come before P3 regardless of urgency
      expect(items[0].task.data.title, equals('P0 Due Today'));
      expect(items[1].task.data.title, equals('P3 Overdue'));
    });
  });
}
