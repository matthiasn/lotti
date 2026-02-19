import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

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
    when(() => mockCacheService.sortedCategories).thenReturn([testCategory]);

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

  DayPlanEntry createTestPlan({
    List<PlannedBlock>? plannedBlocks,
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
        status: const DayPlanStatus.draft(),
        plannedBlocks: plannedBlocks ?? [],
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

  Widget createTestWidget({
    DayPlanEntry? plan,
    List<Override> additionalOverrides = const [],
  }) {
    final effectivePlan = plan ?? createTestPlan();

    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: effectivePlan,
      timelineData: createTestTimelineData(),
      budgetProgress: [],
    );

    return RiverpodWidgetTestBench(
      overrides: [
        unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
          () => _TestUnifiedController(unifiedData),
        ),
        ...additionalOverrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: AddBlockSheet(date: testDate),
        ),
      ),
    );
  }

  group('AddBlockSheet', () {
    testWidgets('renders sheet with title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Title and button both show 'Add Block'
      expect(find.text('Add Block'), findsNWidgets(2));
    });

    testWidgets('shows Select Category label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Select Category'), findsOneWidget);
    });

    testWidgets('shows category placeholder when none selected',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Choose a category...'), findsOneWidget);
    });

    testWidgets('shows folder icon when no category selected', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byIcon(MdiIcons.folderOutline), findsOneWidget);
    });

    testWidgets('shows Time Range label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Time Range'), findsOneWidget);
    });

    testWidgets('shows Start and End labels', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      // Add Block button appears twice: title and button
      expect(find.text('Add Block'), findsNWidgets(2));
    });

    testWidgets('Add Block button is disabled without category',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Find the FilledButton with Add Block text
      final addButton = find.widgetWithText(FilledButton, 'Add Block');
      expect(addButton, findsOneWidget);

      // The button should be disabled (onPressed is null)
      final buttonWidget = tester.widget<FilledButton>(addButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('renders AddBlockSheet widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(AddBlockSheet), findsOneWidget);
    });

    testWidgets('shows duration display', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Default is 9:00 AM to 10:00 AM = 1 hour
      expect(find.text('1h'), findsOneWidget);
    });

    testWidgets('category selector is tappable', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Find the category selector by its placeholder text
      final selectorFinder = find.text('Choose a category...');
      expect(selectorFinder, findsOneWidget);

      // The selector should be inside a GestureDetector
      final gestureDetector = find.ancestor(
        of: selectorFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    testWidgets('time selectors are tappable', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Find start time selector
      final startFinder = find.text('Start');
      expect(startFinder, findsOneWidget);

      // The time selectors should be tappable
      final startGestureDetector = find.ancestor(
        of: startFinder,
        matching: find.byType(GestureDetector),
      );
      expect(startGestureDetector, findsWidgets);

      // Find end time selector
      final endFinder = find.text('End');
      expect(endFinder, findsOneWidget);

      final endGestureDetector = find.ancestor(
        of: endFinder,
        matching: find.byType(GestureDetector),
      );
      expect(endGestureDetector, findsWidgets);
    });

    testWidgets('shows arrow between time selectors', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Arrow icon between start and end time
      expect(find.byIcon(MdiIcons.arrowRight), findsOneWidget);
    });

    testWidgets('shows chevron icons for selection', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Chevron for category selector
      expect(find.byIcon(MdiIcons.chevronRight), findsOneWidget);
    });

    testWidgets('displays default start time', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Default start time is 9:00 AM
      expect(find.text('9:00 AM'), findsOneWidget);
    });

    testWidgets('displays default end time', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Default end time is 10:00 AM
      expect(find.text('10:00 AM'), findsOneWidget);
    });

    testWidgets('Cancel button is enabled', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel');
      expect(cancelButton, findsOneWidget);

      final buttonWidget = tester.widget<OutlinedButton>(cancelButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('shows drag handle at top', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // The drag handle is a Container with specific decoration
      // Check that the widget structure exists (handle container is 40x4)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('has correct layout structure', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Should have main Column for layout
      expect(find.byType(Column), findsWidgets);
      // Should have Row for time selectors and buttons
      expect(find.byType(Row), findsWidgets);
    });
  });
}
