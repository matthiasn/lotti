import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_config_card_container.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../../widget_test_utils.dart';

/// Finds the [BoxDecoration] of the [AnimatedContainer] rendered by
/// [AiConfigCardContainer].
BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.byType(AnimatedContainer),
  );
  return container.decoration! as BoxDecoration;
}

/// Resolves the [ColorScheme] the rendered card actually sees, so assertions
/// compare against the real theme rather than re-hardcoded colors.
ColorScheme _schemeOf(WidgetTester tester) {
  final context = tester.element(find.byType(AiConfigCardContainer));
  return Theme.of(context).colorScheme;
}

void main() {
  const childKey = Key('card-child');

  Future<void> pumpCard(
    WidgetTester tester, {
    required Brightness brightness,
    required bool isSelected,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        AiConfigCardContainer(
          onTap: onTap ?? () {},
          isSelected: isSelected,
          child: const Text('content', key: childKey),
        ),
        theme: ThemeData(useMaterial3: true, brightness: brightness),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the provided child inside the card', (tester) async {
    await pumpCard(
      tester,
      brightness: Brightness.light,
      isSelected: false,
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AiConfigCardContainer),
        matching: find.text('content'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('invokes onTap when the card is tapped', (tester) async {
    var taps = 0;
    await pumpCard(
      tester,
      brightness: Brightness.light,
      isSelected: false,
      onTap: () => taps++,
    );

    await tester.tap(find.byType(AiConfigCardContainer));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets(
    'light + unselected: surface background, no gradient, subtle outline border',
    (tester) async {
      await pumpCard(
        tester,
        brightness: Brightness.light,
        isSelected: false,
      );

      final scheme = _schemeOf(tester);
      final decoration = _decorationOf(tester);

      // Background uses the surface color in light mode.
      expect(decoration.color, scheme.surface);
      // No gradient in light mode.
      expect(decoration.gradient, isNull);
      // Border is the subtle outline with width 1 (unselected).
      final border = decoration.border! as Border;
      expect(
        border.top.color,
        scheme.outline.withValues(alpha: AppTheme.alphaOutline),
      );
      expect(border.top.width, 1);
      // Shadow uses the light-mode alpha and elevation.
      final shadow = decoration.boxShadow!.single;
      expect(
        shadow.color,
        scheme.shadow.withValues(alpha: AppTheme.alphaShadowLight),
      );
      expect(shadow.blurRadius, AppTheme.cardElevationLight);
      expect(shadow.offset, AppTheme.shadowOffset);
    },
  );

  testWidgets(
    'dark + unselected: null background, linear gradient, container border',
    (tester) async {
      await pumpCard(
        tester,
        brightness: Brightness.dark,
        isSelected: false,
      );

      final scheme = _schemeOf(tester);
      final decoration = _decorationOf(tester);

      // Background color is null in dark mode (gradient is used instead).
      expect(decoration.color, isNull);

      // A two-stop diagonal LinearGradient is produced.
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
      expect(gradient.colors, [
        Color.lerp(
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          0.3,
        ),
        Color.lerp(
          scheme.surface,
          scheme.surfaceContainerLow,
          0.5,
        ),
      ]);

      // Border uses the primaryContainer tint in dark mode.
      final border = decoration.border! as Border;
      expect(
        border.top.color,
        scheme.primaryContainer.withValues(
          alpha: AppTheme.alphaPrimaryContainer,
        ),
      );
      expect(border.top.width, 1);

      // Shadow uses the dark-mode alpha and elevation.
      final shadow = decoration.boxShadow!.single;
      expect(
        shadow.color,
        scheme.shadow.withValues(alpha: AppTheme.alphaShadowDark),
      );
      expect(shadow.blurRadius, AppTheme.cardElevationDark);
    },
  );

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'selected (${brightness.name}): primary container bg, primary border, '
      'width 2, no gradient',
      (tester) async {
        await pumpCard(
          tester,
          brightness: brightness,
          isSelected: true,
        );

        final scheme = _schemeOf(tester);
        final decoration = _decorationOf(tester);

        // Selected background overrides brightness-based color.
        expect(
          decoration.color,
          scheme.primaryContainer.withValues(alpha: 0.3),
        );
        // Selected state never uses a gradient.
        expect(decoration.gradient, isNull);
        // Selected border is the primary color at half alpha, width 2.
        final border = decoration.border! as Border;
        expect(
          border.top.color,
          scheme.primary.withValues(alpha: 0.5),
        );
        expect(border.top.width, 2);
      },
    );
  }

  for (final selected in [true, false]) {
    testWidgets(
      'reflects isSelected=$selected through Semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpCard(
          tester,
          brightness: Brightness.light,
          isSelected: selected,
        );

        expect(
          tester.getSemantics(find.byType(InkWell)),
          matchesSemantics(
            // The card always advertises that it has a selected state...
            hasSelectedState: true,
            // ...and reflects the current selection through it.
            isSelected: selected,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
          ),
        );

        handle.dispose();
      },
    );
  }
}
