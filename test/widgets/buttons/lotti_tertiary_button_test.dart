import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

void main() {
  group('LottiTertiaryButton', () {
    testWidgets('renders with label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('renders with icon and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextButton));
      expect(pressed, isTrue);
    });

    testWidgets('does not call onPressed when disabled',
        (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () => pressed = true,
              enabled: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextButton));
      expect(pressed, isFalse);
    });

    testWidgets('does not call onPressed when onPressed is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: null,
            ),
          ),
        ),
      );

      // Should not throw when tapping disabled button
      await tester.tap(find.byType(TextButton));
    });

    testWidgets('renders with full width when fullWidth is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () {},
              fullWidth: true,
            ),
          ),
        ),
      );

      tester.widget<TextButton>(find.byType(TextButton));
      final parent = tester.widget<SizedBox>(find.ancestor(
        of: find.byType(TextButton),
        matching: find.byType(SizedBox),
      ));

      expect(parent.width, equals(double.infinity));
    });

    testWidgets('renders with destructive styling when isDestructive is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Delete',
              onPressed: () {},
              isDestructive: true,
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      final theme = Theme.of(tester.element(find.byType(TextButton)));
      expect(button.style?.foregroundColor?.resolve({}),
          equals(theme.colorScheme.error));
    });

    testWidgets('renders with primary color when not destructive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      final theme = Theme.of(tester.element(find.byType(TextButton)));
      expect(button.style?.foregroundColor?.resolve({}),
          equals(theme.colorScheme.primary));
    });

    testWidgets('renders with disabled color when disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () {},
              enabled: false,
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      final theme = Theme.of(tester.element(find.byType(TextButton)));
      final expectedColor =
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      expect(button.style?.foregroundColor?.resolve({}), equals(expectedColor));
    });

    testWidgets('renders with disabled color when onPressed is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: null,
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      final theme = Theme.of(tester.element(find.byType(TextButton)));
      final expectedColor =
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      expect(button.style?.foregroundColor?.resolve({}), equals(expectedColor));
    });

    testWidgets('has correct padding and styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LottiTertiaryButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<TextButton>(find.byType(TextButton));
      final style = button.style;

      expect(style?.padding?.resolve({}),
          equals(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)));
      expect(
          style?.textStyle?.resolve({})?.fontWeight, equals(FontWeight.w500));
      expect(style?.textStyle?.resolve({})?.fontSize, equals(16));
    });
  });
}
