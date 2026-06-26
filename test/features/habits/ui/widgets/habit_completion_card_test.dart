import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
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
  Future<List<HabitResult>> build() async => _results;
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

  setUp(() async {
    _results = const [];
    await setUpTestGetIt(
      additionalSetup: () {
        mockCacheService = MockEntitiesCacheService();

        when(
          () => mockCacheService.getHabitById(habitFlossing.id),
        ).thenReturn(habitFlossing);
        // The action row's CategoryIconCompact resolves the habit's category;
        // the test habit has none, so a null category is fine.
        when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(
            mockJournalDbWithHabits([habitFlossing]),
          )
          ..registerSingleton<EntitiesCacheService>(mockCacheService)
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  /// Pumps a [HabitCompletionCard] for [habit] with the family overridden to
  /// serve [_results].
  Future<void> pumpCard(
    WidgetTester tester, {
    HabitDefinition? habit,
    bool showLinkedDashboard = true,
  }) async {
    final definition = habit ?? habitFlossing;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitCompletionCard(
          habitId: definition.id,
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
          showLinkedDashboard: showLinkedDashboard,
        ),
        overrides: [
          habitCompletionControllerProvider.overrideWith2(
            (_) => _FakeController(),
          ),
        ],
      ),
    );
    // One frame to resolve the async family value into the card.
    await tester.pump();
  }

  HabitActionRow row(WidgetTester tester) =>
      tester.widget<HabitActionRow>(find.byType(HabitActionRow));

  group('null habit', () {
    testWidgets('renders SizedBox.shrink with no row', (tester) async {
      when(() => mockCacheService.getHabitById('unknown')).thenReturn(null);
      await pumpCard(tester, habit: habitFlossing.copyWith(id: 'unknown'));
      expect(find.byType(HabitActionRow), findsNothing);
    });
  });

  group('completedToday derived from the latest in-range result', () {
    final cases = {
      HabitCompletionType.success: true,
      HabitCompletionType.skip: true,
      HabitCompletionType.fail: false,
      HabitCompletionType.open: false,
    };
    for (final entry in cases.entries) {
      testWidgets('last result ${entry.key.name} → ${entry.value}', (
        tester,
      ) async {
        _results = _last(entry.key);
        await pumpCard(tester);
        expect(row(tester).completedToday, entry.value);
      });
    }

    testWidgets('no results → not completed', (tester) async {
      _results = const [];
      await pumpCard(tester);
      expect(row(tester).completedToday, isFalse);
    });
  });

  group('history strip glyphs', () {
    testWidgets('renders the correct glyph per outcome with a Semantics label', (
      tester,
    ) async {
      // The open day precedes the success day so `results.last` is success and
      // the trailing button is the done-circle, not another check_rounded.
      _results = [
        _result(DateTime(2024, 3, 11), HabitCompletionType.open),
        _result(DateTime(2024, 3, 12), HabitCompletionType.fail),
        _result(DateTime(2024, 3, 13), HabitCompletionType.skip),
        _result(_rangeEnd, HabitCompletionType.success),
      ];
      await pumpCard(tester);

      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // success cell
      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // fail cell
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget); // skip cell

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>();
      expect(
        labels.any((l) => l.contains(habitFlossing.name)),
        isTrue,
        reason: 'a strip cell labels itself with the habit name',
      );
    });

    testWidgets('open-only days render no outcome glyph', (tester) async {
      _results = [
        _result(DateTime(2024, 3, 13), HabitCompletionType.open),
        _result(DateTime(2024, 3, 14), HabitCompletionType.open),
        _result(_rangeEnd, HabitCompletionType.open),
      ];
      await pumpCard(tester);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);
      // No success cell, and the not-done button is a hollow "+" — so the strip
      // shows no check glyph at all.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('passthrough to the action row', () {
    testWidgets('forwards showLinkedDashboard', (tester) async {
      _results = _last(HabitCompletionType.open);
      await pumpCard(tester, showLinkedDashboard: false);
      expect(row(tester).showLinkedDashboard, isFalse);
    });
  });

  group('rebinding to a different habit (didUpdateWidget)', () {
    testWidgets('clears stale results when habitId changes', (tester) async {
      when(
        () => mockCacheService.getHabitById(habitFlossingDueLater.id),
      ).thenReturn(habitFlossingDueLater);
      _results = _last(HabitCompletionType.open);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitCompletionCard(
            habitId: habitFlossing.id,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ),
          overrides: [
            habitCompletionControllerProvider.overrideWith2(
              (_) => _FakeController(),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text(habitFlossing.name), findsOneWidget);

      // Same tree shape, card B at the same position, no differing Key: Flutter
      // reconciles in place and didUpdateWidget drops the cached results.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitCompletionCard(
            habitId: habitFlossingDueLater.id,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ),
          overrides: [
            habitCompletionControllerProvider.overrideWith2(
              (_) => _FakeController(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text(habitFlossingDueLater.name), findsOneWidget);
      expect(find.text(habitFlossing.name), findsNothing);
    });
  });
}
