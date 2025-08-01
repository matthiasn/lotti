import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/ui/lotti_animated_checkbox.dart';

void main() {
  group('LottiAnimatedCheckbox', () {
    Widget makeTestableWidget({
      required Widget child,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('displays label text correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test Label',
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('shows checked state when value is true', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            value: true,
          ),
        ),
      );

      // Should show check icon when checked
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('shows unchecked state when value is false', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            value: false,
          ),
        ),
      );

      // Should not show check icon when unchecked
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('calls onChanged when tapped and enabled', (tester) async {
      bool? changedValue;

      await tester.pumpWidget(
        makeTestableWidget(
          child: LottiAnimatedCheckbox(
            label: 'Test',
            value: false,
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      );

      await tester.tap(find.byType(LottiAnimatedCheckbox));
      await tester.pumpAndSettle();

      expect(changedValue, true);
    });

    testWidgets('does not call onChanged when disabled', (tester) async {
      bool? changedValue;

      await tester.pumpWidget(
        makeTestableWidget(
          child: LottiAnimatedCheckbox(
            label: 'Test',
            value: false,
            enabled: false,
            onChanged: (value) {
              changedValue = value;
            },
          ),
        ),
      );

      await tester.tap(find.byType(LottiAnimatedCheckbox));
      await tester.pumpAndSettle();

      expect(changedValue, isNull);
    });

    testWidgets('shows disabled icon when provided and disabled',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            enabled: false,
            disabledIcon: Icons.mic_off_outlined,
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
    });

    testWidgets('shows subtitle when provided and disabled', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            enabled: false,
            subtitle: 'No configuration available',
          ),
        ),
      );

      expect(find.text('No configuration available'), findsOneWidget);
    });

    testWidgets('does not show subtitle when enabled', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            subtitle: 'No configuration available',
          ),
        ),
      );

      expect(find.text('No configuration available'), findsNothing);
    });

    testWidgets('toggles value correctly', (tester) async {
      var currentValue = false;

      await tester.pumpWidget(
        makeTestableWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return LottiAnimatedCheckbox(
                label: 'Test',
                value: currentValue,
                onChanged: (value) {
                  setState(() {
                    currentValue = value ?? false;
                  });
                },
              );
            },
          ),
        ),
      );

      // Initially unchecked
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Tap to check
      await tester.tap(find.byType(LottiAnimatedCheckbox));
      await tester.pumpAndSettle();
      expect(currentValue, true);

      // Tap to uncheck
      await tester.tap(find.byType(LottiAnimatedCheckbox));
      await tester.pumpAndSettle();
      expect(currentValue, false);
    });

    testWidgets('applies correct text styling when enabled', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test Label',
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Test Label'));
      expect(text.style?.fontSize, 14);
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('applies correct text styling when disabled', (tester) async {
      final theme = ThemeData.light();

      await tester.pumpWidget(
        makeTestableWidget(
          theme: theme,
          child: const LottiAnimatedCheckbox(
            label: 'Test Label',
            enabled: false,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Test Label'));
      expect(text.style?.fontSize, 14);
      expect(text.style?.fontWeight, FontWeight.w500);
      // Color should be muted when disabled
      expect(
        text.style?.color,
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      );
    });

    testWidgets('checkbox animates when state changes', (tester) async {
      var isChecked = false;

      await tester.pumpWidget(
        makeTestableWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return LottiAnimatedCheckbox(
                label: 'Test',
                value: isChecked,
                onChanged: (value) {
                  setState(() {
                    isChecked = value ?? false;
                  });
                },
              );
            },
          ),
        ),
      );

      // Find the AnimatedContainer
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsOneWidget);

      // Tap to trigger animation
      await tester.tap(find.byType(LottiAnimatedCheckbox));

      // Pump to start animation
      await tester.pump();

      // Animation should be in progress
      await tester.pump(const Duration(milliseconds: 90));

      // Complete animation
      await tester.pumpAndSettle();

      // Should now show check icon
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('handles null value as false', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
          ),
        ),
      );

      // Should not show check icon when value is null
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('respects minimum hit target size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const LottiAnimatedCheckbox(
            label: 'Test',
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byType(InkWell));

      // Check that the touch target is reasonably sized
      expect(renderBox.size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('shows correct border radius on ink splash', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: LottiAnimatedCheckbox(
            label: 'Test',
            onChanged: (_) {},
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('subtitle uses correct text styling', (tester) async {
      final theme = ThemeData.light();

      await tester.pumpWidget(
        makeTestableWidget(
          theme: theme,
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            enabled: false,
            subtitle: 'Subtitle text',
          ),
        ),
      );

      final subtitleText = tester.widget<Text>(find.text('Subtitle text'));
      expect(subtitleText.style?.fontSize, 11);
      expect(
        subtitleText.style?.color,
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
      );
    });

    testWidgets('layout adjusts correctly with long label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          child: const SizedBox(
            width: 200,
            child: LottiAnimatedCheckbox(
              label: 'This is a very long label that should wrap properly',
            ),
          ),
        ),
      );

      // The Flexible widget should allow text to wrap
      expect(find.byType(Flexible), findsOneWidget);
      expect(find.text('This is a very long label that should wrap properly'),
          findsOneWidget);
    });

    testWidgets('disabled state shows correct icon color', (tester) async {
      final theme = ThemeData.light();

      await tester.pumpWidget(
        makeTestableWidget(
          theme: theme,
          child: const LottiAnimatedCheckbox(
            label: 'Test',
            enabled: false,
            disabledIcon: Icons.lock,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.lock));
      expect(
        icon.color,
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      );
    });
  });
}
