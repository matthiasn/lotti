import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/goals/ui/pages/goal_page_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    GoalPageStateKind kind, {
    VoidCallback? onBack,
    VoidCallback? onRetry,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        GoalPageState(kind: kind, onBack: onBack ?? () {}, onRetry: onRetry),
      ),
    );
    await tester.pump();
  }

  testWidgets('a first load is the design system spinner under the way '
      'back, and the way back works', (tester) async {
    var backs = 0;
    await pump(tester, GoalPageStateKind.loading, onBack: () => backs++);

    expect(find.byType(DesignSystemSpinner), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('goal-page-state-back')));
    expect(backs, 1);
  });

  testWidgets('a failed read says so and Try again repeats it', (
    tester,
  ) async {
    var retries = 0;
    await pump(tester, GoalPageStateKind.failed, onRetry: () => retries++);

    expect(find.text("This goal's page didn't load."), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-page-retry')));
    expect(retries, 1);
  });

  testWidgets('a failed read with nothing to retry offers no button', (
    tester,
  ) async {
    await pump(tester, GoalPageStateKind.failed);

    expect(find.text("This goal's page didn't load."), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-page-retry')), findsNothing);
  });

  testWidgets('a goal that is gone says so, with no retry', (tester) async {
    await pump(tester, GoalPageStateKind.notFound, onRetry: () {});

    expect(find.text('This goal agent no longer exists.'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-page-retry')), findsNothing);
  });
}
