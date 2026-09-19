import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_circular_progress.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemCircularProgress', () {
    testWidgets('renders determinate progress with center content', (
      tester,
    ) async {
      const progressKey = Key('circular-progress');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemCircularProgress(
              key: progressKey,
              value: 0.78,
              size: DesignSystemCircularProgressSize.large,
              semanticsLabel: 'Health Score',
              center: Text('78'),
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byKey(progressKey),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(progressKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Health Score' &&
                widget.properties.value == '78%',
          ),
        ),
      );

      expect(progress.value, 0.78);
      expect(progress.strokeWidth, 6);
      expect(progress.strokeCap, StrokeCap.round);
      expect(progress.backgroundColor, dsTokensLight.colors.decorative.level01);
      expect(
        progress.valueColor?.value,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(find.text('78'), findsOneWidget);
      expect(semantics.properties.label, 'Health Score');
      expect(semantics.properties.value, '78%');
    });

    for (final (size, dimension, strokeWidth, centerStyle) in [
      (
        DesignSystemCircularProgressSize.small,
        dsTokensLight.spacing.step9,
        4.0,
        dsTokensLight.typography.styles.subtitle.subtitle2,
      ),
      (
        DesignSystemCircularProgressSize.medium,
        dsTokensLight.spacing.step10,
        5.0,
        dsTokensLight.typography.styles.subtitle.subtitle1,
      ),
    ]) {
      testWidgets('${size.name} ring is ${dimension}px with a '
          '${strokeWidth}px stroke and clamps out-of-range values', (
        tester,
      ) async {
        const progressKey = Key('circular-progress');
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Center(
              child: DesignSystemCircularProgress(
                key: progressKey,
                value: 1.4,
                size: size,
                center: const Text('done'),
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(tester.getSize(find.byKey(progressKey)), Size.square(dimension));
        expect(progress.strokeWidth, strokeWidth);
        expect(progress.value, 1.0);
        final centerText = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(progressKey),
            matching: find.byType(RichText),
          ),
        );
        expect(centerText.text.style?.fontSize, centerStyle.fontSize);
        expect(
          tester.getSemantics(find.byKey(progressKey)).value,
          '100%',
        );
      });
    }
  });
}
