import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/colors.dart';
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

    testWidgets('renders with priority variant', (WidgetTester tester) async {
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
              variant: UnifiedToggleVariant.priority,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Verify the switch uses gold color for priority variant
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
      expect(switchWidget.activeTrackColor, starredGold);
    });

    testWidgets('renders with archived variant', (WidgetTester tester) async {
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
              variant: UnifiedToggleVariant.archived,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Verify the switch uses outline color for archived variant
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
      
      final context = tester.element(find.byType(Switch));
      expect(
          switchWidget.activeTrackColor, Theme.of(context).colorScheme.outline);
    });

    testWidgets('renders with ai variant', (WidgetTester tester) async {
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
              variant: UnifiedToggleVariant.ai,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);

      // Verify the switch uses primary color for ai variant
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
      
      final context = tester.element(find.byType(Switch));
      expect(
          switchWidget.activeTrackColor, Theme.of(context).colorScheme.primary);
    });

    testWidgets('renders with cupertino variant', (WidgetTester tester) async {
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
              variant: UnifiedToggleVariant.cupertino,
            ),
          ),
        ),
      );

      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(Switch), findsNothing);

      // Verify the CupertinoSwitch is rendered
      final cupertinoSwitch = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(cupertinoSwitch.value, false);
    });

    testWidgets('custom active color overrides variant color', (WidgetTester tester) async {
      const customColor = Colors.purple;
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
              activeColor: customColor,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.activeTrackColor, customColor);
    });
  });

  group('UnifiedToggleField', () {
    testWidgets('with leading widget', (WidgetTester tester) async {
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
              leading: const Icon(Icons.settings),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Test Toggle'), findsOneWidget);
    });

    testWidgets('dense layout', (WidgetTester tester) async {
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
              title: 'Dense Toggle',
              dense: true,
            ),
          ),
        ),
      );

      expect(find.text('Dense Toggle'), findsOneWidget);
      // Dense layout will have reduced padding
    });

    testWidgets('tap on field toggles value', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedToggleField(
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                  title: 'Tap Me',
                );
              },
            ),
          ),
        ),
      );

      expect(value, false);

      // Tap on the text area (not just the switch)
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(value, true);
    });
  });

  group('UnifiedFormBuilderToggle', () {
    testWidgets('renders with form field', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedFormBuilderToggle(
              name: 'test_toggle',
              title: 'Form Toggle',
              initialValue: true,
            ),
          ),
        ),
      );

      expect(find.text('Form Toggle'), findsOneWidget);
      expect(find.byType(UnifiedToggleField), findsOneWidget);
      
      // Verify initial value
      final toggleField = tester.widget<UnifiedToggleField>(find.byType(UnifiedToggleField));
      expect(toggleField.value, true);
    });

    testWidgets('shows validation error', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: UnifiedFormBuilderToggle(
                name: 'test_toggle',
                title: 'Required Toggle',
                initialValue: false,
                validator: (value) {
                  if (value != true) {
                    return 'This must be enabled';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      // Validate form
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      // Check error message is displayed
      expect(find.text('This must be enabled'), findsOneWidget);
    });

    testWidgets('with subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedFormBuilderToggle(
              name: 'test_toggle',
              title: 'Form Toggle',
              subtitle: 'Additional description',
            ),
          ),
        ),
      );

      expect(find.text('Form Toggle'), findsOneWidget);
      expect(find.text('Additional description'), findsOneWidget);
    });

    testWidgets('onChanged callback', (WidgetTester tester) async {
      bool? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedFormBuilderToggle(
              name: 'test_toggle',
              title: 'Form Toggle',
              initialValue: false,
              onChanged: (value) {
                changedValue = value;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Form Toggle'));
      await tester.pumpAndSettle();

      expect(changedValue, true);
    });

    testWidgets('semanticsLabel support', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedFormBuilderToggle(
              name: 'test_toggle',
              title: 'Form Toggle',
              semanticsLabel: 'Custom accessibility label',
            ),
          ),
        ),
      );

      expect(find.byType(UnifiedToggleField), findsOneWidget);
      
      // Verify semanticsLabel is passed through
      final toggleField = tester.widget<UnifiedToggleField>(find.byType(UnifiedToggleField));
      expect(toggleField.semanticsLabel, 'Custom accessibility label');
    });
  });

  group('UnifiedAiToggleField', () {
    testWidgets('renders with AI-specific styling', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.text('AI Feature'), findsOneWidget);
      expect(find.byType(UnifiedToggle), findsOneWidget);
      
      // Verify it uses AI variant
      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      expect(toggle.variant, UnifiedToggleVariant.ai);
    });

    testWidgets('with description', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              description: 'Enable AI assistance',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.text('AI Feature'), findsOneWidget);
      expect(find.text('Enable AI assistance'), findsOneWidget);
    });

    testWidgets('with icon', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              icon: Icons.auto_awesome,
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('tap toggles value', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return UnifiedAiToggleField(
                  label: 'AI Feature',
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

      expect(value, false);

      await tester.tap(find.text('AI Feature'));
      await tester.pumpAndSettle();

      expect(value, true);
    });

    testWidgets('disabled state', (WidgetTester tester) async {
      const value = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'AI Feature',
              value: value,
              onChanged: null,
              enabled: false,
            ),
          ),
        ),
      );

      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      // UnifiedAiToggleField sets onChanged to null when disabled rather than passing enabled
      expect(toggle.onChanged, null);
      // The toggle's enabled property defaults to true
      expect(toggle.enabled, true);
    });

    testWidgets('semantic label is properly set', (WidgetTester tester) async {
      var value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: UnifiedAiToggleField(
              label: 'Enable AI suggestions',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      final toggle = tester.widget<UnifiedToggle>(find.byType(UnifiedToggle));
      expect(toggle.semanticLabel, 'Enable AI suggestions');
    });
  });
}
