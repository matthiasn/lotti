import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

class MockTimeService extends Mock implements TimeService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  DayPlanEntry createTestPlan({
    DayPlanStatus status = const DayPlanStatus.draft(),
    List<PlannedBlock> plannedBlocks = const [],
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(testDate),
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: status,
        plannedBlocks: plannedBlocks,
      ),
    );
  }

  DailyTimelineData createTestTimelineData() {
    return DailyTimelineData(
      date: testDate,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }

  group('DailyOsState', () {
    test('isDraft returns true for draft plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isTrue);
      expect(state.isAgreed, isFalse);
      expect(state.needsReview, isFalse);
    });

    test('isAgreed returns true for agreed plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          status: DayPlanStatus.agreed(agreedAt: testDate),
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isFalse);
      expect(state.isAgreed, isTrue);
      expect(state.needsReview, isFalse);
    });

    test('needsReview returns true for needsReview plans', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          status: DayPlanStatus.needsReview(
            triggeredAt: testDate,
            reason: DayPlanReviewReason.blockModified,
          ),
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isFalse);
      expect(state.isAgreed, isFalse);
      expect(state.needsReview, isTrue);
    });

    test('isToday returns true when selectedDate is today', () {
      final today = DateTime.now().dayAtMidnight;
      final state = DailyOsState(
        selectedDate: today,
        dayPlan: null,
        budgetProgress: [],
        timelineData: DailyTimelineData(
          date: today,
          plannedSlots: [],
          actualSlots: [],
          dayStartHour: 8,
          dayEndHour: 18,
        ),
      );

      expect(state.isToday, isTrue);
    });

    test('isToday returns false when selectedDate is not today', () {
      final state = DailyOsState(
        selectedDate: testDate, // Jan 15, 2026
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isToday, isFalse);
    });

    test('totalBudgetedTime sums planned block durations', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-1',
              startTime: testDate.add(const Duration(hours: 9)),
              endTime: testDate.add(const Duration(hours: 11)), // 2 hours
            ),
            PlannedBlock(
              id: 'block-2',
              categoryId: 'cat-2',
              startTime: testDate.add(const Duration(hours: 14)),
              endTime: testDate.add(const Duration(hours: 15)), // 1 hour
            ),
          ],
        ),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.totalBudgetedTime, equals(const Duration(hours: 3)));
    });

    test('totalBudgetedTime returns zero when no plan', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.totalBudgetedTime, equals(Duration.zero));
    });

    test('totalRecordedTime sums budget progress durations', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [
          const TimeBudgetProgress(
            categoryId: 'cat-1',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 1, minutes: 30),
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            taskProgressItems: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-2',
            category: null,
            plannedDuration: Duration(hours: 1),
            recordedDuration: Duration(minutes: 45),
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            taskProgressItems: [],
          ),
        ],
        timelineData: createTestTimelineData(),
      );

      expect(
        state.totalRecordedTime,
        equals(const Duration(hours: 2, minutes: 15)),
      );
    });

    test('overBudgetCount counts budgets over their limit', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [
          const TimeBudgetProgress(
            categoryId: 'cat-1',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 3), // Over by 1 hour
            status: BudgetProgressStatus.overBudget,
            blocks: [],
            contributingEntries: [],
            taskProgressItems: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-2',
            category: null,
            plannedDuration: Duration(hours: 2),
            recordedDuration: Duration(hours: 1), // Under
            status: BudgetProgressStatus.underBudget,
            blocks: [],
            contributingEntries: [],
            taskProgressItems: [],
          ),
          const TimeBudgetProgress(
            categoryId: 'cat-3',
            category: null,
            plannedDuration: Duration(hours: 1),
            recordedDuration: Duration(hours: 1, minutes: 30), // Over
            status: BudgetProgressStatus.overBudget,
            blocks: [],
            contributingEntries: [],
            taskProgressItems: [],
          ),
        ],
        timelineData: createTestTimelineData(),
      );

      expect(state.overBudgetCount, equals(2));
    });

    test('copyWith creates new state with specified changes', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: createTestPlan(),
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith(
        isEditingPlan: true,
        highlightedCategoryId: 'cat-2',
      );

      expect(modified.isEditingPlan, isTrue);
      expect(modified.highlightedCategoryId, equals('cat-2'));
      // Original unchanged
      expect(original.isEditingPlan, isFalse);
      expect(original.highlightedCategoryId, equals('cat-1'));
    });

    test('copyWith with clearExpandedSection clears section', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedSection: DailyOsSection.timeline,
      );

      final modified = original.copyWith(clearExpandedSection: true);

      expect(modified.expandedSection, isNull);
    });

    test('copyWith with clearHighlight clears highlight', () {
      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith(clearHighlight: true);

      expect(modified.highlightedCategoryId, isNull);
    });

    test('copyWith preserves values when not specified', () {
      final plan = createTestPlan();
      final timeline = createTestTimelineData();
      final budgets = [
        const TimeBudgetProgress(
          categoryId: 'cat-1',
          category: null,
          plannedDuration: Duration(hours: 1),
          recordedDuration: Duration.zero,
          status: BudgetProgressStatus.underBudget,
          blocks: [],
          contributingEntries: [],
          taskProgressItems: [],
        ),
      ];

      final original = DailyOsState(
        selectedDate: testDate,
        dayPlan: plan,
        budgetProgress: budgets,
        timelineData: timeline,
        expandedSection: DailyOsSection.budgets,
        isEditingPlan: true,
        highlightedCategoryId: 'cat-1',
      );

      final modified = original.copyWith();

      expect(modified.selectedDate, equals(testDate));
      expect(modified.dayPlan, equals(plan));
      expect(modified.budgetProgress, equals(budgets));
      expect(modified.timelineData, equals(timeline));
      expect(modified.expandedSection, equals(DailyOsSection.budgets));
      expect(modified.isEditingPlan, isTrue);
      expect(modified.highlightedCategoryId, equals('cat-1'));
    });
  });

  group('DailyOsSection', () {
    test('enum has correct values', () {
      expect(DailyOsSection.values.length, equals(3));
      expect(DailyOsSection.values, contains(DailyOsSection.timeline));
      expect(DailyOsSection.values, contains(DailyOsSection.budgets));
      expect(DailyOsSection.values, contains(DailyOsSection.summary));
    });
  });

  group('DailyOsState computed properties', () {
    test('isDraft returns true when dayPlan is null', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isDraft, isTrue);
    });

    test('isAgreed returns false when dayPlan is null', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isAgreed, isFalse);
    });

    test('needsReview returns false when dayPlan is null', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.needsReview, isFalse);
    });

    test('overBudgetCount returns zero with empty budgets', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.overBudgetCount, equals(0));
    });

    test('totalRecordedTime returns zero with empty budgets', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.totalRecordedTime, equals(Duration.zero));
    });
  });

  group('DailyOsState expandedSection', () {
    test('default expandedSection is null', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.expandedSection, isNull);
    });

    test('can set expandedSection via constructor', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedSection: DailyOsSection.timeline,
      );

      expect(state.expandedSection, equals(DailyOsSection.timeline));
    });

    test('copyWith changes expandedSection', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      final modified = state.copyWith(expandedSection: DailyOsSection.budgets);

      expect(modified.expandedSection, equals(DailyOsSection.budgets));
    });
  });

  group('DailyOsState isEditingPlan', () {
    test('default isEditingPlan is false', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.isEditingPlan, isFalse);
    });

    test('can set isEditingPlan via constructor', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        isEditingPlan: true,
      );

      expect(state.isEditingPlan, isTrue);
    });
  });

  group('DailyOsState highlightedCategoryId', () {
    test('default highlightedCategoryId is null', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.highlightedCategoryId, isNull);
    });

    test('can set highlightedCategoryId via constructor', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-123',
      );

      expect(state.highlightedCategoryId, equals('cat-123'));
    });

    test('copyWith changes highlightedCategoryId', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        highlightedCategoryId: 'cat-old',
      );

      final modified = state.copyWith(highlightedCategoryId: 'cat-new');

      expect(modified.highlightedCategoryId, equals('cat-new'));
    });
  });

  group('DailyOsState expandedFoldRegions', () {
    test('default expandedFoldRegions is empty', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
      );

      expect(state.expandedFoldRegions, isEmpty);
    });

    test('can set expandedFoldRegions via constructor', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0, 18},
      );

      expect(state.expandedFoldRegions, equals({0, 18}));
    });

    test('copyWith changes expandedFoldRegions', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0},
      );

      final modified = state.copyWith(expandedFoldRegions: {0, 12, 18});

      expect(modified.expandedFoldRegions, equals({0, 12, 18}));
    });

    test('copyWith preserves expandedFoldRegions when not specified', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {6, 22},
      );

      final modified = state.copyWith(isEditingPlan: true);

      expect(modified.expandedFoldRegions, equals({6, 22}));
    });

    test('copyWith can set expandedFoldRegions to empty set', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0, 18},
      );

      final modified = state.copyWith(expandedFoldRegions: {});

      expect(modified.expandedFoldRegions, isEmpty);
    });
  });

  group('DailyOsState fold region toggle logic', () {
    test('adding startHour to expandedFoldRegions expands that region', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {},
      );

      // Simulate toggling region starting at hour 0
      final currentRegions = state.expandedFoldRegions;
      final updatedRegions = {...currentRegions, 0};

      final modified = state.copyWith(expandedFoldRegions: updatedRegions);

      expect(modified.expandedFoldRegions.contains(0), isTrue);
    });

    test('removing startHour from expandedFoldRegions collapses that region',
        () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0, 18},
      );

      // Simulate toggling region starting at hour 0 (collapsing it)
      final currentRegions = state.expandedFoldRegions;
      final updatedRegions = currentRegions.where((r) => r != 0).toSet();

      final modified = state.copyWith(expandedFoldRegions: updatedRegions);

      expect(modified.expandedFoldRegions.contains(0), isFalse);
      expect(modified.expandedFoldRegions.contains(18), isTrue);
    });

    test('multiple regions can be expanded simultaneously', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0, 6, 18, 22},
      );

      expect(state.expandedFoldRegions.length, equals(4));
      expect(state.expandedFoldRegions.containsAll({0, 6, 18, 22}), isTrue);
    });
  });

  group('DailyOsController fold region toggle logic (simulated)', () {
    // These tests simulate the controller's toggleFoldRegion behavior
    // by applying the same state transformation logic

    Set<int> simulateToggleFoldRegion(Set<int> currentRegions, int startHour) {
      if (currentRegions.contains(startHour)) {
        return currentRegions.where((r) => r != startHour).toSet();
      } else {
        return {...currentRegions, startHour};
      }
    }

    test('toggleFoldRegion adds region when not present', () {
      const currentRegions = <int>{};
      final updated = simulateToggleFoldRegion(currentRegions, 6);

      expect(updated, contains(6));
      expect(updated.length, equals(1));
    });

    test('toggleFoldRegion removes region when present', () {
      const currentRegions = {6, 18};
      final updated = simulateToggleFoldRegion(currentRegions, 6);

      expect(updated, isNot(contains(6)));
      expect(updated, contains(18));
      expect(updated.length, equals(1));
    });

    test('toggleFoldRegion is idempotent on double toggle', () {
      const currentRegions = <int>{};
      final afterFirstToggle = simulateToggleFoldRegion(currentRegions, 6);
      final afterSecondToggle = simulateToggleFoldRegion(afterFirstToggle, 6);

      expect(afterSecondToggle, equals(currentRegions));
    });

    test('toggleFoldRegion handles multiple independent toggles', () {
      var regions = <int>{};
      regions = simulateToggleFoldRegion(regions, 0);
      regions = simulateToggleFoldRegion(regions, 12);
      regions = simulateToggleFoldRegion(regions, 22);

      expect(regions, equals({0, 12, 22}));

      regions = simulateToggleFoldRegion(regions, 12);
      expect(regions, equals({0, 22}));
    });

    test('resetFoldState clears all regions', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedFoldRegions: {0, 6, 12, 18, 22},
      );

      // Simulate resetFoldState
      final reset = state.copyWith(expandedFoldRegions: {});

      expect(reset.expandedFoldRegions, isEmpty);
    });

    test('toggle does not affect other state properties', () {
      final state = DailyOsState(
        selectedDate: testDate,
        dayPlan: null,
        budgetProgress: [],
        timelineData: createTestTimelineData(),
        expandedSection: DailyOsSection.timeline,
        highlightedCategoryId: 'cat-1',
        isEditingPlan: true,
      );

      final toggled = state.copyWith(
        expandedFoldRegions: {...state.expandedFoldRegions, 6},
      );

      expect(toggled.expandedSection, equals(DailyOsSection.timeline));
      expect(toggled.highlightedCategoryId, equals('cat-1'));
      expect(toggled.isEditingPlan, isTrue);
      expect(toggled.expandedFoldRegions, contains(6));
    });
  });

  group('RunningTimerCategoryId', () {
    late MockTimeService mockTimeService;
    late StreamController<JournalEntity?> timerStreamController;
    late ProviderContainer container;

    setUp(() {
      mockTimeService = MockTimeService();
      timerStreamController = StreamController<JournalEntity?>.broadcast();

      when(() => mockTimeService.getStream())
          .thenAnswer((_) => timerStreamController.stream);

      getIt.allowReassignment = true;
      getIt.registerSingleton<TimeService>(mockTimeService);

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      timerStreamController.close();
      getIt.reset();
    });

    test('returns null when no timer is running', () {
      when(() => mockTimeService.getCurrent()).thenReturn(null);
      when(() => mockTimeService.linkedFrom).thenReturn(null);

      final result = container.read(runningTimerCategoryIdProvider);

      expect(result, isNull);
    });

    test('returns category ID from linkedFrom when available', () {
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 30)),
          categoryId: 'entry-category',
        ),
      );

      final linkedTask = JournalEntity.task(
        meta: Metadata(
          id: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'task-category',
        ),
        data: TaskData(
          title: 'Test Task',
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: const [],
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
        ),
      );

      when(() => mockTimeService.getCurrent()).thenReturn(entry);
      when(() => mockTimeService.linkedFrom).thenReturn(linkedTask);

      final result = container.read(runningTimerCategoryIdProvider);

      expect(result, equals('task-category'));
    });

    test('returns category ID from entry when linkedFrom is null', () {
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 30)),
          categoryId: 'entry-category',
        ),
      );

      when(() => mockTimeService.getCurrent()).thenReturn(entry);
      when(() => mockTimeService.linkedFrom).thenReturn(null);

      final result = container.read(runningTimerCategoryIdProvider);

      expect(result, equals('entry-category'));
    });

    test('returns null when entry has no category', () {
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 30)),
        ),
      );

      when(() => mockTimeService.getCurrent()).thenReturn(entry);
      when(() => mockTimeService.linkedFrom).thenReturn(null);

      final result = container.read(runningTimerCategoryIdProvider);

      expect(result, isNull);
    });

    test('updates when timer stream emits', () async {
      when(() => mockTimeService.getCurrent()).thenReturn(null);
      when(() => mockTimeService.linkedFrom).thenReturn(null);

      // Initial state - no timer
      expect(container.read(runningTimerCategoryIdProvider), isNull);

      // Start a timer
      final entry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate.add(const Duration(minutes: 30)),
          categoryId: 'work',
        ),
      );

      when(() => mockTimeService.getCurrent()).thenReturn(entry);
      timerStreamController.add(entry);

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);

      expect(container.read(runningTimerCategoryIdProvider), equals('work'));
    });
  });

  group('activeFocusCategoryId', () {
    late ProviderContainer container;

    final testDateToday = DateTime.now().dayAtMidnight;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(testDateToday),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('returns null when selected date is not today', () async {
      final yesterday = testDateToday.subtract(const Duration(days: 1));

      final testContainer = ProviderContainer(
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(yesterday),
          unifiedDailyOsDataControllerProvider(date: yesterday).overrideWith(
            () => _TestUnifiedController(
              DailyOsData(
                date: yesterday,
                dayPlan: createTestPlan(),
                timelineData: createTestTimelineData(),
                budgetProgress: [],
              ),
            ),
          ),
        ],
      );

      // Use a completer to wait for the first data emission
      final completer = Completer<String?>();
      testContainer.listen<AsyncValue<String?>>(
        activeFocusCategoryIdProvider,
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      expect(result, isNull);

      testContainer.dispose();
    });

    test('returns category ID when current time is within a planned block',
        () async {
      final now = DateTime.now();
      final today = now.dayAtMidnight;

      // Create a planned block that contains the current time
      final blockStart = now.subtract(const Duration(minutes: 30));
      final blockEnd = now.add(const Duration(minutes: 30));

      final plannedSlots = [
        PlannedTimeSlot(
          startTime: blockStart,
          endTime: blockEnd,
          block: PlannedBlock(
            id: 'block-1',
            categoryId: 'cat-work',
            startTime: blockStart,
            endTime: blockEnd,
          ),
          categoryId: 'cat-work',
        ),
      ];

      final timelineData = DailyTimelineData(
        date: today,
        plannedSlots: plannedSlots,
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      final testData = DailyOsData(
        date: today,
        dayPlan: createTestPlan(
          plannedBlocks: [
            PlannedBlock(
              id: 'block-1',
              categoryId: 'cat-work',
              startTime: blockStart,
              endTime: blockEnd,
            ),
          ],
        ),
        timelineData: timelineData,
        budgetProgress: [],
      );

      final testContainer = ProviderContainer(
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(today),
          unifiedDailyOsDataControllerProvider(date: today).overrideWith(
            () => _TestUnifiedController(testData),
          ),
        ],
      );

      // Wait for the unified data to be loaded first
      await testContainer
          .read(unifiedDailyOsDataControllerProvider(date: today).future);

      // Use a completer to wait for the first data emission
      final completer = Completer<String?>();
      testContainer.listen<AsyncValue<String?>>(
        activeFocusCategoryIdProvider,
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      expect(result, equals('cat-work'));

      testContainer.dispose();
    });

    test('returns null when no planned block contains current time', () async {
      final now = DateTime.now();
      final today = now.dayAtMidnight;

      // Create planned blocks that do NOT contain the current time
      final pastBlockEnd = now.subtract(const Duration(hours: 2));
      final pastBlockStart = now.subtract(const Duration(hours: 3));
      final futureBlockStart = now.add(const Duration(hours: 1));
      final futureBlockEnd = now.add(const Duration(hours: 2));

      final plannedSlots = [
        PlannedTimeSlot(
          startTime: pastBlockStart,
          endTime: pastBlockEnd,
          block: PlannedBlock(
            id: 'block-past',
            categoryId: 'cat-past',
            startTime: pastBlockStart,
            endTime: pastBlockEnd,
          ),
          categoryId: 'cat-past',
        ),
        PlannedTimeSlot(
          startTime: futureBlockStart,
          endTime: futureBlockEnd,
          block: PlannedBlock(
            id: 'block-future',
            categoryId: 'cat-future',
            startTime: futureBlockStart,
            endTime: futureBlockEnd,
          ),
          categoryId: 'cat-future',
        ),
      ];

      final timelineData = DailyTimelineData(
        date: today,
        plannedSlots: plannedSlots,
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      final testData = DailyOsData(
        date: today,
        dayPlan: createTestPlan(
          plannedBlocks: [
            PlannedBlock(
              id: 'block-past',
              categoryId: 'cat-past',
              startTime: pastBlockStart,
              endTime: pastBlockEnd,
            ),
            PlannedBlock(
              id: 'block-future',
              categoryId: 'cat-future',
              startTime: futureBlockStart,
              endTime: futureBlockEnd,
            ),
          ],
        ),
        timelineData: timelineData,
        budgetProgress: [],
      );

      final testContainer = ProviderContainer(
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(today),
          unifiedDailyOsDataControllerProvider(date: today).overrideWith(
            () => _TestUnifiedController(testData),
          ),
        ],
      );

      // Wait for the unified data to be loaded first
      await testContainer
          .read(unifiedDailyOsDataControllerProvider(date: today).future);

      // Use a completer to wait for the first data emission
      final completer = Completer<String?>();
      testContainer.listen<AsyncValue<String?>>(
        activeFocusCategoryIdProvider,
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      expect(result, isNull);

      testContainer.dispose();
    });

    test('returns null when no planned slots exist', () async {
      final now = DateTime.now();
      final today = now.dayAtMidnight;

      final timelineData = DailyTimelineData(
        date: today,
        plannedSlots: [], // No planned slots
        actualSlots: [],
        dayStartHour: 8,
        dayEndHour: 18,
      );

      final testData = DailyOsData(
        date: today,
        dayPlan: createTestPlan(),
        timelineData: timelineData,
        budgetProgress: [],
      );

      final testContainer = ProviderContainer(
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(today),
          unifiedDailyOsDataControllerProvider(date: today).overrideWith(
            () => _TestUnifiedController(testData),
          ),
        ],
      );

      // Wait for the unified data to be loaded first
      await testContainer
          .read(unifiedDailyOsDataControllerProvider(date: today).future);

      // Use a completer to wait for the first data emission
      final completer = Completer<String?>();
      testContainer.listen<AsyncValue<String?>>(
        activeFocusCategoryIdProvider,
        (previous, next) {
          if (next.hasValue && !completer.isCompleted) {
            completer.complete(next.value);
          }
        },
        fireImmediately: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      expect(result, isNull);

      testContainer.dispose();
    });
  });
}

/// Mock controller that returns fixed unified data for testing.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}
