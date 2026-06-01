import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

// Fixed reference date for deterministic tests
final _today = DateTime(2024, 3, 15);
final _rangeStart = DateTime(2024, 3, 8);
final _rangeEnd = DateTime(2024, 3, 15);

/// Finds the tappable [GestureDetector] for the day cell whose date equals
/// [dayString] (a `yyyy-MM-dd` string).
///
/// Each day cell wraps its `GestureDetector` inside a [Tooltip] whose `message`
/// is `chartDateFormatter(res.dayString)`. Scoping to the [Tooltip] with that
/// day-specific message resolves to exactly one cell, even when the card
/// renders multiple days.
Finder _dayCellTapFinder(String dayString) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is Tooltip && w.message == chartDateFormatter(dayString),
  ),
  matching: find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onTap != null,
  ),
);

/// Returns a single-day result for today with the given [completionType].
List<HabitResult> _singleResult(HabitCompletionType completionType) {
  return [
    HabitResult(
      dayString: _today.toIso8601String().substring(0, 10),
      completionType: completionType,
    ),
  ];
}

/// Pumps a [HabitCompletionCard] for [habit] with [results] injected via a mock
/// repository.
///
/// The cache service must already have [habit] stubbed via
/// `getIt<EntitiesCacheService>()`. An optional [theme] is forwarded to the
/// surrounding [MaterialApp] so bottom-sheet styling can be asserted.
Future<void> _pumpCard(
  WidgetTester tester, {
  required List<HabitResult> results,
  required MockHabitsRepository mockRepository,
  HabitDefinition? habit,
  ThemeData? theme,
}) async {
  final habitDefinition = habit ?? habitFlossing;

  // Stub the repository so HabitCompletionController resolves synchronously.
  when(
    () => mockRepository.getHabitCompletionsByHabitId(
      habitId: habitDefinition.id,
      rangeStart: any(named: 'rangeStart'),
      rangeEnd: any(named: 'rangeEnd'),
    ),
  ).thenAnswer((_) async => []);

  when(() => mockRepository.updateStream).thenAnswer(
    (_) => const Stream<Set<String>>.empty(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
        // Override the family provider to return [results] immediately.
        habitCompletionControllerProvider(
          habitId: habitDefinition.id,
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
        ).overrideWith(() => _StubHabitCompletionController(results)),
      ],
      child: makeTestableWidgetWithScaffold(
        HabitCompletionCard(
          habitId: habitDefinition.id,
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
        ),
        theme: theme,
      ),
    ),
  );

  await tester.pump();
}

/// A stub controller that returns a fixed list without any database access.
class _StubHabitCompletionController extends HabitCompletionController {
  _StubHabitCompletionController(this._results);

  final List<HabitResult> _results;

  @override
  Future<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async => _results;
}

void main() {
  late MockEntitiesCacheService mockCacheService;
  late MockHabitsRepository mockRepository;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();
        mockRepository = MockHabitsRepository();

        when(
          () => mockCacheService.getHabitById(habitFlossing.id),
        ).thenReturn(habitFlossing);

        // HabitDialog accesses PersistenceLogic from getIt on construction.
        final mockPersistenceLogic = MockPersistenceLogic();
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCacheService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('HabitCompletionCard — null habit', () {
    testWidgets('renders SizedBox.shrink when habit is not found', (
      tester,
    ) async {
      when(
        () => mockCacheService.getHabitById(any()),
      ).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: makeTestableWidgetWithScaffold(
            HabitCompletionCard(
              habitId: 'unknown-id',
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
            ),
          ),
        ),
      );
      await tester.pump();

      // No card/list-tile rendered — only the invisible shrink box.
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('HabitCompletionCard — habit name display', () {
    testWidgets('shows habit name in list tile title', (tester) async {
      await _pumpCard(
        tester,
        results: _singleResult(HabitCompletionType.open),
        mockRepository: mockRepository,
      );

      expect(find.text(habitFlossing.name), findsOneWidget);
    });

    testWidgets(
      'applies line-through decoration when completed today (success)',
      (tester) async {
        await _pumpCard(
          tester,
          results: _singleResult(HabitCompletionType.success),
          mockRepository: mockRepository,
        );

        // Find the Text widget displaying the habit name.
        final textWidget = tester.widget<Text>(find.text(habitFlossing.name));
        expect(
          textWidget.style?.decoration,
          TextDecoration.lineThrough,
          reason: 'Completed habit name should have line-through',
        );
      },
    );

    testWidgets(
      'applies line-through decoration when completed today (skip)',
      (tester) async {
        await _pumpCard(
          tester,
          results: _singleResult(HabitCompletionType.skip),
          mockRepository: mockRepository,
        );

        final textWidget = tester.widget<Text>(find.text(habitFlossing.name));
        expect(
          textWidget.style?.decoration,
          TextDecoration.lineThrough,
          reason: 'Skipped habit name should have line-through',
        );
      },
    );

    testWidgets('does NOT apply line-through when habit is open', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        results: _singleResult(HabitCompletionType.open),
        mockRepository: mockRepository,
      );

      final textWidget = tester.widget<Text>(find.text(habitFlossing.name));
      expect(
        textWidget.style?.decoration,
        isNot(TextDecoration.lineThrough),
        reason: 'Open habit should not have line-through',
      );
    });
  });

  group('HabitCompletionCard — completion colors', () {
    // Verify that each completion type maps to the correct container color.
    for (final testCase in [
      (HabitCompletionType.success, successColor, 'success → successColor'),
      (HabitCompletionType.fail, alarm, 'fail → alarm (red)'),
      (
        HabitCompletionType.open,
        failColor.withAlpha(153),
        'open → failColor dimmed',
      ),
    ]) {
      final completionType = testCase.$1;
      final expectedColor = testCase.$2;
      final description = testCase.$3;

      testWidgets('color correct for $description', (tester) async {
        await _pumpCard(
          tester,
          results: _singleResult(completionType),
          mockRepository: mockRepository,
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ClipRRect),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          container.color,
          expectedColor,
          reason: description,
        );
      });
    }

    testWidgets('color correct for skip → habitSkipColor dimmed', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        results: _singleResult(HabitCompletionType.skip),
        mockRepository: mockRepository,
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ClipRRect),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        container.color,
        habitSkipColor.withAlpha(102),
        reason: 'skip → habitSkipColor with 40% alpha',
      );
    });
  });

  group('HabitCompletionCard — trailing check button', () {
    testWidgets('trailing IconButton with check_circle_outline is present', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        results: [],
        mockRepository: mockRepository,
      );

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets(
      'tapping trailing check button opens HabitDialog bottom sheet',
      (tester) async {
        await _pumpCard(
          tester,
          results: [],
          mockRepository: mockRepository,
        );

        final checkButton = find.byIcon(Icons.check_circle_outline);
        expect(checkButton, findsOneWidget);

        await tester.tap(checkButton);
        await tester.pumpAndSettle();

        // The HabitDialog is shown in a bottom sheet.
        expect(find.byType(HabitDialog), findsOneWidget);
      },
    );
  });

  group('HabitCompletionCard — day cell tap', () {
    testWidgets(
      'each day cell GestureDetector has an onTap callback',
      (tester) async {
        await _pumpCard(
          tester,
          results: _singleResult(HabitCompletionType.open),
          mockRepository: mockRepository,
        );

        // Each result day is wrapped in a GestureDetector.
        // Verify that at least one GestureDetector with onTap exists (the day
        // cell's) — the trailing IconButton is NOT a GestureDetector, so all
        // GestureDetectors here come from the day cells.
        final gds = tester.widgetList<GestureDetector>(
          find.byType(GestureDetector),
        );
        final cellDetectors = gds.where((gd) => gd.onTap != null).toList();
        expect(
          cellDetectors,
          isNotEmpty,
          reason: 'Day cells must expose onTap on their GestureDetector',
        );
      },
    );

    testWidgets(
      'tapping a past day cell opens HabitDialog with that day as dateString',
      (tester) async {
        // A result for a day that is NOT today exercises the
        // `DateTime.now().ymd != res.dayString ? res.dayString : ...` branch
        // where res.dayString is forwarded to the dialog.
        const pastDay = '2024-03-12';
        await _pumpCard(
          tester,
          results: const [
            HabitResult(
              dayString: pastDay,
              completionType: HabitCompletionType.open,
            ),
          ],
          mockRepository: mockRepository,
        );

        // Scope to the cell whose tooltip matches this specific past day so
        // the finder resolves to exactly one GestureDetector.
        final cell = _dayCellTapFinder(pastDay);
        expect(cell, findsOneWidget);
        await tester.tap(cell);
        await tester.pumpAndSettle();

        final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
        expect(
          dialog.dateString,
          pastDay,
          reason: 'Tapping a non-today cell forwards its dayString',
        );
        expect(dialog.habitId, habitFlossing.id);
      },
    );

    testWidgets(
      "tapping today's day cell opens HabitDialog with today as dateString",
      (tester) async {
        // A result whose dayString equals the real DateTime.now().ymd exercises
        // the `== res.dayString ? ... : DateTime.now().ymd` branch.
        final todayYmd = DateTime.now().ymd;
        await _pumpCard(
          tester,
          results: [
            HabitResult(
              dayString: todayYmd,
              completionType: HabitCompletionType.open,
            ),
          ],
          mockRepository: mockRepository,
        );

        // Scope to today's cell via its tooltip so the finder targets exactly
        // one GestureDetector.
        final cell = _dayCellTapFinder(todayYmd);
        expect(cell, findsOneWidget);
        await tester.tap(cell);
        await tester.pumpAndSettle();

        final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
        expect(
          dialog.dateString,
          todayYmd,
          reason: "Tapping today's cell forwards today's ymd",
        );
      },
    );
  });

  group('HabitCompletionCard — bottom sheet background color', () {
    // Sentinel color so we can assert which backgroundColor branch was taken
    // when onTapAdd opens the bottom sheet.
    const sentinelSheetColor = Color(0xFF123456);

    ThemeData themeWithSheetColor() => ThemeData(
      useMaterial3: true,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sentinelSheetColor,
      ),
    );

    testWidgets(
      'uses theme bottomSheet background when habit has a dashboardId',
      (tester) async {
        final habitWithDashboard = habitFlossing.copyWith(
          dashboardId: 'dashboard-123',
        );
        when(
          () => mockCacheService.getHabitById(habitWithDashboard.id),
        ).thenReturn(habitWithDashboard);

        await _pumpCard(
          tester,
          results: const [],
          mockRepository: mockRepository,
          habit: habitWithDashboard,
          theme: themeWithSheetColor(),
        );

        await tester.tap(find.byIcon(Icons.check_circle_outline));
        await tester.pumpAndSettle();

        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(
          sheet.backgroundColor,
          sentinelSheetColor,
          reason: 'dashboardId != null → theme bottomSheet backgroundColor',
        );
      },
    );

    testWidgets(
      'uses transparent background when habit has no dashboardId',
      (tester) async {
        // habitFlossing has dashboardId == null → transparent branch.
        await _pumpCard(
          tester,
          results: const [],
          mockRepository: mockRepository,
          theme: themeWithSheetColor(),
        );

        await tester.tap(find.byIcon(Icons.check_circle_outline));
        await tester.pumpAndSettle();

        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(
          sheet.backgroundColor,
          Colors.transparent,
          reason: 'dashboardId == null → Colors.transparent',
        );
      },
    );
  });

  group('HabitCompletionCard — reduced opacity when completed today', () {
    testWidgets('opacity is 0.75 when last result is success', (tester) async {
      await _pumpCard(
        tester,
        results: _singleResult(HabitCompletionType.success),
        mockRepository: mockRepository,
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, closeTo(0.75, 0.01));
    });

    testWidgets('opacity is 1.0 when last result is open', (tester) async {
      await _pumpCard(
        tester,
        results: _singleResult(HabitCompletionType.open),
        mockRepository: mockRepository,
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, closeTo(1.0, 0.01));
    });
  });

  group('HabitCompletionCard — priority star', () {
    testWidgets('shows star icon when habit has priority=true', (tester) async {
      final priorityHabit = habitFlossing.copyWith(priority: true);

      when(
        () => mockCacheService.getHabitById(priorityHabit.id),
      ).thenReturn(priorityHabit);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsRepositoryProvider.overrideWithValue(mockRepository),
            habitCompletionControllerProvider(
              habitId: priorityHabit.id,
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
            ).overrideWith(() => _StubHabitCompletionController([])),
          ],
          child: makeTestableWidgetWithScaffold(
            HabitCompletionCard(
              habitId: priorityHabit.id,
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('star icon is NOT shown when habit priority is null/false', (
      tester,
    ) async {
      // habitFlossing has no priority set (defaults to null → not shown).
      // When Visibility.visible is false the child is replaced by SizedBox.shrink
      // and the Icon widget is not in the tree at all.
      await _pumpCard(
        tester,
        results: [],
        mockRepository: mockRepository,
      );

      // The Visibility widget is present but should report visible: false.
      final visibilities = tester.widgetList<Visibility>(
        find.byType(Visibility),
      );
      final starVisibility = visibilities.firstWhere(
        (v) => v.child is Padding,
        orElse: () => throw StateError('Star Visibility widget not found'),
      );
      expect(
        starVisibility.visible,
        isFalse,
        reason: 'Star should not be visible when habit has no priority',
      );
    });
  });
}
