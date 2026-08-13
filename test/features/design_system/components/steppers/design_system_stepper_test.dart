import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemStepper', () {
    testWidgets('renders the label between the glyphs in tabular figures', (
      tester,
    ) async {
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3× / 7 days',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          onDecrement: () {},
          onIncrement: () {},
        ),
      );

      final text = tester.widget<Text>(find.text('3× / 7 days'));
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('fires the callbacks through the keyed glyphs', (tester) async {
      var decrements = 0;
      var increments = 0;
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3× / 7 days',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          decrementKey: const Key('stepper-decrease'),
          incrementKey: const Key('stepper-increase'),
          onDecrement: () => decrements++,
          onIncrement: () => increments++,
        ),
      );

      await tester.tap(find.byKey(const Key('stepper-decrease')));
      await tester.tap(find.byKey(const Key('stepper-increase')));
      await tester.tap(find.byKey(const Key('stepper-increase')));
      await tester.pump();

      expect(decrements, 1);
      expect(increments, 2);
    });

    testWidgets('a null callback disables that side only', (tester) async {
      var increments = 0;
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        DesignSystemStepper(
          label: '1× / 7 days',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          decrementKey: const Key('stepper-decrease'),
          onDecrement: null,
          onIncrement: () => increments++,
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Decrease')),
        matchesSemantics(
          label: 'Decrease',
          isButton: true,
          hasEnabledState: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Increase')),
        matchesSemantics(
          label: 'Increase',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      // The disabled glyph drops to low emphasis; the live one keeps the
      // interactive accent.
      expect(
        tester.widget<Icon>(find.byIcon(Icons.remove_rounded)).color,
        dsTokensLight.colors.text.lowEmphasis,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.add_rounded)).color,
        dsTokensLight.colors.interactive.enabled,
      );

      // Tapping the disabled side is inert.
      await tester.tap(
        find.byKey(const Key('stepper-decrease')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(increments, 0);
      semantics.dispose();
    });

    testWidgets('glyphs preserve the minimum pointer target', (tester) async {
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3× / 7 days',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          decrementKey: const Key('stepper-decrease'),
          incrementKey: const Key('stepper-increase'),
          onDecrement: () {},
          onIncrement: () {},
        ),
      );

      for (final key in const [
        Key('stepper-decrease'),
        Key('stepper-increase'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(TapTargets.minimum));
        expect(size.height, greaterThanOrEqualTo(TapTargets.minimum));
      }
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Center(child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
