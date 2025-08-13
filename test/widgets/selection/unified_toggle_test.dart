import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

void main() {
  group('UnifiedToggle', () {
    testWidgets('renders with normal variant', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggle(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Verify the switch is rendered
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
    });

    testWidgets('renders with warning variant', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggle(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              variant: UnifiedToggleVariant.warning,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Verify the switch uses error color for warning variant
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);

      // The active color should be the error color for warning variant
      final context = tester.element(find.byType(Switch));
      expect(
          switchWidget.activeTrackColor, Theme.of(context).colorScheme.error);
    });

    testWidgets('UnifiedToggleField renders with title and subtitle',
        (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedToggleField(
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
              title: 'Test Toggle',
              subtitle: 'This is a test description',
            ),
          ),
        ),
      );

      expect(find.text('Test Toggle'), findsOneWidget);
      expect(find.text('This is a test description'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('toggle changes value when tapped',
        (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedToggle(
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Initial state
      var switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);

      // Tap to toggle
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify state changed
      switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('disabled toggle does not respond to taps',
        (WidgetTester tester) async {
      const value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedToggle(
              value: value,
              onChanged: null, // Disabled
              enabled: false,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, null);
    });
  });
}
