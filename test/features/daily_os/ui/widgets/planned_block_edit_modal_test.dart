import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
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

  PlannedBlock createTestBlock({
    String? categoryId,
    String? note,
    int startHour = 9,
    int endHour = 11,
  }) {
    return PlannedBlock(
      id: 'block-1',
      categoryId: categoryId ?? testCategory.id,
      startTime: testDate.add(Duration(hours: startHour)),
      endTime: testDate.add(Duration(hours: endHour)),
      note: note,
    );
  }

  DayPlanEntry createTestPlan({
    List<PlannedBlock>? blocks,
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
        plannedBlocks: blocks ?? [createTestBlock()],
      ),
    );
  }

  Widget createTestWidget({
    required PlannedBlock block,
    DayPlanEntry? plan,
    List<Override> additionalOverrides = const [],
  }) {
    final effectivePlan = plan ?? createTestPlan();

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        dayPlanControllerProvider(date: testDate).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        ...additionalOverrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: PlannedBlockEditModal(block: block, date: testDate),
        ),
      ),
    );
  }

  group('PlannedBlockEditModal', () {
    testWidgets('renders modal with title', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.text('Edit Planned Block'), findsOneWidget);
    });

    testWidgets('shows time range section', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.text('Time Range'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });

    testWidgets('shows start and end times', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
    });

    testWidgets('shows duration', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('shows category section', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('shows Uncategorized when category not found', (tester) async {
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

      await tester.pumpWidget(
        createTestWidget(block: createTestBlock(categoryId: 'unknown')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('shows note section', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Add a note...'), findsOneWidget);
    });

    testWidgets('displays existing note', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(block: createTestBlock(note: 'Important meeting')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Important meeting'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows delete button', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.delete), findsOneWidget);
    });

    testWidgets('renders PlannedBlockEditModal widget', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      expect(find.byType(PlannedBlockEditModal), findsOneWidget);
    });

    testWidgets('displays hours and minutes duration', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pumpAndSettle();

      // 2 hours exactly
      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('displays minutes only duration for short block',
        (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      // Create a 30 minute block
      final block = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: testDate.add(const Duration(hours: 9)),
        endTime: testDate.add(const Duration(hours: 9, minutes: 30)),
      );

      await tester.pumpWidget(
        createTestWidget(
          block: block,
          plan: DayPlanEntry(
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
              plannedBlocks: [block],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 30 minutes
      expect(find.text('30 minutes'), findsOneWidget);
    });

    testWidgets('shows tappable time selectors', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      // Find InkWell widgets for time selectors
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      // Tap the delete button
      await tester.tap(find.byIcon(MdiIcons.delete));
      await tester.pumpAndSettle();

      // Verify the confirmation dialog appears
      expect(find.text('Delete Block?'), findsOneWidget);
      expect(
        find.text('This will remove the planned block from your timeline.'),
        findsOneWidget,
      );
    });

    testWidgets('cancel button closes dialog without deleting', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      // Tap delete and then cancel
      await tester.tap(find.byIcon(MdiIcons.delete));
      await tester.pumpAndSettle();

      // Find the cancel button in the dialog (there are multiple Cancel texts)
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // The modal should still be visible
      expect(find.byType(PlannedBlockEditModal), findsOneWidget);
    });

    testWidgets('note field allows text entry', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'My test note');
      await tester.pumpAndSettle();

      expect(find.text('My test note'), findsOneWidget);
    });

    testWidgets('save button is enabled for valid time range', (tester) async {
      when(() => mockCacheService.getCategoryById('cat-1'))
          .thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pumpAndSettle();

      // Find the Save button
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);

      // It should be enabled (FilledButton with valid onPressed)
      final button = tester.widget<FilledButton>(
        find.ancestor(of: saveButton, matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
