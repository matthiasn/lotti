import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_swipe_action_background.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('names the action in the given ink on the given fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        const SizedBox(
          width: 400,
          height: 80,
          child: DesignSystemSwipeActionBackground(
            alignment: Alignment.centerRight,
            color: Color(0xFF123456),
            foregroundColor: Color(0xFFABCDEF),
            icon: Icons.close,
            label: 'Dismiss',
          ),
        ),
      ),
    );

    final fill = find.descendant(
      of: find.byType(DesignSystemSwipeActionBackground),
      matching: find.byType(ColoredBox),
    );
    expect(tester.widget<ColoredBox>(fill).color, const Color(0xFF123456));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.close)).color,
      const Color(0xFFABCDEF),
    );
    final label = tester.widget<Text>(find.text('Dismiss'));
    expect(label.style?.color, const Color(0xFFABCDEF));
    expect(
      tester.getCenter(find.text('Dismiss')).dx,
      greaterThan(200),
      reason: 'sits at the trailing edge for an end-to-start swipe',
    );
  });
}
