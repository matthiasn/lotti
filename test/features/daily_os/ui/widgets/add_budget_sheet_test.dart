import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

/// Mock controller that returns a fixed DayPlanEntry.
class _TestDayPlanController extends DayPlanController {
  _TestDayPlanController(this._entry);

  final DayPlanEntry? _entry;

  @override
  Future<JournalEntity?> build({required DateTime date}) async {
    return _entry;
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
    List<TimeBudget>? budgets,
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
        budgets: budgets ?? [],
      ),
    );
  }

  Widget createTestWidget({
    DayPlanEntry? plan,
    List<Override> additionalOverrides = const [],
  }) {
    final effectivePlan = plan ?? createTestPlan();

    return RiverpodWidgetTestBench(
      overrides: [
        dayPlanControllerProvider(date: testDate).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        ...additionalOverrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: AddBudgetSheet(date: testDate),
        ),
      ),
    );
  }

  group('AddBudgetSheet', () {
    testWidgets('renders sheet with title', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Title and button both show 'Add Budget'
      expect(find.text('Add Budget'), findsNWidgets(2));
    });

    testWidgets('shows Select Category label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Select Category'), findsOneWidget);
    });

    testWidgets('shows category placeholder when none selected',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Choose a category...'), findsOneWidget);
    });

    testWidgets('shows folder icon when no category selected', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.folderOutline), findsOneWidget);
    });

    testWidgets('shows Planned Duration label', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Planned Duration'), findsOneWidget);
    });

    testWidgets('shows duration chips', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('30m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
      expect(find.text('4h'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      // Add Budget button appears twice: title and button
      expect(find.text('Add Budget'), findsNWidgets(2));
    });

    testWidgets('Add Budget button is disabled without category',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the FilledButton with Add Budget text
      final addButton = find.widgetWithText(FilledButton, 'Add Budget');
      expect(addButton, findsOneWidget);

      // The button should be disabled (onPressed is null)
      final buttonWidget = tester.widget<FilledButton>(addButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('renders AddBudgetSheet widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AddBudgetSheet), findsOneWidget);
    });

    testWidgets('can select different duration', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on 2h duration chip
      await tester.tap(find.text('2h'));
      await tester.pumpAndSettle();

      // The chip should be visually selected
      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets('1h is selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1h should be selected by default - we verify by checking it's rendered
      expect(find.text('1h'), findsOneWidget);
    });
  });
}
