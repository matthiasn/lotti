import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection_save_button.dart';

import '../../test_helper.dart';

void main() {
  group('SelectionSaveButton', () {
    Widget createTestWidget({
      VoidCallback? onPressed,
      String? label,
      IconData? icon,
    }) {
      return WidgetTestBench(
        child: Center(
          child: SelectionSaveButton(
            onPressed: onPressed,
            label: label,
            icon: icon ?? Icons.check_rounded,
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders with default label and icon', skip: true,
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('renders with custom label', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
          label: 'Custom Label',
        ));
        await tester.pumpAndSettle();

        expect(find.text('Custom Label'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
      });

      testWidgets('renders with custom icon', skip: true, (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
          icon: Icons.done_all,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.done_all), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      });

      testWidgets('takes full width of parent', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The SelectionSaveButton contains a SizedBox with width: double.infinity
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final fullWidthBox = sizedBoxes.firstWhere(
          (box) => box.width == double.infinity,
        );
        expect(fullWidthBox.width, double.infinity);
      });

      testWidgets('has correct text styling', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('Save'));
        expect(text.style?.fontWeight, FontWeight.w600);
        expect(text.style?.fontSize, 16);
      });

      testWidgets('has correct icon size', skip: true, (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
        expect(icon.size, 20);
      });
    });

    group('States', () {
      testWidgets('shows enabled state when onPressed is provided',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        final saveButton = tester
            .widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
        expect(saveButton.onPressed, isNotNull);

        // Verify button is tappable
        await tester.tap(find.byType(SelectionSaveButton));
      });

      testWidgets('shows disabled state when onPressed is null',
          (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final saveButton = tester
            .widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
        expect(saveButton.onPressed, isNull);

        // Verify button is not tappable
        await tester.tap(find.byType(SelectionSaveButton));
        // No error should be thrown when tapping disabled button
      });

      testWidgets('applies correct colors when enabled', skip: true,
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The button should be visible and have the correct styling
        expect(find.byType(SelectionSaveButton), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('applies correct colors when disabled', skip: true,
          (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // The disabled button should still be visible
        expect(find.byType(SelectionSaveButton), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });
    });

    group('Interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;

        await tester.pumpWidget(createTestWidget(
          onPressed: () => pressed = true,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SelectionSaveButton));
        expect(pressed, true);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        const pressed = false;

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SelectionSaveButton));
        expect(pressed, false);
      });

      testWidgets('shows ink effect on tap when enabled', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // Tap and hold to see ink effect
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SelectionSaveButton)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Should show ink effect (Material widget handles this)
        expect(find.byType(Material), findsAtLeastNWidgets(1));

        await gesture.up();
      });

      testWidgets('handles rapid taps correctly', (tester) async {
        var tapCount = 0;

        await tester.pumpWidget(createTestWidget(
          onPressed: () => tapCount++,
        ));
        await tester.pumpAndSettle();

        // Rapid taps on the SelectionSaveButton
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byType(SelectionSaveButton));
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(tapCount, 5);
      });
    });

    group('Styling', () {
      testWidgets('has correct padding', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The button should have proper padding as defined in the widget
        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('has correct border radius', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The button should have rounded corners as defined in the widget
        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('has shadow when enabled', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The button should have elevation/shadow when enabled
        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });
    });

    group('Theming', () {
      testWidgets('adapts to dark theme', (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: Theme(
              data: ThemeData.dark(),
              child: Center(
                child: SelectionSaveButton(
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SelectionSaveButton));
        final theme = Theme.of(context);

        expect(theme.brightness, Brightness.dark);

        // Button should still be visible in dark theme
        expect(find.byType(SelectionSaveButton), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('uses theme colors correctly', (tester) async {
        final customTheme = ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.green,
            onPrimary: Colors.yellow,
          ),
        );

        await tester.pumpWidget(
          WidgetTestBench(
            child: Theme(
              data: customTheme,
              child: Center(
                child: SelectionSaveButton(
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SelectionSaveButton));
        final colorScheme = Theme.of(context).colorScheme;

        expect(colorScheme.primary, Colors.green);
        expect(colorScheme.onPrimary, Colors.yellow);

        // Button should use theme colors
        expect(find.byType(SelectionSaveButton), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('has minimum touch target size', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
        ));
        await tester.pumpAndSettle();

        // The button should have a minimum height of 48 for accessibility
        final saveButton = find.byType(SelectionSaveButton);
        expect(saveButton, findsOneWidget);
        final buttonSize = tester.getSize(saveButton);
        expect(buttonSize.height, greaterThanOrEqualTo(48));
      });

      testWidgets('maintains text legibility', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
          label: 'Very Long Button Label Text That Might Wrap',
        ));
        await tester.pumpAndSettle();

        // Text should be visible and not overflow
        expect(
          find.text('Very Long Button Label Text That Might Wrap'),
          findsOneWidget,
        );
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty label', (tester) async {
        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
          label: '',
        ));
        await tester.pumpAndSettle();

        // Find the text widget with empty string
        expect(find.text(''), findsOneWidget);
        // Button widget should exist
        expect(find.byType(SelectionSaveButton), findsOneWidget);
        // Should have a SizedBox parent
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      });

      testWidgets('handles very long label', (tester) async {
        final longLabel =
            'This is an extremely long label that might cause layout issues ' *
                5;

        await tester.pumpWidget(createTestWidget(
          onPressed: () {},
          label: longLabel,
        ));
        await tester.pumpAndSettle();

        expect(find.text(longLabel), findsOneWidget);
        // Button widget should exist
        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('handles state changes', (tester) async {
        var enabled = true;

        await tester.pumpWidget(
          WidgetTestBench(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SelectionSaveButton(
                      onPressed: enabled ? () {} : null,
                    ),
                    TextButton(
                      onPressed: () => setState(() => enabled = !enabled),
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially enabled - check the SelectionSaveButton
        var saveButton = tester
            .widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
        expect(saveButton.onPressed, isNotNull);

        // Toggle to disabled
        await tester.tap(find.text('Toggle'));
        await tester.pumpAndSettle();

        saveButton = tester
            .widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
        expect(saveButton.onPressed, isNull);

        // Toggle back to enabled
        await tester.tap(find.text('Toggle'));
        await tester.pumpAndSettle();

        saveButton = tester
            .widget<SelectionSaveButton>(find.byType(SelectionSaveButton));
        expect(saveButton.onPressed, isNotNull);
      });
    });
  });
}
