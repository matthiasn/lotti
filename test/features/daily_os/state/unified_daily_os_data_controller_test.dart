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
        title: 'Test Task',
        dateFrom: dateFrom,
        dateTo: dateTo,
        statusHistory: [],
        status: TaskStatus.inProgress(
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
}
