import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/unified_toggle.dart';

void main() {
  group('UnifiedAiToggleField', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders label and switch', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test Switch',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Test Switch'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: false,
            onChanged: (_) {},
            icon: Icons.notifications,
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows description when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: false,
            onChanged: (_) {},
            description: 'This is a helpful description',
          ),
        ),
      );

      expect(find.text('This is a helpful description'), findsOneWidget);
    });

    testWidgets('calls onChanged when switch is toggled', (tester) async {
      bool? changedValue;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: false,
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(changedValue, true);
    });

    testWidgets('reflects initial value correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('is disabled when enabled is false', (tester) async {
      var wasChanged = false;

      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: false,
            onChanged: (_) => wasChanged = true,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      expect(wasChanged, false);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, null);
    });

    testWidgets('has proper container styling', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Test',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(UnifiedAiToggleField),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('can be tapped anywhere to toggle', (tester) async {
      var value = false;

      await tester.pumpWidget(
        buildTestWidget(
          StatefulBuilder(
            builder: (context, setState) => UnifiedAiToggleField(
              label: 'Test',
              value: value,
              onChanged: (newValue) => setState(() => value = newValue),
            ),
          ),
        ),
      );

      // Tap on the label text instead of the switch
      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(value, true);
    });

    testWidgets('layout adjusts properly with all elements', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          UnifiedAiToggleField(
            label: 'Complete Switch',
            value: false,
            onChanged: (_) {},
            icon: Icons.settings,
            description: 'This switch has all elements',
          ),
        ),
      );

      // Verify all elements are present and properly laid out
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Complete Switch'), findsOneWidget);
      expect(find.text('This switch has all elements'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Verify they're in a column/row structure
      final column = find.ancestor(
        of: find.text('This switch has all elements'),
        matching: find.byType(Column),
      );
      expect(column, findsWidgets);
    });
  });
}
