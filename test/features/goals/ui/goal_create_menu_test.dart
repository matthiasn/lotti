import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_create_menu.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<GoalCreateChoice?> Function() chosen = () async => null;

  Future<void> open(
    WidgetTester tester, {
    bool canReflect = true,
    bool canLogToday = true,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              final result = showGoalCreateMenu(
                context: context,
                canReflect: canReflect,
                canLogToday: canLogToday,
              );
              chosen = () => result;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder row(GoalCreateChoice choice) =>
      find.byKey(ValueKey('goal-create-${choice.name}'));

  testWidgets('names what it adds to, and leads with the written check-in', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Add to this goal'), findsOneWidget);
    final tops = [
      for (final choice in [
        GoalCreateChoice.writeCheckIn,
        GoalCreateChoice.logToday,
        GoalCreateChoice.reflectToday,
      ])
        tester.getTopLeft(row(choice)).dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
    expect(find.text('Write a check-in'), findsOneWidget);
    expect(find.text('Log today'), findsOneWidget);
    expect(find.text('Reflect on today'), findsOneWidget);
  });

  for (final choice in GoalCreateChoice.values) {
    testWidgets('tapping ${choice.name} closes the menu with that choice', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(row(choice));
      await tester.pumpAndSettle();

      expect(await chosen(), choice);
      expect(row(choice), findsNothing);
    });
  }

  testWidgets('a goal with no habit and no day to judge offers the written '
      'check-in alone; dismissed, the menu chooses nothing', (tester) async {
    await open(tester, canReflect: false, canLogToday: false);

    expect(row(GoalCreateChoice.writeCheckIn), findsOneWidget);
    expect(row(GoalCreateChoice.logToday), findsNothing);
    expect(row(GoalCreateChoice.reflectToday), findsNothing);

    Navigator.of(tester.element(row(GoalCreateChoice.writeCheckIn))).pop();
    await tester.pumpAndSettle();
    expect(await chosen(), isNull);
  });
}
