import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemStepper', () {
    testWidgets('renders the label between the glyphs in tabular figures', (
      tester,
    ) async {
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3×/week',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          onDecrement: () {},
          onIncrement: () {},
        ),
      );

      final text = tester.widget<Text>(find.text('3×/week'));
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text.style?.color, dsTokensLight.colors.text.highEmphasis);
      // One level below a selection-row title: bodySmall, not bodyMedium.
      expect(
        text.style?.fontSize,
        dsTokensLight.typography.styles.body.bodySmall.fontSize,
      );
      expect(find.byIcon(LottiIcons.remove), findsOneWidget);
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
    });

    testWidgets('each glyph sits in a circular level02 container', (
      tester,
    ) async {
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3×/week',
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
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color, dsTokensLight.colors.background.level02);
        expect(
          container.constraints,
          BoxConstraints.tight(
            Size.square(dsTokensLight.spacing.step7),
          ),
        );
      }
    });

    testWidgets('the band absorbs taps that miss the glyphs', (tester) async {
      var rowTaps = 0;
      var increments = 0;
      await _pump(
        tester,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => rowTaps++,
          child: DesignSystemStepper(
            label: '3×/week',
            decrementTooltip: 'Decrease',
            incrementTooltip: 'Increase',
            incrementKey: const Key('stepper-increase'),
            onDecrement: () {},
            onIncrement: () => increments++,
          ),
        ),
      );

      // A tap on the band's label lands inside the stepper but outside any
      // glyph — it must not fall through to the hosting row.
      await tester.tap(find.text('3×/week'));
      await tester.pump();
      expect(rowTaps, 0);

      // The glyphs themselves still work.
      await tester.tap(find.byKey(const Key('stepper-increase')));
      await tester.pump();
      expect(increments, 1);
    });

    testWidgets('fires the callbacks through the keyed glyphs', (tester) async {
      var decrements = 0;
      var increments = 0;
      await _pump(
        tester,
        DesignSystemStepper(
          label: '3×/week',
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
          label: '1×/week',
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
        tester.widget<Icon>(find.byIcon(LottiIcons.remove)).color,
        dsTokensLight.colors.text.lowEmphasis,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.add)).color,
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
          label: '3×/week',
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
