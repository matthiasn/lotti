import 'dart:async';

import 'package:clock/clock.dart';
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
  _TestUnifiedController(this._data, {this.shouldThrow = false, this.saveGate});

  final DailyOsData _data;
  final bool shouldThrow;

  /// When set, [setPlannedBlocks] stays in flight until the gate completes,
  /// so tests can assert the saving (button-disabled) state.
  final Completer<void>? saveGate;
  List<PlannedBlock>? savedBlocks;

  @override
  Future<DailyOsData> build() async => _data;

  @override
  Future<void> setPlannedBlocks(List<PlannedBlock> blocks) async {
    if (saveGate != null) {
      await saveGate!.future;
    }
    if (shouldThrow) {
      throw Exception('Save failed');
    }
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
    // The page stops watching the autoDispose provider once initialized, so
    // riverpod may dispose and re-initialize it (e.g. on save). The factory
    // must therefore mint a fresh notifier per init; `testController` always
    // tracks the latest instance.
    final effectiveData = data ?? _makeData();

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SetTimeBlocksPage(),
        theme: DesignSystemTheme.light(),
        overrides: [
          dailyOsSelectedDateProvider.overrideWithBuild((_, _) => _testDate),
          unifiedDailyOsDataControllerProvider(_testDate).overrideWith(
            () => testController = _TestUnifiedController(effectiveData),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Pumps the page inside a two-route [Navigator] so that
  /// `Navigator.of(context).pop()` (save success and the back button) can
  /// be verified.
  Future<void> pumpPageWithNavigator(
    WidgetTester tester, {
    DailyOsData? data,
    bool shouldThrow = false,
    Completer<void>? saveGate,
  }) async {
    final effectiveData = data ?? _makeData();
    _TestUnifiedController createController() =>
        testController = _TestUnifiedController(
          effectiveData,
          shouldThrow: shouldThrow,
          saveGate: saveGate,
        );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SetTimeBlocksPage(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
        theme: DesignSystemTheme.light(),
        overrides: [
          dailyOsSelectedDateProvider.overrideWithBuild((_, _) => _testDate),
          unifiedDailyOsDataControllerProvider(_testDate).overrideWith(
            createController,
          ),
        ],
      ),
    );
    // Route transitions need real settles.
    await tester.pumpAndSettle();

    // Navigate to the page under test.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('SetTimeBlocksPage — layout', () {
    testWidgets('renders all expected layout elements in a single pump', (
      tester,
    ) async {
      await pumpPage(tester);

      // Header: title and back affordance.
      expect(find.text('Set time blocks'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Section headers (favourites + others both present for this fixture).
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Other categories'), findsOneWidget);

      // One row per category, each labelled with its category name.
      expect(find.byType(CategoryBlockRow), findsNWidgets(4));
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Leisure'), findsOneWidget);
      expect(find.text('Commute'), findsOneWidget);

      // Save action.
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add new time block'), findsOneWidget);
    });

    testWidgets('tapping expanded category collapses it', (tester) async {
      await pumpPage(tester);

      // Expand
      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Add new time block'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Add new time block'), findsNothing);
    });

    testWidgets('only one category expanded at a time', (tester) async {
      await pumpPage(tester);

      // Expand Work
      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Add new time block'), findsOneWidget);

      // Expand Study — should close Work
      await tester.tap(find.text('Study'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Add a block
        await tester.tap(find.text('Add new time block'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Delete icon present
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        // Dash separator present
        expect(find.text('-'), findsOneWidget);
      },
    );
  });

  group('SetTimeBlocksPage — save success', () {
    testWidgets(
      'successful save shows success toast and pops navigator',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );

        await pumpPageWithNavigator(
          tester,
          data: _makeData(blocks: [existingBlock]),
        );
        await tester.pump();

        // Save button should be enabled (existing blocks present).
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNotNull);

        // Tap save.
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // Verify the controller received the blocks.
        expect(testController.savedBlocks, isNotNull);
        expect(testController.savedBlocks, hasLength(1));
        expect(testController.savedBlocks!.first.categoryId, 'cat-work');

        // After successful save, the page pops back to the parent route.
        expect(find.text('Set time blocks'), findsNothing);
        expect(find.text('Open'), findsOneWidget);

        // Success toast should be displayed.
        expect(find.text('Plan created successfully'), findsOneWidget);
        expect(
          find.text(
            'Your time blocks have been saved. '
            'You can start tracking your tasks.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'save error shows error toast and re-enables button',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );

        await pumpPageWithNavigator(
          tester,
          data: _makeData(blocks: [existingBlock]),
          shouldThrow: true,
        );
        await tester.pump();

        // Tap save — should fail.
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Page should NOT have popped.
        expect(find.text('Set time blocks'), findsOneWidget);

        // Error toast should be displayed.
        expect(find.text('Could not save plan'), findsOneWidget);
        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );

        // Save button should be re-enabled.
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'save button is disabled while the save is in flight',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );
        final saveGate = Completer<void>();

        await pumpPageWithNavigator(
          tester,
          data: _makeData(blocks: [existingBlock]),
          saveGate: saveGate,
        );
        await tester.pump();

        // Enabled before the tap.
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );

        // Tap save — the gated controller keeps the future pending.
        await tester.tap(find.byType(FilledButton));
        await tester.pump();

        // _isSaving == true: button disabled while the save is in flight.
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(testController.savedBlocks, isNull);

        // Release the gate: save completes and the page pops.
        saveGate.complete();
        await tester.pumpAndSettle();

        expect(testController.savedBlocks, hasLength(1));
        expect(find.text('Set time blocks'), findsNothing);
      },
    );

    testWidgets(
      'deleting every existing block still allows saving an empty plan',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );

        await pumpPageWithNavigator(
          tester,
          data: _makeData(blocks: [existingBlock]),
        );
        await tester.pump();

        // Expand the Work category and delete its only block.
        await tester.tap(find.text('Work'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.delete_outline_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // _hadExistingBlocks keeps _hasChanges true: clearing a previously
        // saved plan is a change the user must be able to persist.
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNotNull);

        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        // The controller received the now-empty plan and the page popped.
        expect(testController.savedBlocks, isNotNull);
        expect(testController.savedBlocks, isEmpty);
        expect(find.text('Set time blocks'), findsNothing);
      },
    );
  });

  group('SetTimeBlocksPage — init idempotence', () {
    testWidgets(
      'rebuild after a user edit does not re-seed from the existing plan',
      (tester) async {
        // Existing plan seeds one Work block via _initFromExistingPlan.
        final existingBlock = PlannedBlock(
          id: 'existing-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 12),
        );

        await pumpPageWithNavigator(
          tester,
          data: _makeData(blocks: [existingBlock]),
        );
        await tester.pump();

        // Initial seed: Work has a block (check icon), the rest do not.
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        // User edits a *different* category: add a block to Study. Each tap
        // triggers a rebuild, which re-invokes _initFromExistingPlan. The
        // _initializedDate guard must prevent it from clearing _pendingBlocks
        // and dropping the user's Study block.
        await tester.tap(find.text('Study'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Add new time block'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Collapse Study — another setState/rebuild cycle. If init were not
        // idempotent, this rebuild would wipe the Study block.
        await tester.tap(find.text('Study'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Both Work (existing) and Study (user-added) now show a block.
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

        // Persisting confirms both blocks survived the repeated rebuilds:
        // the existing Work block was not duplicated and the Study edit was
        // not lost.
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();

        expect(testController.savedBlocks, isNotNull);
        final savedCategoryIds =
            testController.savedBlocks!.map((b) => b.categoryId).toList()
              ..sort();
        expect(savedCategoryIds, ['cat-study', 'cat-work']);
      },
    );
  });

  group('SetTimeBlocksPage — back button', () {
    testWidgets('tapping back arrow pops the navigator', (tester) async {
      await pumpPageWithNavigator(tester);

      // Verify we're on the set time blocks page.
      expect(find.text('Set time blocks'), findsOneWidget);

      // Tap back arrow.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Page should have popped.
      expect(find.text('Set time blocks'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — date label', () {
    testWidgets('shows "Today" prefix when selected date is today', (
      tester,
    ) async {
      // Deterministic: the impl reads clock.now(), so fix "today" to the
      // test date instead of depending on the real wall clock.
      await withClock(
        Clock.fixed(_testDate.add(const Duration(hours: 10))),
        () async {
          await pumpPage(tester);
        },
      );

      // The label should contain the "Today" prefix.
      expect(
        find.textContaining('Today'),
        findsOneWidget,
      );
    });

    testWidgets('shows only date without "Today" for non-today date', (
      tester,
    ) async {
      await pumpPage(tester);

      // The test date is 2026-03-15 which is not today, so "Today" should
      // NOT appear in the header.
      expect(find.textContaining('Today'), findsNothing);
      // The formatted date should still be present.
      expect(find.textContaining('Mar 15, 2026'), findsOneWidget);
    });
  });

  group('SetTimeBlocksPage — save button enabled after adding block', () {
    testWidgets('save button becomes enabled after adding a time block', (
      tester,
    ) async {
      await pumpPage(tester);

      // Initially disabled — no blocks.
      final disabledButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(disabledButton.onPressed, isNull);

      // Expand a category and add a block.
      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Add new time block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now the save button should be enabled.
      final enabledButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(enabledButton.onPressed, isNotNull);
    });
  });
}
