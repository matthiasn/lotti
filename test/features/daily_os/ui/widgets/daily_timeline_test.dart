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

    testWidgets('renders actual time entries with task title', (tester) async {
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

      // Should render the task title in the actual block
      expect(find.text('Important Task'), findsOneWidget);
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
  });
}
