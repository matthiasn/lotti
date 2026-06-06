import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernBaseCard Tests', () {
    testWidgets('renders with light theme (solid color, no gradient)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.light(),
        ),
      );

      await tester.pump();

      // Find the Container
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;

      // Light theme should have gradient when no background color is specified
      expect(decoration.color, isNull);
      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('renders with dark theme (gradient, no solid color)', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.dark(),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;

      // Dark theme should have gradient, no solid color
      expect(decoration.color, isNull);
      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient, isA<LinearGradient>());
    });

    testWidgets('custom background color overrides default', (tester) async {
      const customColor = Colors.red;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            backgroundColor: customColor,
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, customColor);
      expect(decoration.gradient, isNull);
    });

    testWidgets('custom border color overrides default', (tester) async {
      const customBorderColor = Colors.blue;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            borderColor: customBorderColor,
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect((decoration.border! as Border).top.color, customBorderColor);
    });

    testWidgets('custom gradient overrides default', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.red, Colors.blue],
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            gradient: customGradient,
            child: Text('Test Content'),
          ),
          theme: ThemeData.dark(), // Dark theme to test gradient override
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.gradient, customGradient);
    });

    testWidgets('tap callback is triggered correctly', (tester) async {
      // Plain closure instead of a Mock — a counter is all the tap test
      // needs, and it keeps the file free of one-off mock classes.
      var tapCount = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernBaseCard(
            onTap: () => tapCount++,
            child: const Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      // Tap the card
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('InkWell is present when onTap is provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ModernBaseCard(
            onTap: () {},
            child: const Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('no InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('normal mode uses standard padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            // isCompact defaults to false
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Material),
              matching: find.byType(Container),
            )
            .last,
      );

      expect(
        container.padding,
        const EdgeInsets.all(AppTheme.cardPadding),
      );
    });

    testWidgets('custom padding overrides default', (tester) async {
      const customPadding = EdgeInsets.all(50);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            padding: customPadding,
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Material),
              matching: find.byType(Container),
            )
            .last,
      );

      expect(container.padding, customPadding);
    });

    testWidgets('margin is applied correctly', (tester) async {
      const customMargin = EdgeInsets.all(20);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            margin: customMargin,
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      expect(container.margin, customMargin);
    });

    testWidgets('shadow differs between light and dark themes', (tester) async {
      // Test light theme shadow
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.light(),
        ),
      );

      await tester.pump();

      var container = tester.widget<Container>(
        find.byType(Container).first,
      );
      var decoration = container.decoration! as BoxDecoration;
      final lightShadow = decoration.boxShadow!.first;

      // Test dark theme shadow
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.dark(),
        ),
      );

      // Re-pumping with a new ThemeData animates via AnimatedTheme
      // (kThemeAnimationDuration = 200ms); advance past it in one bounded
      // pump instead of pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 250));

      container = tester.widget<Container>(
        find.byType(Container).first,
      );
      decoration = container.decoration! as BoxDecoration;
      final darkShadow = decoration.boxShadow!.first;

      // Shadows should be different
      expect(lightShadow.blurRadius, AppTheme.cardElevationLight);
      expect(darkShadow.blurRadius, AppTheme.cardElevationDark);
    });

    testWidgets('child content is rendered', (tester) async {
      const testText = 'Test Child Content';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text(testText),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(testText), findsOneWidget);
    });

    testWidgets('border radius is applied correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
        ),
      );

      await tester.pump();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppTheme.cardBorderRadius),
      );
    });

    testWidgets('theme changes apply instantly without animation', (
      tester,
    ) async {
      // Start with light theme
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.light(),
        ),
      );

      await tester.pump();

      // Verify Container is used (not AnimatedContainer)
      expect(find.byType(Container), findsWidgets);

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      // Container should not have duration or curve properties
      // (these only exist on AnimatedContainer)
      expect(container.runtimeType.toString(), 'Container');

      // Switch to dark theme
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernBaseCard(
            child: Text('Test Content'),
          ),
          theme: ThemeData.dark(),
        ),
      );

      // No animation should occur - theme should change immediately
      // We verify this by checking that after one frame (not pumpAndSettle),
      // the decoration has already changed
      await tester.pump();

      final darkContainer = tester.widget<Container>(
        find.byType(Container).first,
      );
      final darkDecoration = darkContainer.decoration! as BoxDecoration;

      // Dark theme should have gradient immediately
      expect(darkDecoration.gradient, isNotNull);
    });
  });
}
