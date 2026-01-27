import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

/// Mock controller that returns fixed timeline data.
class _TestTimelineController extends TimelineDataController {
  _TestTimelineController(this._data);

  final DailyTimelineData _data;

  @override
  Future<DailyTimelineData> build({required DateTime date}) async {
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

  Widget createTestWidget({
    required DailyTimelineData data,
    List<Override> additionalOverrides = const [],
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        timelineDataControllerProvider(date: testDate).overrideWith(
          () => _TestTimelineController(data),
        ),
        highlightedCategoryIdProvider.overrideWith((ref) => null),
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
        RiverpodWidgetTestBench(
          overrides: [
            dailyOsSelectedDateProvider.overrideWithValue(testDate),
            timelineDataControllerProvider(date: testDate).overrideWith(
              () => _TestTimelineController(
                DailyTimelineData(
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
            ),
            // Highlight the category
            highlightedCategoryIdProvider.overrideWith((ref) => 'cat-1'),
          ],
          child: const SingleChildScrollView(
            child: DailyTimeline(),
          ),
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
          data: DailyTimelineData(
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
}
