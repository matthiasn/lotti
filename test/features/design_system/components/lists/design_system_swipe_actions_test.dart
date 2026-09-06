import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_swipe_action_background.dart';
import 'package:lotti/features/design_system/components/lists/design_system_swipe_actions.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  DesignSystemSwipeAction action(String label, VoidCallback onTrigger) =>
      DesignSystemSwipeAction(
        color: const Color(0xFF102030),
        foregroundColor: const Color(0xFFAABBCC),
        icon: Icons.check,
        label: label,
        onTrigger: onTrigger,
      );

  Widget subject({
    DesignSystemSwipeAction? startToEnd,
    DesignSystemSwipeAction? endToStart,
  }) => makeTestableWidgetWithScaffold(
    SizedBox(
      width: 400,
      child: DesignSystemSwipeActions(
        swipeKey: const ValueKey('row'),
        borderRadius: BorderRadius.circular(8),
        startToEnd: startToEnd,
        endToStart: endToStart,
        child: const SizedBox(height: 64, child: Text('Row')),
      ),
    ),
  );

  testWidgets('a row with no action is left untouched by the wrapper', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(find.text('Row'), findsOneWidget);
    expect(
      find.byType(Dismissible),
      findsNothing,
      reason: 'A row that cannot be decided must not swallow drag gestures.',
    );
  });

  testWidgets('the wired directions are the only ones that drag', (
    tester,
  ) async {
    void noop() {}

    await tester.pumpWidget(subject(startToEnd: action('Confirm', noop)));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.startToEnd,
    );

    await tester.pumpWidget(subject(endToStart: action('Reject', noop)));
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.endToStart,
    );

    await tester.pumpWidget(
      subject(
        startToEnd: action('Confirm', noop),
        endToStart: action('Reject', noop),
      ),
    );
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).direction,
      DismissDirection.horizontal,
    );
  });

  testWidgets('each direction triggers its own action and the row stays', (
    tester,
  ) async {
    var confirmed = 0;
    var rejected = 0;
    await tester.pumpWidget(
      subject(
        startToEnd: action('Confirm', () => confirmed++),
        endToStart: action('Reject', () => rejected++),
      ),
    );

    await tester.drag(find.text('Row'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(confirmed, 1);
    expect(rejected, 0);
    expect(
      find.text('Row'),
      findsOneWidget,
      reason: 'The row snaps back — its own state records the decision.',
    );

    await tester.drag(find.text('Row'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(rejected, 1);
    expect(confirmed, 1);
    expect(find.text('Row'), findsOneWidget);
  });

  testWidgets('a drag short of the threshold decides nothing', (tester) async {
    var confirmed = 0;
    await tester.pumpWidget(
      subject(startToEnd: action('Confirm', () => confirmed++)),
    );

    // Well under `threshold` of the 400 pt row.
    await tester.drag(find.text('Row'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(confirmed, 0);
  });

  testWidgets('a one-direction row still names its action while dragging', (
    tester,
  ) async {
    await tester.pumpWidget(subject(endToStart: action('Reject', () {})));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
    );
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(find.text('Reject'), findsOneWidget);
    expect(
      find.byType(DesignSystemSwipeActionBackground),
      findsWidgets,
      reason: 'The revealed band comes from the shared design-system band.',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
