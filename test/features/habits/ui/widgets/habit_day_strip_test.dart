import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/ui/widgets/habit_day_strip.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<HabitResult> resultsFor(List<HabitCompletionType> types) {
    return [
      for (var i = 0; i < types.length; i++)
        HabitResult(
          dayString: '2026-05-${(i + 1).toString().padLeft(2, '0')}',
          completionType: types[i],
        ),
    ];
  }

  testWidgets('renders one cell per HabitResult', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitDayStrip(
          results: resultsFor([
            HabitCompletionType.success,
            HabitCompletionType.fail,
            HabitCompletionType.skip,
            HabitCompletionType.open,
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Tooltip), findsNWidgets(4));
  });

  testWidgets('cell colors match the DS-token completion palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitDayStrip(
          results: resultsFor([
            HabitCompletionType.success,
            HabitCompletionType.fail,
            HabitCompletionType.skip,
            HabitCompletionType.open,
          ]),
        ),
      ),
    );
    await tester.pump();

    final tokens = Theme.of(
      tester.element(find.byType(HabitDayStrip)),
    ).extension<DsTokens>()!;

    final colors = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.color)
        .toList();

    expect(colors[0], tokens.colors.interactive.enabled);
    expect(colors[1], tokens.colors.alert.error.defaultColor);
    expect(colors[2], tokens.colors.alert.warning.defaultColor);
    expect(colors[3], tokens.colors.decorative.level01);
  });

  testWidgets('tapping a cell forwards the day string when onTapDay is set', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      makeTestableWidget(
        HabitDayStrip(
          results: resultsFor([HabitCompletionType.open]),
          onTapDay: (d) => tapped = d,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(Tooltip));
    await tester.pump();

    expect(tapped, '2026-05-01');
  });

  testWidgets('shows "Nd" and "now" labels when showLabels is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        HabitDayStrip(
          results: resultsFor(List.filled(3, HabitCompletionType.open)),
          showLabels: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('3d'), findsOneWidget);
    expect(find.text('now'), findsOneWidget);
  });
}
