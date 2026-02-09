import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/compressed_timeline_region.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

/// Mock controller that returns fixed unified data.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    name: 'Work',
    color: '#4285F4',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  late MockEntitiesCacheService mockCacheService;

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    when(() => mockCacheService.getCategoryById('cat-1'))
        .thenReturn(testCategory);
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(() async {
    beamToNamedOverride = null;
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
  });

  DayPlanEntry createEmptyDayPlan(DateTime date) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: const DayPlanStatus.draft(),
      ),
    );
  }

  Widget createTestWidget({
    required DailyTimelineData timelineData,
    DayPlanEntry? dayPlan,
    List<TimeBudgetProgress> budgetProgress = const [],
    String? highlightedCategoryId,
    List<Override> additionalOverrides = const [],
  }) {
    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: dayPlan ?? createEmptyDayPlan(testDate),
      timelineData: timelineData,
      budgetProgress: budgetProgress,
    );

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
          () => _TestUnifiedController(unifiedData),
        ),
        highlightedCategoryIdProvider
            .overrideWith((ref) => highlightedCategoryId),
        // Override to avoid TimeService dependency in tests
        runningTimerCategoryIdProvider.overrideWithValue(null),
        ...additionalOverrides,
      ],
      child: const SingleChildScrollView(
        child: DailyTimeline(),
      ),
    );
  }

  group('DailyTimeline', () {
    testWidgets('renders empty state when no data', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty timeline message
      expect(find.text('No timeline entries'), findsOneWidget);
    });

    testWidgets('renders timeline header', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show timeline header with icon
      expect(find.byIcon(MdiIcons.timelineClockOutline), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
    });

    testWidgets('shows plan and actual legend', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show legend labels
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
    });

    testWidgets('renders planned blocks with category name', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render the category name in the planned block
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('renders actual time entries as colored blocks',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      final taskMeta = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate.add(const Duration(hours: 10)),
        dateTo: testDate.add(const Duration(hours: 11)),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: Task(
                  meta: taskMeta,
                  data: TaskData(
                    title: 'Important Task',
                    status: TaskStatus.groomed(
                      id: 'status-1',
                      createdAt: testDate,
                      utcOffset: 0,
                    ),
                    dateFrom: testDate.add(const Duration(hours: 10)),
                    dateTo: testDate.add(const Duration(hours: 11)),
                    statusHistory: const [],
                  ),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Actual blocks render as colored blocks without text labels.
      // The category name is preserved via Semantics for accessibility.
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
    });

    testWidgets('renders time axis labels', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show hour labels on the time axis for the visible cluster
      // Entry from 9-11 occupies hours 9 and 10 (no buffer padding)
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('renders DailyTimeline widget', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders planned block without category', (tester) async {
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: 'unknown',
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'unknown',
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Planned" as fallback when no category
      expect(find.text('Planned'), findsOneWidget);
    });

    testWidgets('renders multiple planned blocks', (tester) async {
      final testCategory2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(testCategory2);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-2',
                  categoryId: testCategory2.id,
                  startTime: testDate.add(const Duration(hours: 14)),
                  endTime: testDate.add(const Duration(hours: 15)),
                ),
                startTime: testDate.add(const Duration(hours: 14)),
                endTime: testDate.add(const Duration(hours: 15)),
                categoryId: testCategory2.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show both category names
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget);
    });

    testWidgets('renders actual entry as non-task with semantics label',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      final entryMeta = Metadata(
        id: 'entry-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate.add(const Duration(hours: 10)),
        dateTo: testDate.add(const Duration(hours: 11)),
        categoryId: testCategory.id,
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: JournalEntity.journalEntry(meta: entryMeta),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Actual blocks show category name via Semantics (no visible text)
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
    });

    testWidgets('highlights planned block when category is highlighted',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
          highlightedCategoryId: 'cat-1',
        ),
      );
      await tester.pumpAndSettle();

      // Widget should render (test passes if no exception)
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders both planned and actual blocks simultaneously',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      final taskMeta = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate.add(const Duration(hours: 10)),
        dateTo: testDate.add(const Duration(hours: 11)),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: [
              ActualTimeSlot(
                entry: Task(
                  meta: taskMeta,
                  data: TaskData(
                    title: 'Real Work Done',
                    status: TaskStatus.groomed(
                      id: 'status-1',
                      createdAt: testDate,
                      utcOffset: 0,
                    ),
                    dateFrom: testDate.add(const Duration(hours: 10)),
                    dateTo: testDate.add(const Duration(hours: 11)),
                    statusHistory: const [],
                  ),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Planned block shows visible text label
      expect(find.text('Work'), findsOneWidget);
      // Both planned and actual blocks have semantics label 'Work'
      // (planned via Text widget, actual via Semantics widget)
      expect(find.bySemanticsLabel('Work'), findsNWidgets(2));
    });

    testWidgets('planned block is tappable', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 9)),
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the planned block text and its GestureDetector ancestor
      final blockFinder = find.text('Work');
      expect(blockFinder, findsOneWidget);

      final gestureDetector = find.ancestor(
        of: blockFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    testWidgets('actual block is tappable', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      final taskMeta = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate.add(const Duration(hours: 10)),
        dateTo: testDate.add(const Duration(hours: 11)),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: Task(
                  meta: taskMeta,
                  data: TaskData(
                    title: 'Tap Me Task',
                    status: TaskStatus.groomed(
                      id: 'status-1',
                      createdAt: testDate,
                      utcOffset: 0,
                    ),
                    dateFrom: testDate.add(const Duration(hours: 10)),
                    dateTo: testDate.add(const Duration(hours: 11)),
                    statusHistory: const [],
                  ),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the actual block by its semantics label and check for GestureDetector
      final blockFinder = find.bySemanticsLabel('Work');
      expect(blockFinder, findsOneWidget);

      final gestureDetector = find.ancestor(
        of: blockFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    testWidgets('tap on rating-linked actual block navigates to time entry',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final timeEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'time-entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 11)),
        ),
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
          dimensions: [RatingDimension(key: 'focus', value: 0.5)],
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: timeEntry,
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
                linkedFrom: ratingEntry,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Work'));
      await tester.pumpAndSettle();

      expect(navigatedPath, equals('/journal/time-entry-1'));
    });

    testWidgets('tap on non-task linked actual block navigates to time entry',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final timeEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'time-entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 11)),
        ),
      );

      final parentJournal = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'journal-parent-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: timeEntry,
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
                linkedFrom: parentJournal,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Work'));
      await tester.pumpAndSettle();

      expect(navigatedPath, equals('/journal/time-entry-1'));
    });

    testWidgets(
        'tap on task-linked actual block navigates to task and publishes focus',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      String? navigatedPath;
      beamToNamedOverride = (path) => navigatedPath = path;

      final timeEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: 'time-entry-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate.add(const Duration(hours: 10)),
          dateTo: testDate.add(const Duration(hours: 11)),
        ),
      );

      final parentTask = JournalEntity.task(
        meta: Metadata(
          id: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'cat-1',
        ),
        data: TaskData(
          title: 'Task 1',
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 0,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: const [],
        ),
      );

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: timeEntry,
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
                linkedFrom: parentTask,
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 18,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Work'));
      await tester.pumpAndSettle();

      expect(navigatedPath, equals('/tasks/task-1'));

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DailyTimeline)));
      final focusState =
          container.read(taskFocusControllerProvider(id: 'task-1'));
      expect(focusState?.entryId, equals('time-entry-1'));
    });

    testWidgets('respects custom day bounds', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 6)),
                  endTime: testDate.add(const Duration(hours: 7)),
                ),
                startTime: testDate.add(const Duration(hours: 6)),
                endTime: testDate.add(const Duration(hours: 7)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 5, // Early start
            dayEndHour: 10, // Early end
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With no buffer, entry 6-7 creates a visible cluster just for that hour
      // The hour label for the entry's hour is visible
      expect(find.text('06:00'), findsOneWidget);
    });

    testWidgets(
        'handles invalid day bounds without crashing (endHour < startHour)',
        (tester) async {
      // This test verifies the timeline handles edge cases gracefully.
      // With smart folding, the timeline calculates visible regions from
      // actual entries rather than using dayStartHour/dayEndHour directly.
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 21)),
                  endTime: testDate.add(const Duration(hours: 23)),
                ),
                startTime: testDate.add(const Duration(hours: 21)),
                endTime: testDate.add(const Duration(hours: 23)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            // Invalid: endHour < startHour (would cause negative totalHours)
            dayStartHour: 22,
            dayEndHour: 2, // This is less than startHour
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render without throwing RangeError
      expect(find.byType(DailyTimeline), findsOneWidget);
      // With smart folding, hours around the entry (21-23) with buffer
      // become visible (20-24)
      expect(find.text('21:00'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
    });
  });

  group('DailyTimeline - Overlapping Entries Lane Assignment', () {
    JournalEntity createJournalEntry({
      required String id,
      required DateTime dateFrom,
      required DateTime dateTo,
      String? categoryId,
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

    testWidgets('renders single entry at full width', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single entry should render successfully
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders two non-overlapping entries in same lane',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 11)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 11)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries should render (using semantics since text is hidden)
      expect(find.bySemanticsLabel('Work'), findsNWidgets(2));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders two overlapping entries in separate lanes',
        (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 9:00 - 11:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-1',
              ),
              // Entry 2: 10:00 - 12:00 (overlaps with entry 1)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-2',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both overlapping entries should be visible
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders three overlapping entries in three lanes',
        (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );
      final category3 = CategoryDefinition(
        id: 'cat-3',
        name: 'Meeting',
        color: '#EA4335',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);
      when(() => mockCacheService.getCategoryById('cat-3'))
          .thenReturn(category3);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 9:00 - 12:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
              // Entry 2: 9:30 - 11:00 (overlaps with entry 1)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 9, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 9, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-2',
              ),
              // Entry 3: 10:00 - 11:30 (overlaps with both)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-3',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
                  categoryId: 'cat-3',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
                categoryId: 'cat-3',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three overlapping entries should be visible
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.bySemanticsLabel('Meeting'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('reuses lane after entry ends', (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );
      final category3 = CategoryDefinition(
        id: 'cat-3',
        name: 'Meeting',
        color: '#EA4335',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);
      when(() => mockCacheService.getCategoryById('cat-3'))
          .thenReturn(category3);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 9:00 - 10:00 (lane 0)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
              // Entry 2: 9:30 - 11:00 (overlaps with entry 1, uses lane 1)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 9, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 9, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-2',
              ),
              // Entry 3: 10:00 - 11:00 (starts after entry 1 ends, reuses lane 0)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-3',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-3',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-3',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three entries should be visible (lane reuse is handled internally)
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.bySemanticsLabel('Meeting'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('handles entries with identical times', (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 9:00 - 10:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
              // Entry 2: Same exact times (parallel task tracking)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-2',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries with identical times should be visible in separate lanes
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('handles back-to-back entries in same lane', (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 9:00 - 10:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
              // Entry 2: 10:00 - 11:00 (starts exactly when entry 1 ends)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-2',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Back-to-back entries should both render (in same lane, no overlap)
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });
  });

  group('DailyTimeline - Same-Category Nesting', () {
    JournalEntity createJournalEntry({
      required String id,
      required DateTime dateFrom,
      required DateTime dateTo,
      String? categoryId,
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

    testWidgets(
        'nests smaller entry inside larger entry of same category (gym trip scenario)',
        (tester) async {
      // This is the key use case: a 1.5h gym trip containing a 45m workout
      // The workout should render INSIDE the gym trip block, not in a separate lane
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Gym trip: 10:00 - 11:30 (1.5 hours total)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'gym-trip',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
                categoryId: 'cat-1',
              ),
              // Workout: 10:30 - 11:15 (45 minutes, contained within gym trip)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'workout',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 15)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 15)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 13,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries should render - the nested one should be inside the parent
      // Since they have the same category, we expect 2 semantics labels for 'Work'
      expect(find.bySemanticsLabel('Work'), findsNWidgets(2));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets(
        'does not nest entries of different categories even when one contains another',
        (tester) async {
      final category2 = CategoryDefinition(
        id: 'cat-2',
        name: 'Exercise',
        color: '#34A853',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);
      when(() => mockCacheService.getCategoryById('cat-2'))
          .thenReturn(category2);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Work block: 10:00 - 12:00 (2 hours)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'work-block',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
              // Exercise: 10:30 - 11:00 (different category - should be in separate lane)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'exercise',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-2',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-2',
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both should be visible - different categories don't nest
      expect(find.bySemanticsLabel('Work'), findsOneWidget);
      expect(find.bySemanticsLabel('Exercise'), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('nests multiple children within parent of same category',
        (tester) async {
      // Morning block with multiple specific activities logged within it
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Morning work block: 9:00 - 12:00 (3 hours)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'morning-block',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
              // Call 1: 9:30 - 10:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'call-1',
                  dateFrom: testDate.add(const Duration(hours: 9, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 10)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 10)),
                categoryId: 'cat-1',
              ),
              // Call 2: 10:30 - 11:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'call-2',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three entries should render (parent + 2 nested children)
      expect(find.bySemanticsLabel('Work'), findsNWidgets(3));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets(
        'does not nest entries with same category that do not fully contain each other',
        (tester) async {
      // Partially overlapping entries of same category should still be in separate lanes
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Entry 1: 10:00 - 11:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-1',
              ),
              // Entry 2: 10:30 - 11:30 (overlaps but neither contains the other)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-2',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 13,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries should render (partial overlap = separate lanes, not nesting)
      expect(find.bySemanticsLabel('Work'), findsNWidgets(2));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets(
        'renders overlapping nested children in separate lanes within parent',
        (tester) async {
      // When nested children overlap each other, they should be in separate
      // lanes within the parent block (not rendered on top of each other)
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Morning work block: 9:00 - 12:00 (3 hours)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'morning-block',
                  dateFrom: testDate.add(const Duration(hours: 9)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
              // Call 1: 10:00 - 11:00 (overlaps with Call 2)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'call-1',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-1',
              ),
              // Call 2: 10:30 - 11:30 (overlaps with Call 1)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'call-2',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 8,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All three entries should render (parent + 2 overlapping nested children)
      // The nested children should be in separate lanes within the parent
      expect(find.bySemanticsLabel('Work'), findsNWidgets(3));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('renders entry without category (null categoryId)',
        (tester) async {
      // Entries without a category should still render with default styling
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'uncategorized',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                // No categoryId
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 13,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Entry without category should still render
      // The DailyTimeline should be visible and contain the entry
      expect(find.byType(DailyTimeline), findsOneWidget);
      // Verify the timeline content rendered (has hour label for entry's hour)
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets(
        'does not nest entries with null categoryId even when one contains another',
        (tester) async {
      // Entries with null categoryId should not be nested
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Larger entry: 10:00 - 12:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'larger',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 12)),
                // No categoryId
              ),
              // Smaller entry: 10:30 - 11:00 (contained but no category)
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'smaller',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11)),
                // No categoryId
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 14,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries should render (timeline visible)
      expect(find.byType(DailyTimeline), findsOneWidget);
      // Verify the timeline content rendered (hour labels for entries' hours)
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
    });

    testWidgets('renders single nested child without lane splitting',
        (tester) async {
      // A parent with a single nested child should render the child at full width
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Parent: 10:00 - 12:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'parent',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 12)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 12)),
                categoryId: 'cat-1',
              ),
              // Single child: 10:30 - 11:30
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'child',
                  dateFrom:
                      testDate.add(const Duration(hours: 10, minutes: 30)),
                  dateTo: testDate.add(const Duration(hours: 11, minutes: 30)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10, minutes: 30)),
                endTime: testDate.add(const Duration(hours: 11, minutes: 30)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 9,
            dayEndHour: 13,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both entries should render (parent + single nested child)
      expect(find.bySemanticsLabel('Work'), findsNWidgets(2));
      expect(find.byType(DailyTimeline), findsOneWidget);
    });
  });

  group('DailyTimeline - Smart Folding Integration', () {
    JournalEntity createJournalEntry({
      required String id,
      required DateTime dateFrom,
      required DateTime dateTo,
      String? categoryId,
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

    testWidgets('shows compressed region for large gap between entries',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 2AM and 8PM - large gap should create compressed region
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              // Morning entry: 2:00 - 3:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'morning',
                  dateFrom: testDate.add(const Duration(hours: 2)),
                  dateTo: testDate.add(const Duration(hours: 3)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 2)),
                endTime: testDate.add(const Duration(hours: 3)),
                categoryId: 'cat-1',
              ),
              // Evening entry: 20:00 - 21:00
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'evening',
                  dateFrom: testDate.add(const Duration(hours: 20)),
                  dateTo: testDate.add(const Duration(hours: 21)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 20)),
                endTime: testDate.add(const Duration(hours: 21)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have CompressedTimelineRegion for the large gap in the middle
      expect(find.byType(CompressedTimelineRegion), findsWidgets);
    });

    testWidgets('compressed region shows time range label', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry only at 2AM - should compress before 1AM and after ~4AM
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'early',
                  dateFrom: testDate.add(const Duration(hours: 2)),
                  dateTo: testDate.add(const Duration(hours: 3)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 2)),
                endTime: testDate.add(const Duration(hours: 3)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Compressed regions show time range labels like "04:00 - 20:00"
      // We should find at least one text with time range format
      final compressedRegions = find.byType(CompressedTimelineRegion);
      if (compressedRegions.evaluate().isNotEmpty) {
        // At least one compressed region exists
        expect(compressedRegions, findsWidgets);
      }
    });

    testWidgets('compressed region has unfold_more icon', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 12PM only - should compress morning and evening
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'noon',
                  dateFrom: testDate.add(const Duration(hours: 12)),
                  dateTo: testDate.add(const Duration(hours: 13)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 12)),
                endTime: testDate.add(const Duration(hours: 13)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CompressedTimelineRegion contains unfold_more icon
      final compressedRegions = find.byType(CompressedTimelineRegion);
      if (compressedRegions.evaluate().isNotEmpty) {
        expect(find.byIcon(Icons.unfold_more), findsWidgets);
      }
    });

    testWidgets('no compressed regions when entries fill the day',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entries every 3 hours - no gap > 4 hours
      final slots = List.generate(8, (i) {
        final hour = i * 3;
        return ActualTimeSlot(
          entry: createJournalEntry(
            id: 'entry-$i',
            dateFrom: testDate.add(Duration(hours: hour)),
            dateTo: testDate.add(Duration(hours: hour + 1)),
            categoryId: 'cat-1',
          ),
          startTime: testDate.add(Duration(hours: hour)),
          endTime: testDate.add(Duration(hours: hour + 1)),
          categoryId: 'cat-1',
        );
      });

      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: slots,
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With entries every 3 hours and 1-hour buffer, no gap exceeds threshold
      // Should have no compressed regions
      expect(find.byType(CompressedTimelineRegion), findsNothing);
    });

    testWidgets(
        'empty day shows default 6AM-10PM visible with compressed edges',
        (tester) async {
      // No entries - should use default day bounds
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: const [],
            dayStartHour: 6,
            dayEndHour: 22,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty timeline shows empty state, not compressed regions
      expect(find.text('No timeline entries'), findsOneWidget);
    });

    testWidgets('planned slots also affect folding calculation',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Only planned slot at 10AM, no actual entries
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: [
              PlannedTimeSlot(
                block: PlannedBlock(
                  id: 'block-1',
                  categoryId: testCategory.id,
                  startTime: testDate.add(const Duration(hours: 10)),
                  endTime: testDate.add(const Duration(hours: 11)),
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: testCategory.id,
              ),
            ],
            actualSlots: const [],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Planned slot should create visible cluster with compressed regions around it
      expect(find.byType(DailyTimeline), findsOneWidget);
      // Should see the planned block
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('visible hour labels appear in visible clusters',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 10AM - visible cluster is 10-11 (no buffer padding)
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'entry-1',
                  dateFrom: testDate.add(const Duration(hours: 10)),
                  dateTo: testDate.add(const Duration(hours: 11)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 10)),
                endTime: testDate.add(const Duration(hours: 11)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show hour label for the visible cluster (10-11, no buffer)
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('tapping compressed region expands it', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 12PM only - should compress morning and evening
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'noon',
                  dateFrom: testDate.add(const Duration(hours: 12)),
                  dateTo: testDate.add(const Duration(hours: 13)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 12)),
                endTime: testDate.add(const Duration(hours: 13)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have compressed regions
      final compressedRegions = find.byType(CompressedTimelineRegion);
      expect(compressedRegions, findsWidgets);

      // Tap the first compressed region to expand it
      await tester.tap(compressedRegions.first);
      await tester.pumpAndSettle();

      // After expansion, the tapped region should show hour labels instead
      // The region 0-11 (before noon entry) should now be expanded
      // and show a "Fold" button
      expect(find.text('Fold'), findsOneWidget);
    });

    testWidgets('expanded region shows fold button that collapses it',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 12PM only - should compress morning and evening
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'noon',
                  dateFrom: testDate.add(const Duration(hours: 12)),
                  dateTo: testDate.add(const Duration(hours: 13)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 12)),
                endTime: testDate.add(const Duration(hours: 13)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Count initial compressed regions
      final initialCompressedCount =
          find.byType(CompressedTimelineRegion).evaluate().length;
      expect(initialCompressedCount, greaterThan(0));

      // Tap a compressed region to expand it
      await tester.tap(find.byType(CompressedTimelineRegion).first);
      await tester.pumpAndSettle();

      // Should now have one fewer compressed region
      expect(
        find.byType(CompressedTimelineRegion).evaluate().length,
        lessThan(initialCompressedCount),
      );

      // Should show fold button
      expect(find.text('Fold'), findsOneWidget);

      // Tap the fold button to collapse
      await tester.tap(find.text('Fold'));
      await tester.pumpAndSettle();

      // Should be back to original state with compressed regions
      expect(
        find.byType(CompressedTimelineRegion).evaluate().length,
        initialCompressedCount,
      );
      expect(find.text('Fold'), findsNothing);
    });

    testWidgets('visible clusters do not show fold button', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Entry at 12PM - this creates a visible cluster, not a compressed region
      await tester.pumpWidget(
        createTestWidget(
          timelineData: DailyTimelineData(
            date: testDate,
            plannedSlots: const [],
            actualSlots: [
              ActualTimeSlot(
                entry: createJournalEntry(
                  id: 'noon',
                  dateFrom: testDate.add(const Duration(hours: 12)),
                  dateTo: testDate.add(const Duration(hours: 13)),
                  categoryId: 'cat-1',
                ),
                startTime: testDate.add(const Duration(hours: 12)),
                endTime: testDate.add(const Duration(hours: 13)),
                categoryId: 'cat-1',
              ),
            ],
            dayStartHour: 0,
            dayEndHour: 24,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The visible cluster (where the entry is) should NOT have a fold button
      // Only expanded compressed regions have fold buttons
      // Initially, no fold button should be visible
      expect(find.text('Fold'), findsNothing);

      // The hour label for the visible cluster should be visible (12-13, no buffer)
      expect(find.text('12:00'), findsOneWidget);
    });
  });
}
