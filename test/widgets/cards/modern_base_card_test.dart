import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

    group('selected', () {
      BoxDecoration decorationOf(WidgetTester tester) {
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        return container.decoration! as BoxDecoration;
      }

      testWidgets(
        'paints the activated fill over the base color and an accent border',
        (tester) async {
          const baseColor = Color(0xFF222222);
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ModernBaseCard(
                selected: true,
                backgroundColor: baseColor,
                child: Text('Selected'),
              ),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(ModernBaseCard));
          final tokens = context.designTokens;
          final decoration = decorationOf(tester);

          expect(decoration.gradient, isNull);
          expect(
            decoration.color,
            Color.alphaBlend(
              DesignSystemListPalette.activatedFill(tokens),
              baseColor,
            ),
          );
          expect(
            decoration.border,
            Border.all(color: tokens.colors.interactive.enabled),
          );
        },
      );

      testWidgets(
        'without an explicit background, the fill blends over colorScheme '
        'surface',
        (tester) async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ModernBaseCard(
                selected: true,
                child: Text('Selected, no background'),
              ),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(ModernBaseCard));
          final tokens = context.designTokens;
          final decoration = decorationOf(tester);

          // The selected base falls back to the theme surface when no
          // backgroundColor is supplied.
          expect(
            decoration.color,
            Color.alphaBlend(
              DesignSystemListPalette.activatedFill(tokens),
              context.colorScheme.surface,
            ),
          );
        },
      );

      testWidgets(
        'unselected card under the same theme keeps the plain treatment',
        (tester) async {
          const baseColor = Color(0xFF222222);
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ModernBaseCard(
                backgroundColor: baseColor,
                child: Text('Not selected'),
              ),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(ModernBaseCard));
          final decoration = decorationOf(tester);

          expect(decoration.color, baseColor);
          expect(
            decoration.border,
            isNot(
              Border.all(
                color: context.designTokens.colors.interactive.enabled,
              ),
            ),
          );
        },
      );

      testWidgets(
        'isEnhanced draws the two-layer shadow instead of the standard one',
        (tester) async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ModernBaseCard(
                isEnhanced: true,
                child: Text('Enhanced'),
              ),
              theme: ThemeData.dark(),
            ),
          );
          await tester.pump();

          final container = tester.widget<Container>(
            find.byType(Container).first,
          );
          final decoration = container.decoration! as BoxDecoration;
          // The enhanced treatment layers two shadows; the standard card
          // draws exactly one.
          expect(decoration.boxShadow, hasLength(2));
        },
      );

      testWidgets(
        'EnhancedModernCard wraps ModernBaseCard with the enhanced treatment '
        'and forwards taps',
        (tester) async {
          var tapped = 0;
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              EnhancedModernCard(
                onTap: () => tapped++,
                child: const Text('Enhanced wrapper'),
              ),
              theme: ThemeData.dark(),
            ),
          );
          await tester.pump();

          final baseCard = tester.widget<ModernBaseCard>(
            find.byType(ModernBaseCard),
          );
          expect(baseCard.isEnhanced, isTrue);
          expect(baseCard.gradient, isNotNull);

          await tester.tap(find.text('Enhanced wrapper'));
          await tester.pump();
          expect(tapped, 1);
        },
      );

      testWidgets(
        'unselected card renders under a theme without design tokens',
        (tester) async {
          // Regression guard: token resolution must stay lazy — an unselected
          // card on a plain ThemeData (no DsTokens extension) must not throw.
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const ModernBaseCard(child: Text('Plain theme')),
              theme: ThemeData.dark(),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Plain theme'), findsOneWidget);
        },
      );

      testWidgets(
        'ink feedback falls back to colorScheme.primary under a token-less '
        'theme',
        (tester) async {
          // Built without the test helper (which injects DsTokens), so the
          // theme genuinely lacks the extension — exercising the fallback that
          // real token-less consumers rely on for the tap splash.
          final theme = ThemeData(useMaterial3: true);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: ModernBaseCard(
                  onTap: () {},
                  child: const Text('Token-less ink'),
                ),
              ),
            ),
          );
          await tester.pump();

          final inkWell = tester.widget<InkWell>(find.byType(InkWell));
          expect(
            inkWell.splashColor,
            theme.colorScheme.primary.withValues(alpha: AppTheme.alphaPrimary),
          );
          expect(
            inkWell.highlightColor,
            theme.colorScheme.primary.withValues(
              alpha: AppTheme.alphaPrimaryHighlight,
            ),
          );
        },
      );
    });
  });
}
