import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_list_tile.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('MenuSwitchListTile', () {
    testWidgets('renders correctly when value is true',
        (WidgetTester tester) async {
      var switchValue = true;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: MenuSwitchListTile(
              title: 'Test Switch',
              value: switchValue,
              onChanged: (value) {
                switchValue = value;
              },
              icon: Icons.access_time,
              activeIcon: Icons.check_circle,
              activeColor: Colors.green,
            ),
          ),
        ),
      );

      // Verify the title is displayed
      expect(find.text('Test Switch'), findsOneWidget);

      // Verify the active icon is displayed when value is true
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Verify the switch is in the on position
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('renders correctly when value is false',
        (WidgetTester tester) async {
      var switchValue = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: MenuSwitchListTile(
              title: 'Test Switch',
              value: switchValue,
              onChanged: (value) {
                switchValue = value;
              },
              icon: Icons.access_time,
              activeIcon: Icons.check_circle,
              activeColor: Colors.green,
            ),
          ),
        ),
      );

      // Verify the title is displayed
      expect(find.text('Test Switch'), findsOneWidget);

      // Verify the inactive icon is displayed when value is false
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      // Verify the switch is in the off position
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('calls onChanged when tapped', (WidgetTester tester) async {
      var switchValue = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: MenuSwitchListTile(
              title: 'Test Switch',
              value: switchValue,
              onChanged: (value) {
                switchValue = value;
              },
              icon: Icons.access_time,
              activeIcon: Icons.check_circle,
              activeColor: Colors.green,
            ),
          ),
        ),
      );

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Verify the onChanged callback was called and the value was updated
      expect(switchValue, isTrue);
    });
  });
}
