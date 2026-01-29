import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
                  endTime: testDate.add(const Duration(hours: 10)),
                ),
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
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

      // Should show hour labels on the time axis
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
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

      // Should show early hour labels
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
    });

    testWidgets(
        'handles invalid day bounds without crashing (endHour < startHour)',
        (tester) async {
      // This test verifies the defensive clamp prevents RangeError when
      // entries cross midnight (e.g., end at 01:00 next day, start at 23:00).
      // In such cases, the controller might calculate endHour < startHour.
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
                  startTime: testDate.add(const Duration(hours: 23)),
                  endTime: testDate.add(const Duration(hours: 25)), // next day
                ),
                startTime: testDate.add(const Duration(hours: 23)),
                endTime: testDate.add(const Duration(hours: 25)),
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
      // Should show at least 1 hour on the timeline (clamped minimum)
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
  });
}
