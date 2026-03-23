import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemProgressBar', () {
    testWidgets('renders the default header and fill from tokens', (
      tester,
    ) async {
      const barKey = Key('default-progress-bar');

      await _pumpProgressBar(
        tester,
        const DesignSystemProgressBar(
          key: barKey,
          value: 0.7,
          label: 'Progress bar label',
          progressText: '70%',
          trailingIcon: Icons.star_outline_rounded,
        ),
      );

      final label = _findTextNode(tester, barKey, 'Progress bar label');
      final progress = _findTextNode(tester, barKey, '70%');
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
      );
      final fill = tester.widget<ColoredBox>(_fillFinder(barKey).first);
      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Progress bar label' &&
                widget.properties.value == '70%',
          ),
        ),
      );

      expect(tester.getSize(_progressTrackFinder(barKey)), const Size(544, 16));
      expectTextStyle(
        label.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expectTextStyle(
        progress.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(icon.size, 20);
      expect(icon.color, dsTokensLight.colors.text.highEmphasis);
      expect(fill.color, dsTokensLight.colors.interactive.enabled);
      expect(
        tester.getSize(_fillFinder(barKey).first).width,
        closeTo((544 - 6) * 0.7, 0.01),
      );
      expect(semantics.properties.label, 'Progress bar label');
      expect(semantics.properties.value, '70%');
    });

    testWidgets('renders the chunky quest bar with segmented fills', (
      tester,
    ) async {
      const barKey = Key('chunky-progress-bar');

      await _pumpProgressBar(
        tester,
        const DesignSystemProgressBar(
          key: barKey,
          value: 0.6,
          style: DesignSystemProgressBarStyle.chunky,
          label: 'Mega prize label',
          progressText: '45/60',
          trailingIcon: Icons.star_outline_rounded,
        ),
      );

      final label = _findTextNode(tester, barKey, 'Mega prize label');
      final progress = _findTextNode(tester, barKey, '45/60');

      expect(tester.getSize(_progressTrackFinder(barKey)), const Size(544, 16));
      expectTextStyle(
        label.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expectTextStyle(
        progress.style!,
        dsTokensLight.typography.styles.body.bodyMedium,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(_fillFinder(barKey), findsNWidgets(3));
      expect(_trackFinder(barKey), findsNWidgets(5));
      expect(tester.getSize(_fillFinder(barKey).first).height, 8);
      expect(tester.getSize(_fillFinder(barKey).first).width, greaterThan(0));
    });

    testWidgets('renders the off variant without a header and clamps values', (
      tester,
    ) async {
      const barKey = Key('off-progress-bar');

      await _pumpProgressBar(
        tester,
        const DesignSystemProgressBar(
          key: barKey,
          value: 1.4,
          semanticsLabel: 'Overall progress',
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Overall progress' &&
                widget.properties.value == '100%',
          ),
        ),
      );

      expect(tester.getSize(_progressTrackFinder(barKey)), const Size(544, 16));
      expect(
        find.descendant(of: find.byKey(barKey), matching: find.text('70%')),
        findsNothing,
      );
      expect(_fillFinder(barKey), findsOneWidget);
      expect(
        tester.getSize(_fillFinder(barKey).first).width,
        closeTo(544 - 6, 0.01),
      );
      expect(semantics.properties.label, 'Overall progress');
      expect(semantics.properties.value, '100%');
    });

    testWidgets('supports custom figma-specific colors', (tester) async {
      const barKey = Key('custom-progress-bar');
      const labelColor = Color(0xE0FFFFFF);
      const progressColor = Color(0xA3FFFFFF);
      const fillColor = Color(0xFF5ED4B7);

      await _pumpProgressBar(
        tester,
        const DesignSystemProgressBar(
          key: barKey,
          value: 0.5,
          label: 'Tasks',
          progressText: '3/5 completed',
          labelColor: labelColor,
          progressColor: progressColor,
          fillColor: fillColor,
        ),
      );

      final label = _findTextNode(tester, barKey, 'Tasks');
      final progress = _findTextNode(tester, barKey, '3/5 completed');
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(barKey),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == fillColor,
          ),
        ),
      );

      expect(label.style?.color, labelColor);
      expect(progress.style?.color, progressColor);
      expect(fill.color, fillColor);
    });
  });
}

Future<void> _pumpProgressBar(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(
        width: 544,
        child: child,
      ),
      theme: DesignSystemTheme.light(),
    ),
  );
}

Finder _fillFinder(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is ColoredBox &&
        widget.color == dsTokensLight.colors.interactive.enabled,
  ),
);

Finder _progressTrackFinder(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is SizedBox && widget.height == 16 && widget.width == null,
  ),
);

Finder _trackFinder(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is ColoredBox &&
        widget.color == dsTokensLight.colors.decorative.level01,
  ),
);

Text _findTextNode(WidgetTester tester, Key key, String text) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byKey(key),
      matching: find.text(text),
    ),
  );
}
