import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_check_in_weight_card.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<List<bool>> pumpCard(
    WidgetTester tester, {
    required bool value,
  }) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalFormCheckInWeightCard(value: value, onChanged: changes.add),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('says what the switch decides and shows where it stands', (
    tester,
  ) async {
    await pumpCard(tester, value: true);

    expect(find.text('My check-ins are the point'), findsOneWidget);
    expect(
      find.text(
        'Your agent answers what you write, not only that you checked in.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<DesignSystemToggle>(find.byType(DesignSystemToggle)).value,
      isTrue,
    );
  });

  testWidgets('the switch and the whole card both ask for the opposite', (
    tester,
  ) async {
    final changes = await pumpCard(tester, value: false);

    await tester.tap(find.byType(DesignSystemToggle));
    await tester.tap(find.text('My check-ins are the point'));

    expect(changes, [true, true]);
  });
}
