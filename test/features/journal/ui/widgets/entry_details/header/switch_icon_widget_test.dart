import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_icon_widget.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('SwitchIconWidget', () {
    testWidgets('renders correctly when value is false',
        (WidgetTester tester) async {
      // ignore: unused_local_variable
      var iconPressed = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: 'Test Icon',
              onPressed: () {
                iconPressed = true;
              },
              value: false,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      // Verify that the inactive icon is displayed
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);

      // Check that the icon has the correct color
      final icon = tester.widget<Icon>(find.byIcon(Icons.star_outline));
      expect(icon.color, isA<Color>());
    });

    testWidgets('renders correctly when value is true',
        (WidgetTester tester) async {
      // ignore: unused_local_variable
      var iconPressed = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: 'Test Icon',
              onPressed: () {
                iconPressed = true;
              },
              value: true,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      // Verify that the active icon is displayed
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);

      // Check that the icon has the correct color
      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, Colors.amber);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      var iconPressed = false;

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: 'Test Icon',
              onPressed: () {
                iconPressed = true;
              },
              value: false,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      // Tap the icon
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Verify the onPressed callback was called
      expect(iconPressed, isTrue);
    });

    testWidgets('has correct tooltip', (WidgetTester tester) async {
      const testTooltip = 'Custom Tooltip';

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: testTooltip,
              onPressed: () {},
              value: false,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      // Verify the tooltip
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, testTooltip);
    });

    testWidgets('triggers haptic feedback when tapped',
        (WidgetTester tester) async {
      // Set up a log to track which haptic feedback was triggered
      final hapticLog = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            final type = methodCall.arguments as String;
            hapticLog.add(type);
            return null;
          }
          return null;
        },
      );

      // Test with value = false (should trigger heavy impact)
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: 'Test Icon',
              onPressed: () {},
              value: false,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Test with value = true (should trigger light impact)
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: SwitchIconWidget(
              tooltip: 'Test Icon',
              onPressed: () {},
              value: true,
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              activeColor: Colors.amber,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Check that the haptic feedback was triggered with correct types
      // Note: In flutter_test environment, we can't fully verify actual haptic feedback
      // but we can check that HapticFeedback methods were called
      expect(hapticLog.length, greaterThan(0));
    });

    testWidgets('has correct size constraints', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: Center(
              child: SwitchIconWidget(
                tooltip: 'Test Icon',
                onPressed: () {},
                value: false,
                icon: Icons.star_outline,
                activeIcon: Icons.star,
                activeColor: Colors.amber,
              ),
            ),
          ),
        ),
      );

      // Find the SizedBox that's a direct parent of IconButton
      final sizedBoxFinder = find
          .ancestor(
            of: find.byType(IconButton),
            matching: find.byType(SizedBox),
          )
          .first;

      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.width, 40);
    });
  });
}
