import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/dashboards_page_controller.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

// Deterministic range — no real timers, no wall-clock reads in assertions.
final _rangeStart = DateTime(2024, 3, 2);
final _rangeEnd = DateTime(2024, 3, 15);

/// A fake [HabitCompletionController] that serves a canned list of
/// [HabitResult]s without touching the database. Overriding the family with
/// `_FakeController.new` lets every keyed instance return `_results`, so the
/// strip and the `completedToday` flag are fully controlled by the test.
class _FakeController extends HabitCompletionController {
  @override
  Future<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async => _results;
}

// The list the active [_FakeController] returns. Set per-test before pumping
// (the family builds lazily on first watch, so this is read at build time).
List<HabitResult> _results = const [];

/// Builds a [HabitResult] for [day] (a `DateTime`) with [type].
HabitResult _result(DateTime day, HabitCompletionType type) => HabitResult(
  dayString:
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
  completionType: type,
);

/// A single result on the range-end day with [type] — controls
/// `completedToday`, which keys off `results.last.completionType`.
List<HabitResult> _last(HabitCompletionType type) => [
  _result(_rangeEnd, type),
];

void main() {
  late MockEntitiesCacheService mockCacheService;
  late MockPersistenceLogic mockPersistenceLogic;

  setUpAll(() {
    registerFallbackValue(FakeHabitCompletionData());
  });

  setUp(() async {
    _results = const [];
    // Quick-complete and swipe paths await HapticFeedback.lightImpact(); without
    // a platform-channel handler that future never resolves and the persistence
    // call that follows it is never reached.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (methodCall) async => null,
        );
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();
        mockPersistenceLogic = MockPersistenceLogic();

        when(
          () => mockCacheService.getHabitById(habitFlossing.id),
        ).thenReturn(habitFlossing);
        // The card's CategoryIconCompact resolves the habit's category; the
        // test habit has none, so a null category is fine.
        when(
          () => mockCacheService.getCategoryById(any()),
        ).thenReturn(null);

        when(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: any(named: 'habitDefinition'),
          ),
        ).thenAnswer((_) async => null);

        getIt
          // The HabitDialog (opened on tap) reads habits from JournalDb.
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(
            mockJournalDbWithHabits([habitFlossing]),
          )
          ..registerSingleton<EntitiesCacheService>(mockCacheService)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );
  });

  tearDown(() async {
    // Reset the platform-channel handler installed in setUp so it can't swallow
    // platform calls in unrelated tests that share this isolate under the
    // batched (very_good) CI runner.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tearDownTestGetIt();
  });

  /// Pumps a [HabitCompletionCard] for [habit] with the family overridden to
  /// serve [_results]. [extraOverrides] lets a test layer in additional
  /// provider overrides (e.g. stubbing the linked dashboard). Returns nothing —
  /// assertions run against the tester.
  Future<void> pumpCard(
    WidgetTester tester, {
    HabitDefinition? habit,
    List<Override> extraOverrides = const [],
  }) async {
    final definition = habit ?? habitFlossing;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitCompletionCard(
          habitId: definition.id,
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
        ),
        overrides: [
          habitCompletionControllerProvider.overrideWith(_FakeController.new),
          ...extraOverrides,
        ],
      ),
    );
    // One frame to resolve the async family value into the card.
    await tester.pump();
  }

  /// The captured [HabitCompletionData] from the single recorded completion.
  HabitCompletionData captureCompletionData() {
    return verify(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: captureAny(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: any(named: 'habitDefinition'),
          ),
        ).captured.single
        as HabitCompletionData;
  }

  group('null habit', () {
    testWidgets('renders SizedBox.shrink with no card content', (tester) async {
      when(() => mockCacheService.getHabitById('unknown')).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitCompletionCard(
            habitId: 'unknown',
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ),
          overrides: [
            habitCompletionControllerProvider.overrideWith(_FakeController.new),
          ],
        ),
      );
      await tester.pump();

      // No row body, no swipe wrapper, no name — just the invisible shrink.
      expect(find.byType(Dismissible), findsNothing);
      expect(find.text(habitFlossing.name), findsNothing);
    });
  });

  group('habit name and priority star', () {
    testWidgets('renders the habit name', (tester) async {
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester);

      expect(find.text(habitFlossing.name), findsOneWidget);
    });

    for (final priority in [true, false]) {
      testWidgets('priority star ${priority ? 'shown' : 'absent'} when '
          'priority=$priority', (tester) async {
        final habit = habitFlossing.copyWith(
          id: 'priority-$priority',
          priority: priority,
        );
        when(() => mockCacheService.getHabitById(habit.id)).thenReturn(habit);
        _results = _last(HabitCompletionType.open);

        await pumpCard(tester, habit: habit);

        expect(
          find.byIcon(Icons.star_rounded),
          priority ? findsOneWidget : findsNothing,
          reason:
              'priority=$priority should ${priority ? '' : 'not '}'
              'render the star',
        );
        expect(find.text(habit.name), findsOneWidget);
      });
    }

    testWidgets('priority star absent when priority is null', (tester) async {
      // habitFlossing has priority == null (defaults to not shown).
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester);

      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });
  });

  group('trailing complete button — not done', () {
    testWidgets('shows the filled check_rounded button', (tester) async {
      _results = _last(HabitCompletionType.fail);
      await pumpCard(tester);

      // Not done → quick-complete button with the bare check.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // The "already done" check is absent in this state (the strip cell for
      // a fail uses close_rounded, never the circle check).
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets(
      'tapping records a SUCCESS for today and shows a SnackBar',
      (tester) async {
        _results = _last(HabitCompletionType.fail);
        await pumpCard(tester);

        await tester.tap(find.byIcon(Icons.check_rounded));
        // The quick-complete is async (haptic + persistence + snackbar).
        await tester.pump();
        await tester.pump();

        final data = captureCompletionData();
        expect(
          data.completionType,
          HabitCompletionType.success,
          reason: 'the quick-complete button records a success',
        );
        expect(data.habitId, habitFlossing.id);

        // The confirming SnackBar names the habit.
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(habitFlossing.name),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('trailing complete button — completed today', () {
    testWidgets('shows check_circle_rounded when last result is success', (
      tester,
    ) async {
      _results = _last(HabitCompletionType.success);
      await pumpCard(tester);

      // The success strip cell AND the trailing button both use the rounded
      // glyphs; the trailing "done" button is the circle check.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
      'tapping does NOT record a duplicate and opens the HabitDialog',
      (tester) async {
        _results = _last(HabitCompletionType.success);
        await pumpCard(tester);

        await tester.tap(find.byIcon(Icons.check_circle_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No silent duplicate completion is recorded.
        verifyNever(
          () => mockPersistenceLogic.createHabitCompletionEntry(
            data: any(named: 'data'),
            comment: any(named: 'comment'),
            habitDefinition: any(named: 'habitDefinition'),
          ),
        );
        // Instead the review dialog opens.
        expect(find.byType(HabitDialog), findsOneWidget);
      },
    );
  });

  group('row body tap', () {
    testWidgets('opens the HabitDialog bottom sheet', (tester) async {
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester);

      // Tap the name text — it sits on the InkWell row body, away from the
      // trailing button and the read-only strip.
      await tester.tap(find.text(habitFlossing.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HabitDialog), findsOneWidget);
      final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
      expect(dialog.habitId, habitFlossing.id);
    });
  });

  group('swipe gestures', () {
    // The row's Dismissible, scoped by its habit-keyed ValueKey so it never
    // collides with the floating SnackBar (itself a Dismissible).
    final swipeRow = find.byKey(
      ValueKey<String>('habit-swipe-${habitFlossing.id}'),
    );

    testWidgets('swipe right records a SUCCESS', (tester) async {
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester);

      await tester.drag(swipeRow, const Offset(600, 0));
      // confirmDismiss is async: record completion, then snap back.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final data = captureCompletionData();
      expect(
        data.completionType,
        HabitCompletionType.success,
        reason: 'startToEnd (right) swipe records success',
      );
      // confirmDismiss returns false → the row snaps back and is never removed.
      expect(swipeRow, findsOneWidget);
    });

    testWidgets('swipe left records a FAIL', (tester) async {
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester);

      await tester.drag(swipeRow, const Offset(-600, 0));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final data = captureCompletionData();
      expect(
        data.completionType,
        HabitCompletionType.fail,
        reason: 'endToStart (left) swipe records a miss',
      );
      // confirmDismiss returns false → the row snaps back and is never removed.
      expect(swipeRow, findsOneWidget);
    });
  });

  group('history strip glyphs', () {
    testWidgets(
      'renders the correct glyph per outcome and a Semantics label',
      (tester) async {
        // One cell per outcome, spanning the recorded states. The open day is
        // placed before the success day so `results.last` is success (the
        // trailing button is the done-circle, not another check_rounded).
        _results = [
          _result(DateTime(2024, 3, 11), HabitCompletionType.open),
          _result(DateTime(2024, 3, 12), HabitCompletionType.fail),
          _result(DateTime(2024, 3, 13), HabitCompletionType.skip),
          _result(_rangeEnd, HabitCompletionType.success),
        ];
        await pumpCard(tester);

        // success cell → check_rounded (strip) + done-circle never check_rounded
        // for the trailing button in this state, so the only check_rounded is
        // the success strip cell.
        expect(
          find.byIcon(Icons.check_rounded),
          findsOneWidget,
          reason: 'success strip cell shows the check glyph',
        );
        // fail cell → close_rounded
        expect(
          find.byIcon(Icons.close_rounded),
          findsOneWidget,
          reason: 'fail strip cell shows the close glyph',
        );
        // skip cell → remove_rounded
        expect(
          find.byIcon(Icons.remove_rounded),
          findsOneWidget,
          reason: 'skip strip cell shows the remove glyph',
        );

        // A strip cell exposes a habit-name Semantics label
        // (habitDayStatusSemantic: "{habit}, {status}").
        final semantics = tester.widgetList<Semantics>(
          find.byType(Semantics),
        );
        final labels = semantics
            .map((s) => s.properties.label)
            .whereType<String>()
            .toList();
        expect(
          labels.any((l) => l.contains(habitFlossing.name)),
          isTrue,
          reason: 'at least one strip cell labels itself with the habit name',
        );
      },
    );

    testWidgets('open/empty cells render no glyph', (tester) async {
      // A range of only open days: the strip draws cells but no outcome glyph,
      // and "not done yet" must never read as a recorded outcome.
      _results = [
        _result(DateTime(2024, 3, 13), HabitCompletionType.open),
        _result(DateTime(2024, 3, 14), HabitCompletionType.open),
        _result(_rangeEnd, HabitCompletionType.open),
      ];
      await pumpCard(tester);

      // No outcome glyphs anywhere in the strip.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      // The only check_rounded would be the trailing button (not done today),
      // never a strip cell — exactly one, from the button.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('rebinding to a different habit (didUpdateWidget)', () {
    testWidgets('clears stale results when habitId changes', (tester) async {
      // Card B's name and completions resolve through the same mocks.
      when(
        () => mockCacheService.getHabitById(habitFlossingDueLater.id),
      ).thenReturn(habitFlossingDueLater);
      _results = _last(HabitCompletionType.open);

      // Pump card A (no Key) at the root position.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitCompletionCard(
            habitId: habitFlossing.id,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ),
          overrides: [
            habitCompletionControllerProvider.overrideWith(_FakeController.new),
          ],
        ),
      );
      await tester.pump();
      expect(find.text(habitFlossing.name), findsOneWidget);

      // Pump the SAME tree shape with card B at the same position and no
      // differing Key. Flutter reconciles the element in place and calls
      // didUpdateWidget, whose habitId-changed branch drops the cached results.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitCompletionCard(
            habitId: habitFlossingDueLater.id,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ),
          overrides: [
            habitCompletionControllerProvider.overrideWith(_FakeController.new),
          ],
        ),
      );
      await tester.pump();

      // The rebound card now shows habit B and no longer habit A.
      expect(find.text(habitFlossingDueLater.name), findsOneWidget);
      expect(find.text(habitFlossing.name), findsNothing);
    });
  });

  group('linked dashboard', () {
    testWidgets(
      'opens the dialog honouring showLinkedDashboard for a dashboard habit',
      (tester) async {
        // A habit with a dashboardId makes onTapAdd take the
        // showLinkedDashboard branch (the bottomSheetTheme background path).
        final dashboardHabit = habitFlossing.copyWith(dashboardId: 'dash-1');
        when(
          () => mockCacheService.getHabitById(dashboardHabit.id),
        ).thenReturn(dashboardHabit);
        // The embedded DashboardWidget watches dashboardByIdProvider; a null
        // dashboard collapses it to a SizedBox.shrink so we can assert the
        // dialog without standing up the full dashboard provider graph.
        when(
          () => mockCacheService.getDashboardById('dash-1'),
        ).thenReturn(null);
        _results = _last(HabitCompletionType.open);

        await pumpCard(
          tester,
          habit: dashboardHabit,
          extraOverrides: [
            dashboardByIdProvider('dash-1').overrideWithValue(null),
          ],
        );

        // Tap the row body (the name on the InkWell) to open the dialog.
        await tester.tap(find.text(dashboardHabit.name));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final dialog = tester.widget<HabitDialog>(find.byType(HabitDialog));
        expect(dialog.habitId, dashboardHabit.id);
        // The card passes its showLinkedDashboard flag straight through; with a
        // dashboardId present the dialog will embed the (collapsed) dashboard.
        expect(dialog.showLinkedDashboard, isTrue);
      },
    );
  });
}
