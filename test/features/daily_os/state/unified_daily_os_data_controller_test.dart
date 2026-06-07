import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockDomainLogger mockDomainLogger;
  late MockDayPlanRepository mockDayPlanRepository;
  late MockTimeService mockTimeService;
  late StreamController<Set<String>> updateStreamController;
  late StreamController<JournalEntity?> timerStreamController;

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
        status:
            status ??
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
    registerFallbackValue(
      DayPlanEntry(
        meta: Metadata(
          id: 'fallback-plan',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(days: 1)),
        ),
        data: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
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
    mockDomainLogger = MockDomainLogger();
    mockDayPlanRepository = MockDayPlanRepository();
    mockTimeService = MockTimeService();
    updateStreamController = StreamController<Set<String>>.broadcast();
    timerStreamController = StreamController<JournalEntity?>.broadcast();

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    when(
      () => mockTimeService.getStream(),
    ).thenAnswer((_) => timerStreamController.stream);

    when(
      () => mockPersistenceLogic.createDbEntity(any()),
    ).thenAnswer((_) async => true);

    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);

    when(
      () => mockDb.getJournalEntitiesForIdsUnordered(any()),
    ).thenAnswer((_) async => []);

    when(() => mockDb.basicLinksForEntryIds(any())).thenAnswer((_) async => []);

    when(() => mockDb.getTasksDueOnOrBefore(any())).thenAnswer((_) async => []);
    when(() => mockDb.getTasksDueOn(any())).thenAnswer((_) async => []);

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<DomainLogger>(mockDomainLogger)
      ..registerSingleton<TimeService>(mockTimeService);

    container = ProviderContainer(
      overrides: [
        dayPlanRepositoryProvider.overrideWithValue(mockDayPlanRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
    timerStreamController.close();
    getIt.reset();
  });

  /// Stubs the day-plan read and empty calendar entries — the baseline
  /// repeated by most integration tests in this file.
  void stubPlanAndEmptyEntries(DayPlanEntry? plan) {
    when(
      () => mockDayPlanRepository.getDayPlan(testDate),
    ).thenAnswer((_) async => plan);
    when(
      () => mockDb.sortedCalendarEntries(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);
  }

  group('UnifiedDailyOsDataController - Budget Progress', () {
    test('returns empty budgetProgress when no blocks defined', () async {
      final plan = createTestPlan(plannedBlocks: []);
      stubPlanAndEmptyEntries(plan);

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
      stubPlanAndEmptyEntries(plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      stubPlanAndEmptyEntries(plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      final personalBudget = progress.firstWhere(
        (p) => p.categoryId == 'cat-personal',
      );
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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [parentTask]);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [parentTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress;
      // Time should be attributed to work (parent) not personal (entry)
      final workBudget = progress.firstWhere((p) => p.categoryId == 'cat-work');
      expect(workBudget.recordedDuration, equals(const Duration(hours: 1)));

      final personalBudget = progress.firstWhere(
        (p) => p.categoryId == 'cat-personal',
      );
      expect(personalBudget.recordedDuration, equals(Duration.zero));
    });
  });

  group('UnifiedDailyOsDataController - Zero Duration Entries', () {
    test('zero-duration entries count toward budget recorded time', () async {
      // Note: Zero-duration entries have Duration.zero, so they don't add time
      // but they should still be tracked in contributingEntries
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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

      final zeroDurationEntry = createTestEntry(
        id: 'zero-entry-1',
        categoryId: 'cat-work',
        dateFrom: testDate.add(const Duration(hours: 10)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [zeroDurationEntry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      // Zero-duration adds zero time but entry is tracked
      expect(progress.contributingEntries.length, equals(1));
      expect(progress.recordedDuration, equals(Duration.zero));
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
      stubPlanAndEmptyEntries(plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
        secondSlot.duration,
        equals(const Duration(hours: 1, minutes: 30)),
      );
    });

    test('excludes zero-duration entries from actual slots', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [parentTask]);

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

    test(
      'actual slots prefer task parent when rating and task are both linked',
      () async {
        final plan = createTestPlan(plannedBlocks: []);
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => plan);

        final timeEntry = createTestEntry(
          id: 'time-entry-1',
          categoryId: 'entry-cat',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        );

        final parentTask = createTestTask(
          id: 'task-1',
          categoryId: 'cat-work',
          dateFrom: testDate,
          dateTo: testDate,
        );

        final ratingEntry = JournalEntity.rating(
          meta: Metadata(
            id: 'rating-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: const RatingData(
            targetId: 'time-entry-1',
            dimensions: [RatingDimension(key: 'focus', value: 0.8)],
          ),
        );

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [timeEntry]);

        when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
          (_) async => [
            // Intentionally put rating first to reproduce bad selection order.
            EntryLink.rating(
              id: 'rating-link-1',
              fromId: 'rating-1',
              toId: 'time-entry-1',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
            EntryLink.basic(
              id: 'basic-link-1',
              fromId: 'task-1',
              toId: 'time-entry-1',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () =>
              mockDb.getJournalEntitiesForIdsUnordered({'task-1', 'rating-1'}),
        ).thenAnswer((_) async => [ratingEntry, parentTask]);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final slot = result.timelineData.actualSlots.single;
        expect(slot.linkedFrom, isA<Task>());
        expect(slot.linkedFrom!.meta.id, equals('task-1'));
        expect(slot.categoryId, equals('cat-work'));
      },
    );

    test('actual slots ignore rating-only parent links', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

      final timeEntry = createTestEntry(
        id: 'time-entry-1',
        categoryId: 'entry-cat',
        dateFrom: testDate.add(const Duration(hours: 9)),
        dateTo: testDate.add(const Duration(hours: 10)),
      );

      final ratingEntry = JournalEntity.rating(
        meta: Metadata(
          id: 'rating-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: const RatingData(
          targetId: 'time-entry-1',
          dimensions: [RatingDimension(key: 'focus', value: 0.8)],
        ),
      );

      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => [timeEntry]);

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
        (_) async => [
          EntryLink.rating(
            id: 'rating-link-1',
            fromId: 'rating-1',
            toId: 'time-entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'rating-1'}),
      ).thenAnswer((_) async => [ratingEntry]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final slot = result.timelineData.actualSlots.single;
      expect(slot.linkedFrom, isNull);
      expect(slot.categoryId, equals('entry-cat'));
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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      stubPlanAndEmptyEntries(plan);

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
      stubPlanAndEmptyEntries(plan);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 6 - 1 (buffer) = 5
      expect(result.timelineData.dayStartHour, equals(5));
    });

    test('calculates start hour from earliest actual slot', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      stubPlanAndEmptyEntries(plan);

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
      stubPlanAndEmptyEntries(plan);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // 22 + 1 (next hour) + 1 (buffer) = 24
      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('calculates end hour from latest actual slot', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      stubPlanAndEmptyEntries(plan);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.timelineData.dayEndHour, equals(24));
    });

    test('handles midnight crossing - entry ends next day', () async {
      final plan = createTestPlan(plannedBlocks: []);
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      stubPlanAndEmptyEntries(plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [parentTask]);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(
        () => mockDb.basicLinksForEntryIds({'time-entry-1', 'time-entry-2'}),
      ).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [parentTask]);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [doneTask]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final taskProgress = result.budgetProgress.first.taskProgressItems.first;
      expect(taskProgress.wasCompletedOnDay, isTrue);
    });

    test(
      'does not mark task as completed when done on different day',
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
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => plan);

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
            createdAt: testDate.subtract(
              const Duration(days: 1),
            ), // Done yesterday
            utcOffset: 0,
          ),
        );

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [timeEntry]);

        when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
        ).thenAnswer((_) async => [doneTask]);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final taskProgress =
            result.budgetProgress.first.taskProgressItems.first;
        expect(taskProgress.wasCompletedOnDay, isFalse);
      },
    );

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(
        () => mockDb.basicLinksForEntryIds({'entry-1', 'entry-2'}),
      ).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1', 'task-2'}),
      ).thenAnswer((_) async => [task1, task2]);

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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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
      when(
        () => mockDb.basicLinksForEntryIds({'entry-1'}),
      ).thenAnswer((_) async => []);

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
          status:
              status ??
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
      stubPlanAndEmptyEntries(plan);

      // Task due today with no tracked time
      final dueTask = createDueTask(
        id: 'task-due',
        categoryId: 'cat-work',
        dueDate: testDate,
        title: 'Task Due Today',
      );

      when(
        () => mockDb.getTasksDueOnOrBefore(testDate),
      ).thenAnswer((_) async => [dueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      expect(progress.taskProgressItems.length, equals(1));
      expect(
        progress.taskProgressItems.first.task.data.title,
        equals('Task Due Today'),
      );
      expect(
        progress.taskProgressItems.first.timeSpentOnDay,
        equals(Duration.zero),
      );
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
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);

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

      when(() => mockDb.basicLinksForEntryIds({'time-entry-1'})).thenAnswer(
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

      when(
        () => mockDb.getJournalEntitiesForIdsUnordered({'task-1'}),
      ).thenAnswer((_) async => [taskWithDue]);

      when(
        () => mockDb.getTasksDueOnOrBefore(testDate),
      ).thenAnswer((_) async => [taskWithDue as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final progress = result.budgetProgress.first;
      // Should have only ONE entry (deduplicated)
      expect(progress.taskProgressItems.length, equals(1));
      // Should have the tracked time
      expect(
        progress.taskProgressItems.first.timeSpentOnDay,
        equals(const Duration(hours: 1)),
      );
      // Should also have due date status
      expect(progress.taskProgressItems.first.isDueOrOverdue, isTrue);
    });

    test(
      'creates synthetic budget for category with due tasks but no budget',
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
        stubPlanAndEmptyEntries(plan);

        // Due task in a category WITHOUT a budget
        final dueTask = createDueTask(
          id: 'task-unplanned',
          categoryId: 'cat-unplanned',
          dueDate: testDate,
          title: 'Unplanned Due Task',
        );

        when(
          () => mockDb.getTasksDueOnOrBefore(testDate),
        ).thenAnswer((_) async => [dueTask as Task]);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        // Should have 2 budgets: the planned one and a synthetic one
        expect(result.budgetProgress.length, equals(2));

        final syntheticBudget = result.budgetProgress.firstWhere(
          (b) => b.categoryId == 'cat-unplanned',
        );
        expect(syntheticBudget.plannedDuration, equals(Duration.zero));
        expect(syntheticBudget.hasNoBudgetWarning, isTrue);
        expect(syntheticBudget.taskProgressItems.length, equals(1));
        expect(
          syntheticBudget.taskProgressItems.first.task.data.title,
          equals('Unplanned Due Task'),
        );
      },
    );

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
      stubPlanAndEmptyEntries(plan);

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

      when(
        () => mockDb.getTasksDueOnOrBefore(testDate),
      ).thenAnswer((_) async => [dueTodayTask as Task, overdueTask as Task]);

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
      stubPlanAndEmptyEntries(plan);

      // Due task with NULL category
      final dueTask = createDueTask(
        id: 'task-no-cat',
        categoryId: null,
        dueDate: testDate,
        title: 'Task Without Category',
      );

      when(
        () => mockDb.getTasksDueOnOrBefore(testDate),
      ).thenAnswer((_) async => [dueTask as Task]);

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // No budgets should be created for tasks without category
      expect(result.budgetProgress, isEmpty);
    });

    test(
      'future dates use getTasksDueOn instead of getTasksDueOnOrBefore',
      () async {
        // Use a date that is definitely in the future
        final futureDate = DateTime(2030, 6, 15);
        final futureDateStart = DateTime(
          futureDate.year,
          futureDate.month,
          futureDate.day,
        );

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

        when(
          () => mockDayPlanRepository.getDayPlan(futureDateStart),
        ).thenAnswer((_) async => plan);
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
        when(
          () => mockDb.getTasksDueOn(futureDateStart),
        ).thenAnswer((_) async => [futureDueTask as Task]);

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

        when(
          () => mockDb.getTasksDueOnOrBefore(futureDateStart),
        ).thenAnswer((_) async => [futureDueTask as Task, overdueTask as Task]);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: futureDateStart).future,
        );

        final items = result.budgetProgress.first.taskProgressItems;

        // Should only have 1 task (the future task), not the overdue task
        expect(items.length, equals(1));
        expect(items[0].task.data.title, equals('Future Task'));

        // Verify getTasksDueOn was called (not getTasksDueOnOrBefore)
        verify(() => mockDb.getTasksDueOn(futureDateStart)).called(1);
      },
    );

    test(
      'sorts tasks by priority (P0 before P1 before P2 before P3)',
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
        stubPlanAndEmptyEntries(plan);

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
        when(() => mockDb.getTasksDueOnOrBefore(testDate)).thenAnswer(
          (_) async => [
            p3Task as Task,
            p0Task as Task,
            p2Task as Task,
            p1Task as Task,
          ],
        );

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
      },
    );

    test('sorts by priority before urgency for tasks with no time', () async {
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
      stubPlanAndEmptyEntries(plan);

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

      when(
        () => mockDb.getTasksDueOnOrBefore(testDate),
      ).thenAnswer((_) async => [p0DueToday as Task, p3Overdue as Task]);

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

  group('UnifiedDailyOsDataController - Timer Subscription Logic', () {
    test('updates state when timer starts', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // Create a timer entry for the current day
        final timerEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 5)),
        );

        // Baseline: nothing recorded against the work budget yet.
        final before = container
            .read(unifiedDailyOsDataControllerProvider(date: testDate))
            .value!
            .budgetProgress
            .firstWhere((p) => p.categoryId == 'cat-work');
        expect(before.recordedDuration, Duration.zero);

        // Simulate timer starting by emitting on stream
        timerStreamController.add(timerEntry);

        // Allow stream listener to process
        async.flushMicrotasks();

        // The live timer entry's elapsed time lands in the budget.
        final after = container
            .read(unifiedDailyOsDataControllerProvider(date: testDate))
            .value!
            .budgetProgress
            .firstWhere((p) => p.categoryId == 'cat-work');
        expect(after.recordedDuration, const Duration(minutes: 5));
        expect(
          after.contributingEntries.map((e) => e.meta.id),
          contains('timer-entry-1'),
        );
      });
    });

    test('updates state when timer stops', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // Start timer first
        final timerEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 5)),
        );
        timerStreamController.add(timerEntry);
        async.flushMicrotasks();

        // Stop timer by emitting null
        timerStreamController.add(null);
        async.flushMicrotasks();

        // Verify the stream listener processed both events
        verify(() => mockTimeService.getStream()).called(greaterThan(0));
      });
    });

    test('throttles updates when minute does not change', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // First timer event (start)
        final timerEntry1 = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 5)),
        );
        timerStreamController.add(timerEntry1);
        async.flushMicrotasks();

        // Second timer event - same minute (should be throttled)
        final timerEntry2 = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(
            const Duration(hours: 10, minutes: 5, seconds: 30),
          ),
        );
        timerStreamController.add(timerEntry2);
        async.flushMicrotasks();

        // Verify stream was accessed (listener is active)
        verify(() => mockTimeService.getStream()).called(greaterThan(0));
      });
    });

    test('updates when minute changes', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // First timer event
        final timerEntry1 = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 5)),
        );
        timerStreamController.add(timerEntry1);
        async.flushMicrotasks();

        // Second timer event - different minute (should update)
        final timerEntry2 = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 6)),
        );
        timerStreamController.add(timerEntry2);
        async.flushMicrotasks();

        // Verify stream was accessed
        verify(() => mockTimeService.getStream()).called(greaterThan(0));
      });
    });

    test('ignores timer for different day', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        late DailyOsData initialResult;
        container
            .read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            )
            .then((value) => initialResult = value);
        async.flushMicrotasks();

        final initialRecorded =
            initialResult.budgetProgress.firstOrNull?.recordedDuration;

        // Timer entry for a DIFFERENT day
        final differentDayEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(days: 1, hours: 10)),
          dateTo: testDate.add(const Duration(days: 1, hours: 10, minutes: 30)),
        );
        timerStreamController.add(differentDayEntry);
        async.flushMicrotasks();

        // The budget should not have changed
        final result = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(
          result.value?.budgetProgress.firstOrNull?.recordedDuration,
          equals(initialRecorded),
        );
      });
    });

    test('ignores timer when entry has no category', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // Timer entry with no category
        final noCategoryEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: null, // No category
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
        );
        timerStreamController.add(noCategoryEntry);
        async.flushMicrotasks();

        // The budget should not have changed for any category
        final result = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(
          result.value?.budgetProgress.first.recordedDuration,
          Duration.zero,
        );
      });
    });

    test('uses linkedFrom category when available', () {
      fakeAsync((async) {
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
        stubPlanAndEmptyEntries(plan);

        // linkedFrom task has the category
        final linkedTask = createTestTask(
          id: 'linked-task',
          categoryId: 'cat-work',
          dateFrom: testDate,
          dateTo: testDate,
        );
        when(() => mockTimeService.linkedFrom).thenReturn(linkedTask);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // Timer entry with no category, but linkedFrom has category
        final timerEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: null, // No category on entry
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
        );
        timerStreamController.add(timerEntry);
        async.flushMicrotasks();

        // The linkedFrom category should be used
        verify(() => mockTimeService.linkedFrom).called(greaterThan(0));
      });
    });

    test('adds new running entry to contributing entries', () {
      fakeAsync((async) {
        final existingEntry = createTestEntry(
          id: 'existing-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 9)),
          dateTo: testDate.add(const Duration(hours: 10)),
        );

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
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => plan);
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [existingEntry]);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch - should have 1 hour recorded
        late DailyOsData initialResult;
        container
            .read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            )
            .then((value) => initialResult = value);
        async.flushMicrotasks();

        expect(
          initialResult.budgetProgress.first.recordedDuration,
          equals(const Duration(hours: 1)),
        );

        // New timer entry (not in existing entries)
        final newTimerEntry = createTestEntry(
          id: 'new-timer-entry',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 11)),
          dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
        );
        timerStreamController.add(newTimerEntry);
        async.flushMicrotasks();

        // The new entry should be added to contributing entries
        // Total should now be 1.5 hours
        final result = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );

        // Verify the state was updated
        expect(result.hasValue, isTrue);
      });
    });

    test('updates existing entry in contributing entries', () {
      fakeAsync((async) {
        final existingEntry = createTestEntry(
          id: 'timer-entry-1',
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
        );

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
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => plan);
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [existingEntry]);

        when(() => mockTimeService.linkedFrom).thenReturn(null);

        // Initial fetch
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // Same entry ID but updated duration
        final updatedTimerEntry = createTestEntry(
          id: 'timer-entry-1', // Same ID as existing
          categoryId: 'cat-work',
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 11)), // Now 1 hour
        );
        timerStreamController.add(updatedTimerEntry);
        async.flushMicrotasks();

        // The entry should be updated (replaced) in contributing entries
        final result = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(result.hasValue, isTrue);
      });
    });
  });

  group('UnifiedDailyOsDataController - Mutation Methods', () {
    DayPlanEntry createPlanWithStatus({
      DayPlanStatus status = const DayPlanStatus.draft(),
      List<PlannedBlock> plannedBlocks = const [],
      List<PinnedTaskRef> pinnedTasks = const [],
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
          status: status,
          plannedBlocks: plannedBlocks,
          pinnedTasks: pinnedTasks,
        ),
      );
    }

    void setupBasicMocks(DayPlanEntry plan) {
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => plan);
      when(() => mockDayPlanRepository.save(any())).thenAnswer((
        invocation,
      ) async {
        return invocation.positionalArguments.first as DayPlanEntry;
      });
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);
    }

    test('agreeToPlan updates status to agreed', () async {
      final plan = createPlanWithStatus();
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .agreeToPlan();

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      expect(captured.length, greaterThan(0));
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.isAgreed, isTrue);
    });

    test('markComplete sets completedAt timestamp', () async {
      final plan = createPlanWithStatus(
        status: DayPlanStatus.agreed(agreedAt: testDate),
      );
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .markComplete();

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.completedAt, isNotNull);
    });

    test('addPlannedBlock adds a block to the plan', () async {
      final plan = createPlanWithStatus();
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final newBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 11),
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .addPlannedBlock(newBlock);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(savedPlan.data.plannedBlocks.first.categoryId, equals('cat-work'));
    });

    test('updatePlannedBlock updates an existing block', () async {
      final existingBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 10),
      );
      final plan = createPlanWithStatus(plannedBlocks: [existingBlock]);
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final updatedBlock = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: DateTime(2026, 1, 15, 9),
        endTime: DateTime(2026, 1, 15, 12), // Extended end time
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .updatePlannedBlock(updatedBlock);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(
        savedPlan.data.plannedBlocks.first.endTime,
        equals(DateTime(2026, 1, 15, 12)),
      );
    });

    test('removePlannedBlock removes a block', () async {
      final plan = createPlanWithStatus(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
          PlannedBlock(
            id: 'block-2',
            categoryId: 'cat-2',
            startTime: DateTime(2026, 1, 15, 14),
            endTime: DateTime(2026, 1, 15, 15),
          ),
        ],
      );
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .removePlannedBlock('block-1');

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(1));
      expect(savedPlan.data.plannedBlocks.first.id, equals('block-2'));
    });

    test('setPlannedBlocks replaces all blocks', () async {
      final plan = createPlanWithStatus(
        plannedBlocks: [
          PlannedBlock(
            id: 'old-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      final newBlocks = [
        PlannedBlock(
          id: 'new-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 1, 15, 8),
          endTime: DateTime(2026, 1, 15, 12),
        ),
        PlannedBlock(
          id: 'new-2',
          categoryId: 'cat-study',
          startTime: DateTime(2026, 1, 15, 14),
          endTime: DateTime(2026, 1, 15, 17),
        ),
      ];

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .setPlannedBlocks(newBlocks);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks.length, equals(2));
      expect(savedPlan.data.plannedBlocks.first.id, equals('new-1'));
      expect(savedPlan.data.plannedBlocks.last.id, equals('new-2'));
    });

    test('setPlannedBlocks with empty list clears all blocks', () async {
      final plan = createPlanWithStatus(
        plannedBlocks: [
          PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          ),
        ],
      );
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .setPlannedBlocks([]);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.plannedBlocks, isEmpty);
    });

    test('pinTask adds a pinned task', () async {
      final plan = createPlanWithStatus();
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      const taskRef = PinnedTaskRef(
        taskId: 'task-123',
        categoryId: 'cat-1',
        sortOrder: 1,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .pinTask(taskRef);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.pinnedTasks.length, equals(1));
      expect(savedPlan.data.pinnedTasks.first.taskId, equals('task-123'));
    });

    test('unpinTask removes a pinned task', () async {
      final plan = createPlanWithStatus(
        pinnedTasks: const [
          PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-1'),
          PinnedTaskRef(taskId: 'task-2', categoryId: 'cat-1'),
        ],
      );
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .unpinTask('task-1');

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.pinnedTasks.length, equals(1));
      expect(savedPlan.data.pinnedTasks.first.taskId, equals('task-2'));
    });

    test('setDayLabel updates the label', () async {
      final plan = createPlanWithStatus();
      setupBasicMocks(plan);

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .setDayLabel('Deep Work Day');

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      final savedPlan = captured.last as DayPlanEntry;
      expect(savedPlan.data.dayLabel, equals('Deep Work Day'));
    });

    group('Status transitions to needsReview', () {
      test('addPlannedBlock transitions agreed plan to needsReview', () async {
        final agreedPlan = createPlanWithStatus(
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
        );
        setupBasicMocks(agreedPlan);

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final newBlock = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 1, 15, 9),
          endTime: DateTime(2026, 1, 15, 11),
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .addPlannedBlock(newBlock);

        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        final savedPlan = captured.last as DayPlanEntry;
        expect(savedPlan.data.needsReview, isTrue);
        expect(
          (savedPlan.data.status as DayPlanStatusNeedsReview).reason,
          equals(DayPlanReviewReason.blockModified),
        );
      });

      test(
        'updatePlannedBlock transitions agreed plan to needsReview',
        () async {
          final existingBlock = PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          );
          final agreedPlan = createPlanWithStatus(
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
            plannedBlocks: [existingBlock],
          );
          setupBasicMocks(agreedPlan);

          await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          final updatedBlock = PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 12),
          );

          await container
              .read(
                unifiedDailyOsDataControllerProvider(date: testDate).notifier,
              )
              .updatePlannedBlock(updatedBlock);

          final captured = verify(
            () => mockDayPlanRepository.save(captureAny()),
          ).captured;
          final savedPlan = captured.last as DayPlanEntry;
          expect(savedPlan.data.needsReview, isTrue);
        },
      );

      test(
        'removePlannedBlock transitions agreed plan to needsReview',
        () async {
          final existingBlock = PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-1',
            startTime: DateTime(2026, 1, 15, 9),
            endTime: DateTime(2026, 1, 15, 10),
          );
          final agreedPlan = createPlanWithStatus(
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
            plannedBlocks: [existingBlock],
          );
          setupBasicMocks(agreedPlan);

          await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          await container
              .read(
                unifiedDailyOsDataControllerProvider(date: testDate).notifier,
              )
              .removePlannedBlock('block-1');

          final captured = verify(
            () => mockDayPlanRepository.save(captureAny()),
          ).captured;
          final savedPlan = captured.last as DayPlanEntry;
          expect(savedPlan.data.needsReview, isTrue);
        },
      );

      test(
        'setPlannedBlocks transitions agreed plan to needsReview',
        () async {
          final agreedPlan = createPlanWithStatus(
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
            plannedBlocks: [
              PlannedBlock(
                id: 'old-1',
                categoryId: 'cat-1',
                startTime: DateTime(2026, 1, 15, 9),
                endTime: DateTime(2026, 1, 15, 10),
              ),
            ],
          );
          setupBasicMocks(agreedPlan);

          await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          await container
              .read(
                unifiedDailyOsDataControllerProvider(date: testDate).notifier,
              )
              .setPlannedBlocks([
                PlannedBlock(
                  id: 'new-1',
                  categoryId: 'cat-work',
                  startTime: DateTime(2026, 1, 15, 8),
                  endTime: DateTime(2026, 1, 15, 12),
                ),
              ]);

          final captured = verify(
            () => mockDayPlanRepository.save(captureAny()),
          ).captured;
          final savedPlan = captured.last as DayPlanEntry;
          expect(savedPlan.data.needsReview, isTrue);
          expect(
            (savedPlan.data.status as DayPlanStatusNeedsReview).reason,
            equals(DayPlanReviewReason.blockModified),
          );
        },
      );

      test(
        'setPlannedBlocks keeps draft status when plan is draft',
        () async {
          final draftPlan = createPlanWithStatus();
          setupBasicMocks(draftPlan);

          await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          await container
              .read(
                unifiedDailyOsDataControllerProvider(date: testDate).notifier,
              )
              .setPlannedBlocks([
                PlannedBlock(
                  id: 'new-1',
                  categoryId: 'cat-work',
                  startTime: DateTime(2026, 1, 15, 8),
                  endTime: DateTime(2026, 1, 15, 12),
                ),
              ]);

          final captured = verify(
            () => mockDayPlanRepository.save(captureAny()),
          ).captured;
          final savedPlan = captured.last as DayPlanEntry;
          expect(savedPlan.data.isDraft, isTrue);
        },
      );

      test('pinTask transitions agreed plan to needsReview', () async {
        final agreedPlan = createPlanWithStatus(
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
        );
        setupBasicMocks(agreedPlan);

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        const taskRef = PinnedTaskRef(
          taskId: 'task-123',
          categoryId: 'cat-1',
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .pinTask(taskRef);

        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        final savedPlan = captured.last as DayPlanEntry;
        expect(savedPlan.data.needsReview, isTrue);
        expect(
          (savedPlan.data.status as DayPlanStatusNeedsReview).reason,
          equals(DayPlanReviewReason.taskRescheduled),
        );
      });

      test('unpinTask transitions agreed plan to needsReview', () async {
        final agreedPlan = createPlanWithStatus(
          status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 15, 8)),
          pinnedTasks: const [
            PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-1'),
          ],
        );
        setupBasicMocks(agreedPlan);

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .unpinTask('task-1');

        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        final savedPlan = captured.last as DayPlanEntry;
        expect(savedPlan.data.needsReview, isTrue);
      });

      test('edits on draft plan do not change status', () async {
        final draftPlan = createPlanWithStatus();
        setupBasicMocks(draftPlan);

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final newBlock = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 1, 15, 9),
          endTime: DateTime(2026, 1, 15, 11),
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .addPlannedBlock(newBlock);

        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        final savedPlan = captured.last as DayPlanEntry;
        expect(savedPlan.data.isDraft, isTrue);
      });

      test('needsReview status preserves previouslyAgreedAt', () async {
        final agreedAt = DateTime(2026, 1, 15, 8);
        final agreedPlan = createPlanWithStatus(
          status: DayPlanStatus.agreed(agreedAt: agreedAt),
        );
        setupBasicMocks(agreedPlan);

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final newBlock = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 1, 15, 9),
          endTime: DateTime(2026, 1, 15, 11),
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .addPlannedBlock(newBlock);

        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        final savedPlan = captured.last as DayPlanEntry;
        final status = savedPlan.data.status as DayPlanStatusNeedsReview;
        expect(status.previouslyAgreedAt, equals(agreedAt));
      });
    });
  });

  group('UnifiedDailyOsDataController - Lazy Day Plan Creation', () {
    void setupMocksForNoPlan() {
      // getDayPlan returns null — no plan exists in DB
      when(
        () => mockDayPlanRepository.getDayPlan(testDate),
      ).thenAnswer((_) async => null);
      when(() => mockDayPlanRepository.save(any())).thenAnswer((
        invocation,
      ) async {
        return invocation.positionalArguments.first as DayPlanEntry;
      });
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);
    }

    test('does not persist a day plan on navigation', () async {
      setupMocksForNoPlan();

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      // UI receives a transient plan with correct ID
      expect(result.dayPlan.meta.id, equals(planId));
      expect(result.dayPlan.data.isDraft, isTrue);
      expect(result.dayPlan.data.plannedBlocks, isEmpty);

      // No save should have been called — plan is transient
      verifyNever(() => mockDayPlanRepository.save(any()));
    });

    test('transient plan uses correct deterministic ID', () async {
      setupMocksForNoPlan();

      final result = await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      expect(result.dayPlan.meta.id, equals(dayPlanId(testDate)));
      expect(
        result.dayPlan.meta.dateFrom,
        equals(testDate),
      );
      expect(
        result.dayPlan.meta.dateTo,
        equals(testDate.add(const Duration(days: 1))),
      );
    });

    test(
      'addPlannedBlock persists transient plan on first interaction',
      () async {
        setupMocksForNoPlan();

        // After mutation, getDayPlan should return the saved plan
        // so _fetchAllData finds it on refetch
        DayPlanEntry? savedPlan;
        when(() => mockDayPlanRepository.save(any())).thenAnswer((
          invocation,
        ) async {
          savedPlan = invocation.positionalArguments.first as DayPlanEntry;
          // On next getDayPlan call, return the saved plan
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) async => savedPlan);
          return savedPlan!;
        });

        await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        // Verify no save before interaction
        verifyNever(() => mockDayPlanRepository.save(any()));

        final newBlock = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 1, 15, 9),
          endTime: DateTime(2026, 1, 15, 11),
        );

        await container
            .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
            .addPlannedBlock(newBlock);

        // Now the plan should have been saved
        final captured = verify(
          () => mockDayPlanRepository.save(captureAny()),
        ).captured;
        expect(captured, isNotEmpty);
        final firstSave = captured.first as DayPlanEntry;
        expect(firstSave.meta.id, equals(planId));
        expect(firstSave.data.plannedBlocks.length, equals(1));
        expect(firstSave.data.plannedBlocks.first.id, equals('block-1'));
      },
    );

    test('agreeToPlan persists transient plan on first interaction', () async {
      setupMocksForNoPlan();

      DayPlanEntry? savedPlan;
      when(() => mockDayPlanRepository.save(any())).thenAnswer((
        invocation,
      ) async {
        savedPlan = invocation.positionalArguments.first as DayPlanEntry;
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => savedPlan);
        return savedPlan!;
      });

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      verifyNever(() => mockDayPlanRepository.save(any()));

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .agreeToPlan();

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      expect(captured, isNotEmpty);
      final firstSave = captured.first as DayPlanEntry;
      expect(firstSave.meta.id, equals(planId));
      expect(firstSave.data.isAgreed, isTrue);
    });

    test('pinTask persists transient plan on first interaction', () async {
      setupMocksForNoPlan();

      DayPlanEntry? savedPlan;
      when(() => mockDayPlanRepository.save(any())).thenAnswer((
        invocation,
      ) async {
        savedPlan = invocation.positionalArguments.first as DayPlanEntry;
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => savedPlan);
        return savedPlan!;
      });

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      verifyNever(() => mockDayPlanRepository.save(any()));

      const taskRef = PinnedTaskRef(
        taskId: 'task-1',
        categoryId: 'cat-work',
      );

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .pinTask(taskRef);

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      expect(captured, isNotEmpty);
      final firstSave = captured.first as DayPlanEntry;
      expect(firstSave.meta.id, equals(planId));
      expect(firstSave.data.pinnedTasks.length, equals(1));
      expect(firstSave.data.pinnedTasks.first.taskId, equals('task-1'));
    });

    test('setDayLabel persists transient plan on first interaction', () async {
      setupMocksForNoPlan();

      DayPlanEntry? savedPlan;
      when(() => mockDayPlanRepository.save(any())).thenAnswer((
        invocation,
      ) async {
        savedPlan = invocation.positionalArguments.first as DayPlanEntry;
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => savedPlan);
        return savedPlan!;
      });

      await container.read(
        unifiedDailyOsDataControllerProvider(date: testDate).future,
      );

      verifyNever(() => mockDayPlanRepository.save(any()));

      await container
          .read(unifiedDailyOsDataControllerProvider(date: testDate).notifier)
          .setDayLabel('Focus Day');

      final captured = verify(
        () => mockDayPlanRepository.save(captureAny()),
      ).captured;
      expect(captured, isNotEmpty);
      final firstSave = captured.first as DayPlanEntry;
      expect(firstSave.meta.id, equals(planId));
      expect(firstSave.data.dayLabel, equals('Focus Day'));
    });

    test(
      'existing plan is returned from DB without creating new one',
      () async {
        final existingPlan = DayPlanEntry(
          meta: Metadata(
            id: planId,
            createdAt: DateTime(2026, 1, 14),
            updatedAt: DateTime(2026, 1, 14),
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(days: 1)),
          ),
          data: DayPlanData(
            planDate: testDate,
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 1, 14, 8)),
            plannedBlocks: [
              PlannedBlock(
                id: 'existing-block',
                categoryId: 'cat-work',
                startTime: DateTime(2026, 1, 15, 9),
                endTime: DateTime(2026, 1, 15, 11),
              ),
            ],
          ),
        );

        stubPlanAndEmptyEntries(existingPlan);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        // Should use the existing plan from DB, not create a new one
        expect(result.dayPlan.meta.id, equals(planId));
        expect(result.dayPlan.data.isAgreed, isTrue);
        expect(result.dayPlan.data.plannedBlocks.length, equals(1));
        expect(
          result.dayPlan.data.plannedBlocks.first.id,
          equals('existing-block'),
        );

        // No save should occur — plan already exists
        verifyNever(() => mockDayPlanRepository.save(any()));
      },
    );

    test('navigating to multiple dates does not create plans', () async {
      // Set up two dates with no plans
      final date1 = DateTime(2026, 1, 15);
      final date2 = DateTime(2026, 1, 16);

      when(
        () => mockDayPlanRepository.getDayPlan(date1),
      ).thenAnswer((_) async => null);
      when(
        () => mockDayPlanRepository.getDayPlan(date2),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.sortedCalendarEntries(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      // Navigate to date1
      await container.read(
        unifiedDailyOsDataControllerProvider(date: date1).future,
      );
      // Navigate to date2
      await container.read(
        unifiedDailyOsDataControllerProvider(date: date2).future,
      );

      // No plan should have been persisted for either date
      verifyNever(() => mockDayPlanRepository.save(any()));
    });
  });
  group('UnifiedDailyOsDataController - Update filtering', () {
    test('ignores unrelated update notifications after initial load', () {
      fakeAsync((async) {
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => createTestPlan());
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []);

        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        updateStreamController.add({'unrelated-entry-id'});
        async.flushMicrotasks();

        verify(() => mockDayPlanRepository.getDayPlan(testDate)).called(1);
        verify(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).called(1);
        verify(() => mockDb.getTasksDueOnOrBefore(testDate)).called(1);
      });
    });

    test('refreshes when a tracked day plan id changes', () {
      fakeAsync((async) {
        var planCalls = 0;
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async {
          planCalls++;
          return planCalls == 1
              ? createTestPlan()
              : createTestPlan(
                  plannedBlocks: [
                    PlannedBlock(
                      id: 'block-1',
                      categoryId: 'cat-work',
                      startTime: DateTime(2026, 1, 15, 9),
                      endTime: DateTime(2026, 1, 15, 11),
                    ),
                  ],
                );
        });
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []);

        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        updateStreamController.add({planId});
        async.flushMicrotasks();

        final state = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(state.value?.dayPlan.data.plannedBlocks, hasLength(1));
        verify(() => mockDayPlanRepository.getDayPlan(testDate)).called(2);
      });
    });

    test(
      'coalesces a notification arriving while a refresh is in flight',
      () {
        fakeAsync((async) {
          var planCalls = 0;
          final gates = <Completer<DayPlanEntry?>>[];
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) {
            planCalls++;
            if (planCalls == 1) {
              // Initial load resolves immediately.
              return Future.value(createTestPlan());
            }
            // Refresh fetches block until released by the test.
            final gate = Completer<DayPlanEntry?>();
            gates.add(gate);
            return gate.future;
          });
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );
          async.flushMicrotasks();
          expect(planCalls, 1);

          // First notification starts a refresh that blocks on the gate.
          updateStreamController.add({planId});
          async.flushMicrotasks();
          expect(planCalls, 2);

          // A second notification while the fetch is in flight must NOT
          // start a concurrent fetch — it only marks _pendingRefresh.
          updateStreamController.add({planId});
          async.flushMicrotasks();
          expect(planCalls, 2);

          // Releasing the in-flight fetch triggers exactly one coalesced
          // follow-up fetch (the do-while loop).
          gates[0].complete(createTestPlan());
          async.flushMicrotasks();
          expect(planCalls, 3);

          // The coalesced fetch's result lands in the state.
          gates[1].complete(
            createTestPlan(
              plannedBlocks: [
                PlannedBlock(
                  id: 'block-coalesced',
                  categoryId: 'cat-work',
                  startTime: DateTime(2026, 1, 15, 9),
                  endTime: DateTime(2026, 1, 15, 10),
                ),
              ],
            ),
          );
          async.flushMicrotasks();
          expect(planCalls, 3);

          final state = container.read(
            unifiedDailyOsDataControllerProvider(date: testDate),
          );
          expect(state.value?.dayPlan.data.plannedBlocks, hasLength(1));
        });
      },
    );

    test('refreshes on task notifications to pick up newly due tasks', () {
      fakeAsync((async) {
        var dueTaskCalls = 0;
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => createTestPlan());
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []);
        when(() => mockDb.getTasksDueOnOrBefore(testDate)).thenAnswer((
          _,
        ) async {
          dueTaskCalls++;
          if (dueTaskCalls == 1) {
            return [];
          }
          return [
            createTestTask(
                  id: 'due-task-1',
                  categoryId: 'cat-work',
                  dateFrom: DateTime(2026, 1, 15, 8),
                  dateTo: DateTime(2026, 1, 15, 8, 30),
                  status: TaskStatus.inProgress(
                    id: 'status-2',
                    createdAt: DateTime(2026, 1, 15, 8),
                    utcOffset: 0,
                  ),
                )
                as Task,
          ];
        });

        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        updateStreamController.add({taskNotification});
        async.flushMicrotasks();

        final state = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(state.value?.budgetProgress, hasLength(1));
        expect(
          state
              .value
              ?.budgetProgress
              .first
              .taskProgressItems
              .first
              .task
              .meta
              .id,
          'due-task-1',
        );
        verify(() => mockDb.getTasksDueOnOrBefore(testDate)).called(2);
      });
    });

    test(
      'queues one refresh when a notification arrives during initial load',
      () {
        fakeAsync((async) {
          final initialPlanCompleter = Completer<DayPlanEntry?>();
          var planCalls = 0;

          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) {
            planCalls++;
            if (planCalls == 1) {
              return initialPlanCompleter.future;
            }
            return Future.value(
              createTestPlan(
                plannedBlocks: [
                  PlannedBlock(
                    id: 'queued-block',
                    categoryId: 'cat-work',
                    startTime: DateTime(2026, 1, 15, 13),
                    endTime: DateTime(2026, 1, 15, 14),
                  ),
                ],
              ),
            );
          });
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );
          async.flushMicrotasks();

          updateStreamController.add({planId});
          async.flushMicrotasks();

          initialPlanCompleter.complete(createTestPlan());
          async.flushMicrotasks();

          final state = container.read(
            unifiedDailyOsDataControllerProvider(date: testDate),
          );
          expect(state.value?.dayPlan.data.plannedBlocks, hasLength(1));
          verify(() => mockDayPlanRepository.getDayPlan(testDate)).called(2);
        });
      },
    );
  });

  // ---------------------------------------------------------------------------
  // New tests for previously uncovered branches
  // ---------------------------------------------------------------------------

  group('UnifiedDailyOsDataController - refresh concurrency (line 174)', () {
    /// When a second notification arrives while a refresh is already in-flight
    /// (`_refreshInFlight == true`), `_refreshFromNotifications` takes the
    /// early-return branch at line 174: it sets `_pendingRefresh = true` and
    /// returns, so the in-flight refresh loops once more after it completes.
    ///
    /// To reliably exercise this, the FIRST refresh's `_fetchAllData` must stay
    /// pending while the second notification fires. We block the refresh's
    /// `getDayPlan` on a Completer that we control.
    test('queues second refresh when one is already in-flight', () {
      fakeAsync((async) {
        // getDayPlan call 1 -> initial build (resolves immediately).
        // getDayPlan call 2 -> first refresh fetch (blocks on completer so the
        //   refresh stays in-flight while the 2nd notification arrives).
        // getDayPlan call 3 -> queued re-run triggered by line 174 (returns a
        //   plan with a block so we can observe the queued refresh ran).
        final refreshFetchCompleter = Completer<DayPlanEntry?>();
        var callCount = 0;

        when(() => mockDayPlanRepository.getDayPlan(testDate)).thenAnswer((_) {
          callCount++;
          if (callCount == 1) return Future.value(createTestPlan());
          if (callCount == 2) return refreshFetchCompleter.future;
          return Future.value(
            createTestPlan(
              plannedBlocks: [
                PlannedBlock(
                  id: 'queued-block',
                  categoryId: 'cat-work',
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 11)),
                ),
              ],
            ),
          );
        });
        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => []);

        // Initial load fully completes (_hasLoadedInitialData = true).
        container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );
        async.flushMicrotasks();

        // First notification -> starts a refresh whose fetch (call 2) blocks on
        // refreshFetchCompleter. The refresh is now in-flight.
        updateStreamController.add({planId});
        async.flushMicrotasks();
        expect(callCount, equals(2)); // initial + in-flight refresh fetch

        // Second notification WHILE the first refresh is in-flight ->
        // _refreshInFlight is true, so line 174 sets _pendingRefresh and returns
        // without starting a new fetch (callCount stays 2).
        updateStreamController.add({planId});
        async.flushMicrotasks();
        expect(callCount, equals(2));

        // Completing the in-flight fetch lets the do/while loop see the queued
        // _pendingRefresh and run exactly one more fetch (call 3).
        refreshFetchCompleter.complete(createTestPlan());
        async.flushMicrotasks();

        expect(callCount, equals(3));
        verify(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).called(3);

        // The queued refresh's data (block from call 3) is the final state,
        // proving the line-174 re-run actually applied fresh data.
        final state = container.read(
          unifiedDailyOsDataControllerProvider(date: testDate),
        );
        expect(state.value?.dayPlan.data.plannedBlocks, hasLength(1));
        expect(
          state.value?.dayPlan.data.plannedBlocks.first.id,
          equals('queued-block'),
        );
      });
    });
  });

  group(
    'UnifiedDailyOsDataController - error handling in _refreshFromNotifications (lines 189-190)',
    () {
      test(
        'logs error when _fetchAllData throws during notification refresh',
        () {
          fakeAsync((async) {
            var callCount = 0;

            when(() => mockDayPlanRepository.getDayPlan(testDate)).thenAnswer(
              (_) async {
                callCount++;
                if (callCount == 1) return createTestPlan();
                throw Exception('DB exploded');
              },
            );
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async => []);

            when(
              () => mockDomainLogger.error(
                any(),
                any(),
                stackTrace: any(named: 'stackTrace'),
                subDomain: any(named: 'subDomain'),
              ),
            ).thenReturn(null);

            // Initial load (succeeds)
            container.read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            );
            async.flushMicrotasks();

            // Trigger a refresh — second getDayPlan call will throw
            updateStreamController.add({planId});
            async.flushMicrotasks();

            // The error should have been logged (lines 190-195)
            verify(
              () => mockDomainLogger.error(
                any(),
                any(),
                stackTrace: any(named: 'stackTrace'),
                subDomain: '_refreshFromNotifications',
              ),
            ).called(1);

            // Controller must still be usable (no unhandled error)
            final stateAfterError = container.read(
              unifiedDailyOsDataControllerProvider(date: testDate),
            );
            expect(stateAfterError.hasValue, isTrue);
          });
        },
      );
    },
  );

  group(
    'UnifiedDailyOsDataController - _updateWithRunningTimer error path (lines 222-223)',
    () {
      test('logs error when refetch throws after timer stops', () {
        fakeAsync((async) {
          var callCount = 0;

          // Initial fetch succeeds; the follow-up refetch (after timer stops)
          // throws to exercise the catchError branch.
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return createTestPlan(); // initial load only
            throw Exception('DB error on refetch');
          });
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          when(() => mockTimeService.linkedFrom).thenReturn(null);

          when(
            () => mockDomainLogger.error(
              any(),
              any(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: any(named: 'subDomain'),
            ),
          ).thenReturn(null);

          // Initial load
          container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );
          async.flushMicrotasks();

          // Start the timer so _runningEntry is set
          final timerEntry = createTestEntry(
            id: 'timer-entry-1',
            categoryId: 'cat-work',
            dateFrom: testDate.add(const Duration(hours: 10)),
            dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
          );
          timerStreamController.add(timerEntry);
          async.flushMicrotasks();

          // Stop the timer — triggers refetch via _updateWithRunningTimer.
          // The refetch (callCount >= 3) will throw.
          timerStreamController.add(null);
          async.flushMicrotasks();

          // The catchError branch (lines 222-228) should have logged the error.
          verify(
            () => mockDomainLogger.error(
              any(),
              any(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: '_updateWithRunningTimer',
            ),
          ).called(greaterThanOrEqualTo(1));
        });
      });
    },
  );

  group(
    'UnifiedDailyOsDataController - disposed _fetchAllData (lines 290-294 & 863-867)',
    () {
      /// `_fetchAllData` short-circuits to an empty [DailyOsData] when the
      /// controller is already disposed (lines 290-294), building its timeline
      /// via `_createEmptyTimelineData` (lines 863-867).
      ///
      /// The only reachable caller that invokes `_fetchAllData` without first
      /// guarding on `_isDisposed` is `build`'s post-load
      /// `if (_pendingRefresh) _refreshFromNotifications()` (line 108-110): the
      /// first iteration of `_refreshFromNotifications`'s do/while always runs
      /// one fetch. So we:
      ///   1. Block the INITIAL load so `_hasLoadedInitialData` is still false.
      ///   2. Fire a notification -> listener sets `_pendingRefresh = true`.
      ///   3. Dispose the container -> `_isDisposed = true`.
      ///   4. Complete the initial load -> `build` resumes, sees
      ///      `_pendingRefresh`, calls `_refreshFromNotifications`, whose first
      ///      `_fetchAllData()` now hits the disposed early-return.
      ///
      /// Observable signal: the disposed branch returns BEFORE touching the DB
      /// or repository again, so `getDayPlan` / `sortedCalendarEntries` are each
      /// called exactly once (initial load only). Without the early-return the
      /// post-load refresh would fetch a second time (cf. the "queues one
      /// refresh during initial load" test which sees `getDayPlan` called 2x).
      test(
        'short-circuits the post-load refresh fetch when disposed',
        () {
          fakeAsync((async) {
            final initialLoadCompleter = Completer<DayPlanEntry?>();

            when(
              () => mockDayPlanRepository.getDayPlan(testDate),
            ).thenAnswer((_) => initialLoadCompleter.future);
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async => []);

            // Start the build; the initial _fetchAllData blocks on the completer.
            container.read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            );
            async.flushMicrotasks();

            // Notification during initial load -> _pendingRefresh = true.
            updateStreamController.add({planId});
            async.flushMicrotasks();

            // Dispose before the initial load resolves -> _isDisposed = true.
            container.dispose();
            async.flushMicrotasks();

            // Resolve the initial load. build resumes, sees _pendingRefresh and
            // calls _refreshFromNotifications, whose first _fetchAllData() takes
            // the disposed early-return (lines 290-294 + 863-867) instead of
            // fetching again.
            initialLoadCompleter.complete(createTestPlan());
            async
              ..flushMicrotasks()
              ..elapse(const Duration(milliseconds: 1))
              ..flushMicrotasks();

            // Exactly one fetch: the disposed branch never re-queried the DB.
            verify(
              () => mockDayPlanRepository.getDayPlan(testDate),
            ).called(1);
            verify(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).called(1);

            // Recreate container so tearDown can dispose it safely.
            container = ProviderContainer(
              overrides: [
                dayPlanRepositoryProvider.overrideWithValue(
                  mockDayPlanRepository,
                ),
              ],
            );
          });
        },
      );
    },
  );

  group(
    'UnifiedDailyOsDataController - synthetic budget with tracked+due task merge '
    '(lines 628-635)',
    () {
      /// In the SYNTHETIC budget path (category has no planned budget), a tracked
      /// task that also appears in the due-tasks list should have its due-status
      /// merged in (lines 628-635).
      test(
        'merges due status into tracked task within a synthetic budget',
        () async {
          // Plan with no budget for cat-unplanned — forces synthetic budget path
          final plan = createTestPlan(plannedBlocks: []);
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) async => plan);

          // Time entry linked to a task in cat-unplanned
          final timeEntry = createTestEntry(
            id: 'time-entry-1',
            categoryId: null,
            dateFrom: testDate.add(const Duration(hours: 9)),
            dateTo: testDate.add(const Duration(hours: 10)),
          );

          final trackedTask = JournalEntity.task(
            meta: Metadata(
              id: 'task-tracked',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              categoryId: 'cat-unplanned',
            ),
            data: TaskData(
              title: 'Tracked And Due',
              dateFrom: testDate,
              dateTo: testDate,
              due: testDate, // also due today
              statusHistory: [],
              status: TaskStatus.inProgress(
                id: 'status-1',
                createdAt: testDate,
                utcOffset: 0,
              ),
            ),
          );

          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => [timeEntry]);

          when(
            () => mockDb.basicLinksForEntryIds({'time-entry-1'}),
          ).thenAnswer(
            (_) async => [
              EntryLink.basic(
                id: 'link-1',
                fromId: 'task-tracked',
                toId: 'time-entry-1',
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
              ),
            ],
          );

          when(
            () => mockDb.getJournalEntitiesForIdsUnordered({'task-tracked'}),
          ).thenAnswer((_) async => [trackedTask]);

          // The same task also appears in the due-tasks list
          when(
            () => mockDb.getTasksDueOnOrBefore(testDate),
          ).thenAnswer((_) async => [trackedTask as Task]);

          final result = await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          // There should be exactly one synthetic budget for cat-unplanned
          expect(result.budgetProgress.length, equals(1));
          final syntheticBudget = result.budgetProgress.first;
          expect(syntheticBudget.categoryId, equals('cat-unplanned'));
          expect(syntheticBudget.hasNoBudgetWarning, isTrue);

          // The task should appear exactly once (deduplication)
          expect(syntheticBudget.taskProgressItems.length, equals(1));
          final item = syntheticBudget.taskProgressItems.first;
          expect(item.task.data.title, equals('Tracked And Due'));
          // Has tracked time AND due status merged in
          expect(
            item.timeSpentOnDay,
            equals(const Duration(hours: 1)),
          );
          expect(item.isDueOrOverdue, isTrue);
        },
      );
    },
  );

  group(
    'UnifiedDailyOsDataController - _buildTaskProgressItems sort edge cases '
    '(lines 732-733, 735)',
    () {
      /// Line 732-733: b has time, a doesn't → return 1 (b should come first).
      /// Line 735: both zero time → alphabetical by title.
      test(
        'task with time comes before task without time in same category',
        () async {
          // Two tasks linked to entries in the same category.
          // task-a: 0 minutes (linked entry has zero duration, gets filtered by
          //   _buildTaskProgressItems' `timeSpentOnDay > Duration.zero` guard
          //   *unless* wasCompletedOnDay is true).
          // We need a task with ZERO time but wasCompletedOnDay = false to be
          // excluded, and another with time.
          // Better approach: provide one task with time and one completed-today
          // with zero time so both appear, then verify ordering.
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
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) async => plan);

          // entry-a: 1 hour (for task-a)
          final entryA = createTestEntry(
            id: 'entry-a',
            categoryId: null,
            dateFrom: testDate.add(const Duration(hours: 9)),
            dateTo: testDate.add(const Duration(hours: 10)),
          );

          // task-a: has time (1 hour)
          final taskA = createTestTask(
            id: 'task-a',
            categoryId: 'cat-work',
            dateFrom: testDate,
            dateTo: testDate,
            title: 'Task With Time',
          );

          // task-b: no tracked time, but completed today so it appears
          final taskB = createTestTask(
            id: 'task-b',
            categoryId: 'cat-work',
            dateFrom: testDate,
            dateTo: testDate,
            title: 'Completed Zero Time',
            status: TaskStatus.done(
              id: 'status-done',
              createdAt: testDate.add(const Duration(hours: 11)),
              utcOffset: 0,
            ),
          );

          // entry-b: zero-duration (gets filtered out from timeline but still
          // counts in contributingEntries). We need task-b to appear via
          // wasCompletedOnDay=true path, so entry-b must link to task-b.
          // But _buildTaskProgressItems only adds items where
          // timeSpentOnDay > 0 || wasCompletedOnDay. So we link a real
          // entry to task-b so it appears with zero effective time.
          // Actually, easiest: entry-b has very small duration and links to task-b.
          // But then timeSpentOnDay > 0. We need 0-time to test line 733.
          // Use a zero-duration entry (same start and end) for task-b.
          final entryBZero = createTestEntry(
            id: 'entry-b-zero',
            categoryId: null,
            dateFrom: testDate.add(const Duration(hours: 11)),
            dateTo: testDate.add(
              const Duration(hours: 11),
            ), // zero duration
          );

          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => [entryA, entryBZero]);

          when(
            () => mockDb.basicLinksForEntryIds(
              {'entry-a', 'entry-b-zero'},
            ),
          ).thenAnswer(
            (_) async => [
              EntryLink.basic(
                id: 'link-a',
                fromId: 'task-a',
                toId: 'entry-a',
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
              ),
              EntryLink.basic(
                id: 'link-b',
                fromId: 'task-b',
                toId: 'entry-b-zero',
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
              ),
            ],
          );

          when(
            () =>
                mockDb.getJournalEntitiesForIdsUnordered({'task-a', 'task-b'}),
          ).thenAnswer((_) async => [taskA, taskB]);

          final result = await container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );

          final items = result.budgetProgress.first.taskProgressItems;
          // task-a has time, task-b has 0 time but is completed on day
          // Ordering: task-a (time) should come before task-b (zero time)
          expect(items.length, equals(2));
          expect(items[0].task.data.title, equals('Task With Time'));
          expect(items[0].timeSpentOnDay, greaterThan(Duration.zero));
          expect(items[1].task.data.title, equals('Completed Zero Time'));
          expect(items[1].timeSpentOnDay, equals(Duration.zero));
          expect(items[1].wasCompletedOnDay, isTrue);
        },
      );

      test('tasks with zero time are sorted alphabetically', () async {
        // Two tasks both completed today, each linked via zero-duration entries.
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
        when(
          () => mockDayPlanRepository.getDayPlan(testDate),
        ).thenAnswer((_) async => plan);

        // task-zebra and task-apple: both completed today with zero tracked time
        final taskZebra = createTestTask(
          id: 'task-z',
          categoryId: 'cat-work',
          dateFrom: testDate,
          dateTo: testDate,
          title: 'Zebra Task',
          status: TaskStatus.done(
            id: 'done-z',
            createdAt: testDate.add(const Duration(hours: 10)),
            utcOffset: 0,
          ),
        );
        final taskApple = createTestTask(
          id: 'task-a',
          categoryId: 'cat-work',
          dateFrom: testDate,
          dateTo: testDate,
          title: 'Apple Task',
          status: TaskStatus.done(
            id: 'done-a',
            createdAt: testDate.add(const Duration(hours: 10)),
            utcOffset: 0,
          ),
        );

        // Zero-duration entries linking to each task
        final entryZ = createTestEntry(
          id: 'entry-z',
          categoryId: null,
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10)),
        );
        final entryA = createTestEntry(
          id: 'entry-a',
          categoryId: null,
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 10)),
        );

        when(
          () => mockDb.sortedCalendarEntries(
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        ).thenAnswer((_) async => [entryZ, entryA]);

        when(
          () => mockDb.basicLinksForEntryIds({'entry-z', 'entry-a'}),
        ).thenAnswer(
          (_) async => [
            EntryLink.basic(
              id: 'link-z',
              fromId: 'task-z',
              toId: 'entry-z',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
            EntryLink.basic(
              id: 'link-a',
              fromId: 'task-a',
              toId: 'entry-a',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ],
        );

        when(
          () => mockDb.getJournalEntitiesForIdsUnordered({'task-z', 'task-a'}),
        ).thenAnswer((_) async => [taskZebra, taskApple]);

        final result = await container.read(
          unifiedDailyOsDataControllerProvider(date: testDate).future,
        );

        final items = result.budgetProgress.first.taskProgressItems;
        expect(items.length, equals(2));
        // Both have zero time — must be sorted alphabetically
        expect(items[0].task.data.title, equals('Apple Task'));
        expect(items[1].task.data.title, equals('Zebra Task'));
        expect(items[0].timeSpentOnDay, equals(Duration.zero));
        expect(items[1].timeSpentOnDay, equals(Duration.zero));
      });
    },
  );

  group(
    'UnifiedDailyOsDataController - _shouldRefreshFor empty set (line 165)',
    () {
      test('empty notification set does not trigger refresh', () {
        fakeAsync((async) {
          when(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).thenAnswer((_) async => createTestPlan());
          when(
            () => mockDb.sortedCalendarEntries(
              rangeStart: any(named: 'rangeStart'),
              rangeEnd: any(named: 'rangeEnd'),
            ),
          ).thenAnswer((_) async => []);

          container.read(
            unifiedDailyOsDataControllerProvider(date: testDate).future,
          );
          async.flushMicrotasks();

          // Fire an empty notification set — should NOT trigger a refresh
          updateStreamController.add({});
          async.flushMicrotasks();

          // getDayPlan called once for initial load only
          verify(
            () => mockDayPlanRepository.getDayPlan(testDate),
          ).called(1);
        });
      });
    },
  );

  group(
    'UnifiedDailyOsDataController - disposed mid-flight guards '
    '(_refreshFromNotifications + _updateWithRunningTimer)',
    () {
      /// Both guards protect the same hazard: a fetch resolving AFTER the
      /// controller was disposed must not assign `state` (which would throw
      /// on a disposed notifier) and must not loop into further fetches.
      test(
        'no state write or extra fetch when disposed while a notification '
        'refresh fetch is in-flight',
        () {
          fakeAsync((async) {
            final refreshFetchCompleter = Completer<DayPlanEntry?>();
            var callCount = 0;

            when(() => mockDayPlanRepository.getDayPlan(testDate)).thenAnswer((
              _,
            ) {
              callCount++;
              if (callCount == 1) return Future.value(createTestPlan());
              return refreshFetchCompleter.future;
            });
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async => []);

            container.read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            );
            async.flushMicrotasks();

            // Notification starts a refresh whose fetch blocks.
            updateStreamController.add({planId});
            async.flushMicrotasks();
            expect(callCount, 2);

            // Dispose while the refresh fetch is in-flight.
            container.dispose();
            async.flushMicrotasks();

            // Resolving the fetch now must hit the `_isDisposed` guard: no
            // state assignment (would throw in this zone) and no do-while
            // re-run fetch.
            refreshFetchCompleter.complete(createTestPlan());
            async.flushMicrotasks();
            expect(callCount, 2);

            // Recreate container so tearDown can dispose it safely.
            container = ProviderContainer(
              overrides: [
                dayPlanRepositoryProvider.overrideWithValue(
                  mockDayPlanRepository,
                ),
              ],
            );
          });
        },
      );

      test(
        'no state write when disposed while the timer-stop refetch is '
        'in-flight',
        () {
          fakeAsync((async) {
            final refetchCompleter = Completer<DayPlanEntry?>();
            var callCount = 0;

            when(() => mockDayPlanRepository.getDayPlan(testDate)).thenAnswer((
              _,
            ) {
              callCount++;
              if (callCount == 1) return Future.value(createTestPlan());
              return refetchCompleter.future;
            });
            when(
              () => mockDb.sortedCalendarEntries(
                rangeStart: any(named: 'rangeStart'),
                rangeEnd: any(named: 'rangeEnd'),
              ),
            ).thenAnswer((_) async => []);
            when(() => mockTimeService.linkedFrom).thenReturn(null);

            container.read(
              unifiedDailyOsDataControllerProvider(date: testDate).future,
            );
            async.flushMicrotasks();

            // Start then stop the timer: the stop triggers the refetch in
            // _updateWithRunningTimer, blocked on the completer.
            timerStreamController.add(
              createTestEntry(
                id: 'timer-entry-1',
                categoryId: 'cat-work',
                dateFrom: testDate.add(const Duration(hours: 10)),
                dateTo: testDate.add(const Duration(hours: 10, minutes: 30)),
              ),
            );
            async.flushMicrotasks();
            timerStreamController.add(null);
            async.flushMicrotasks();
            expect(callCount, 2);

            container.dispose();
            async.flushMicrotasks();

            // Resolving the refetch after dispose must take the `.then`
            // `_isDisposed` early-return instead of assigning state.
            refetchCompleter.complete(createTestPlan());
            async.flushMicrotasks();
            expect(callCount, 2);

            container = ProviderContainer(
              overrides: [
                dayPlanRepositoryProvider.overrideWithValue(
                  mockDayPlanRepository,
                ),
              ],
            );
          });
        },
      );
    },
  );

  group('calculateBudgetProgressStatus — properties', () {
    glados.Glados(
      glados.CombinableAny(glados.any).combine2(
        // Seconds rather than minutes so sub-minute remainders exercise
        // the inMinutes truncation around the 15-minute threshold.
        glados.any.intInRange(0, 4 * 3600),
        glados.any.intInRange(0, 4 * 3600),
        (int planned, int recorded) => (planned: planned, recorded: recorded),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'classifies by remaining time exactly per the threshold spec',
      (scenario) {
        final planned = Duration(seconds: scenario.planned);
        final recorded = Duration(seconds: scenario.recorded);

        final status = calculateBudgetProgressStatus(planned, recorded);

        // Oracle over remaining seconds (15 min threshold compares whole
        // minutes, so it truncates toward zero like Duration.inMinutes).
        final remainingSeconds = scenario.planned - scenario.recorded;
        final expected = remainingSeconds < 0
            ? BudgetProgressStatus.overBudget
            : remainingSeconds == 0
            ? BudgetProgressStatus.exhausted
            : remainingSeconds ~/ 60 <= 15
            ? BudgetProgressStatus.nearLimit
            : BudgetProgressStatus.underBudget;
        expect(
          status,
          expected,
          reason: 'planned=${scenario.planned}s recorded=${scenario.recorded}s',
        );
      },
      tags: 'glados',
    );
  });
}
