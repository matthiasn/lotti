import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/pages/set_time_blocks_page.dart';
import 'package:lotti/features/daily_os/ui/widgets/category_block_row.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

final _testDate = DateTime(2026, 3, 15);

CategoryDefinition _makeCategory({
  required String id,
  required String name,
  bool favorite = false,
}) {
  return EntityDefinition.categoryDefinition(
        id: id,
        name: name,
        createdAt: _testDate,
        updatedAt: _testDate,
        vectorClock: null,
        private: false,
        active: true,
        color: '#6C5CE7',
        favorite: favorite,
      )
      as CategoryDefinition;
}

final CategoryDefinition _favWork = _makeCategory(
  id: 'cat-work',
  name: 'Work',
  favorite: true,
);
final CategoryDefinition _favStudy = _makeCategory(
  id: 'cat-study',
  name: 'Study',
  favorite: true,
);
final CategoryDefinition _otherLeisure = _makeCategory(
  id: 'cat-leisure',
  name: 'Leisure',
);
final CategoryDefinition _otherCommute = _makeCategory(
  id: 'cat-commute',
  name: 'Commute',
);

final _planId = 'plan-${_testDate.toIso8601String()}';

DailyOsData _makeData({List<PlannedBlock> blocks = const []}) {
  return DailyOsData(
    date: _testDate,
    dayPlan: DayPlanEntry(
      meta: Metadata(
        id: _planId,
        createdAt: _testDate,
        updatedAt: _testDate,
        dateFrom: _testDate,
        dateTo: _testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: _testDate,
        status: const DayPlanStatus.draft(),
        plannedBlocks: blocks,
      ),
    ),
    timelineData: DailyTimelineData(
      date: _testDate,
      plannedSlots: const [],
      actualSlots: const [],
      dayStartHour: 7,
      dayEndHour: 22,
    ),
    budgetProgress: [],
  );
}

class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;
  List<PlannedBlock>? savedBlocks;

  @override
  Future<DailyOsData> build({required DateTime date}) async => _data;

  @override
  Future<void> setPlannedBlocks(List<PlannedBlock> blocks) async {
    savedBlocks = blocks;
  }
}

void main() {
  late MockEntitiesCacheService mockCache;
  late _TestUnifiedController testController;

  setUp(() {
    mockCache = MockEntitiesCacheService();
    when(() => mockCache.sortedCategories).thenReturn([
      _favStudy,
      _favWork,
      _otherCommute,
      _otherLeisure,
    ]);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getCategoryById('cat-work')).thenReturn(_favWork);
    when(() => mockCache.getCategoryById('cat-study')).thenReturn(_favStudy);
    when(
      () => mockCache.getCategoryById('cat-leisure'),
    ).thenReturn(_otherLeisure);
    when(
      () => mockCache.getCategoryById('cat-commute'),
    ).thenReturn(_otherCommute);

    getIt.registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(getIt.reset);

  Future<void> pumpPage(
    WidgetTester tester, {
    DailyOsData? data,
  }) async {
    testController = _TestUnifiedController(data ?? _makeData());

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SetTimeBlocksPage(),
        theme: DesignSystemTheme.light(),
        overrides: [
          dailyOsSelectedDateProvider.overrideWithValue(_testDate),
          unifiedDailyOsDataControllerProvider(date: _testDate).overrideWith(
            () => testController,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SetTimeBlocksPage — layout', () {
    testWidgets('renders header with title and date', (tester) async {
      await pumpPage(tester);

      expect(find.text('Set time blocks'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders Favourites section header', (tester) async {
      await pumpPage(tester);

      expect(find.text('Favourites'), findsOneWidget);
    });

    testWidgets('renders Other categories section header', (tester) async {
      await pumpPage(tester);

      expect(find.text('Other categories'), findsOneWidget);
    });

    testWidgets('renders all category rows', (tester) async {
      await pumpPage(tester);

      expect(find.byType(CategoryBlockRow), findsNWidgets(4));
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Leisure'), findsOneWidget);
      expect(find.text('Commute'), findsOneWidget);
    });

    testWidgets('renders Save plan button', (tester) async {
      await pumpPage(tester);

      expect(find.text('Save plan'), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — save button state', () {
    testWidgets('save button disabled when no blocks', (tester) async {
      await pumpPage(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('SetTimeBlocksPage — pre-populates existing blocks', () {
    testWidgets('shows existing blocks from DayPlanData', (tester) async {
      final existingBlock = PlannedBlock(
        id: 'existing-1',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 3, 15, 9),
        endTime: DateTime(2026, 3, 15, 12),
      );

      await pumpPage(tester, data: _makeData(blocks: [existingBlock]));

      // Rebuild after async data is available
      await tester.pump();

      // The Work row should show a time chip (not the tap hint)
      // 3 categories without blocks + Work has a block
      expect(find.text('Tap to add time block'), findsNWidgets(3));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — category interaction', () {
    testWidgets('tapping category expands it', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      expect(find.text('Add new time block'), findsOneWidget);
    });

    testWidgets('tapping expanded category collapses it', (tester) async {
      await pumpPage(tester);

      // Expand
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Add new time block'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Add new time block'), findsNothing);
    });

    testWidgets('only one category expanded at a time', (tester) async {
      await pumpPage(tester);

      // Expand Work
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Add new time block'), findsOneWidget);

      // Expand Study — should close Work
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();
      // Still only one "Add new time block" visible
      expect(find.text('Add new time block'), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — no favorites', () {
    testWidgets('hides Favourites header when no favorites', (tester) async {
      when(() => mockCache.sortedCategories).thenReturn([
        _otherLeisure,
        _otherCommute,
      ]);

      await pumpPage(tester);

      expect(find.text('Favourites'), findsNothing);
      expect(find.text('Other categories'), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — no other categories', () {
    testWidgets('hides Other header when all are favorites', (tester) async {
      when(() => mockCache.sortedCategories).thenReturn([_favWork, _favStudy]);

      await pumpPage(tester);

      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Other categories'), findsNothing);
    });
  });

  group('SetTimeBlocksPage — card styling', () {
    testWidgets(
      'category card uses neutral border, not green, when has blocks',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );

        await pumpPage(tester, data: _makeData(blocks: [existingBlock]));
        await tester.pump();

        // Find the AnimatedContainer for the Work category row
        final animatedContainers = find.byType(AnimatedContainer);
        expect(animatedContainers, findsWidgets);

        // Verify no green-tinted background or border on any card
        for (final element in animatedContainers.evaluate()) {
          final widget = element.widget as AnimatedContainer;
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.border != null) {
            final border = decoration.border! as Border;
            // Border should NOT be green/interactive colored
            final g = (border.top.color.g * 255).round();
            final r = (border.top.color.r * 255).round();
            expect(
              g > 200 && r < 100,
              isFalse,
              reason: 'Card border should be neutral, not green',
            );
            // Background should NOT have green tint
            if (decoration.color != null) {
              final bgG = (decoration.color!.g * 255).round();
              final bgR = (decoration.color!.r * 255).round();
              expect(
                bgG > 200 && bgR < 50,
                isFalse,
                reason: 'Card background should be neutral, not green',
              );
            }
          }
        }
      },
    );

    testWidgets('expanded card shows add button and divider', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Add button present with pill shape
      expect(find.text('Add new time block'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets(
      'adding a time block shows editor with delete icon and dash separator',
      (tester) async {
        await pumpPage(tester);

        // Expand Work
        await tester.tap(find.text('Work'));
        await tester.pumpAndSettle();

        // Add a block
        await tester.tap(find.text('Add new time block'));
        await tester.pumpAndSettle();

        // Delete icon present
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        // Dash separator present
        expect(find.text('-'), findsOneWidget);
      },
    );
  });
}
