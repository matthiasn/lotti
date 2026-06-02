import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemSpinner', () {
    testWidgets('renders at default size with track style', (tester) async {
      const spinnerKey = Key('default-spinner');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            key: spinnerKey,
            semanticsLabel: 'Loading',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.getSize(find.byKey(spinnerKey)), const Size.square(48));
      expect(
        find.descendant(
          of: find.byKey(spinnerKey),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders at custom size', (tester) async {
      const spinnerKey = Key('custom-spinner');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            key: spinnerKey,
            size: 80,
            semanticsLabel: 'Loading',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.getSize(find.byKey(spinnerKey)), const Size.square(80));
    });

    testWidgets('provides semantics label', (tester) async {
      const spinnerKey = Key('semantics-spinner');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            key: spinnerKey,
            semanticsLabel: 'Loading content',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(spinnerKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Loading content',
          ),
        ),
      );

      expect(semantics.properties.label, 'Loading content');
    });

    testWidgets('uses the track painter for track style', (tester) async {
      const spinnerKey = Key('track-painter-spinner');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            key: spinnerKey,
            semanticsLabel: 'Loading',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(spinnerKey),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(customPaint.painter, isNotNull);
    });

    testWidgets('animation controller drives rotation', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            semanticsLabel: 'Loading',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Pump a partial duration to verify animation progresses
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes animation controller without error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemSpinner(
            semanticsLabel: 'Loading',
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      // Replace with empty container to trigger dispose
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('DesignSystemSkeleton', () {
    testWidgets('renders at default dimensions with wave animation', (
      tester,
    ) async {
      const skeletonKey = Key('default-skeleton');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              key: skeletonKey,
              semanticsLabel: 'Loading placeholder',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final size = tester.getSize(find.byKey(skeletonKey));
      expect(size.height, 40);
      expect(size.width, 200);
    });

    testWidgets('renders with custom height', (tester) async {
      const skeletonKey = Key('custom-skeleton');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 300,
            child: DesignSystemSkeleton(
              key: skeletonKey,
              height: 24,
              semanticsLabel: 'Loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.getSize(find.byKey(skeletonKey)).height, 24);
    });

    testWidgets('applies custom border radius', (tester) async {
      const skeletonKey = Key('rounded-skeleton');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              key: skeletonKey,
              borderRadius: 16,
              semanticsLabel: 'Loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(skeletonKey),
          matching: find.byType(ClipRRect),
        ),
      );

      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(16),
      );
    });

    testWidgets('uses token-based border radius by default', (tester) async {
      const skeletonKey = Key('token-skeleton');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              key: skeletonKey,
              semanticsLabel: 'Loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(skeletonKey),
          matching: find.byType(ClipRRect),
        ),
      );

      expect(
        clipRRect.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.xs),
      );
    });

    testWidgets('provides semantics label', (tester) async {
      const skeletonKey = Key('semantics-skeleton');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              key: skeletonKey,
              semanticsLabel: 'Content loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(skeletonKey),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Content loading',
          ),
        ),
      );

      expect(semantics.properties.label, 'Content loading');
    });

    testWidgets('pulse animation runs without error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              animation: DesignSystemSkeletonAnimation.pulse,
              semanticsLabel: 'Loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 750));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 750));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes animation controller without error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200,
            child: DesignSystemSkeleton(
              semanticsLabel: 'Loading',
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // The spinner/skeleton painters are private, so we capture them off the
  // widget tree as CustomPainter and call shouldRepaint cross-wise. Rendering
  // the two variants in the same frame (one pump) guarantees their animation
  // values are identical, so the leading rotation/progress comparison is false
  // and the OR branches for the field under test are the ones that decide the
  // result. This exercises every comparison branch in both shouldRepaint
  // overrides.
  group('_SpinnerPainter.shouldRepaint', () {
    Future<(CustomPainter, CustomPainter)> pumpPair(
      WidgetTester tester, {
      required DesignSystemSpinner left,
      required DesignSystemSpinner right,
      ThemeData? leftTheme,
      ThemeData? rightTheme,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Row(
            children: [
              Theme(data: leftTheme ?? DesignSystemTheme.light(), child: left),
              Theme(
                data: rightTheme ?? DesignSystemTheme.light(),
                child: right,
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((cp) => cp.painter != null)
          .map((cp) => cp.painter!)
          .toList();
      return (painters[0], painters[1]);
    }

    testWidgets('returns false when nothing differs', (tester) async {
      final (a, b) = await pumpPair(
        tester,
        left: const DesignSystemSpinner(semanticsLabel: 'a'),
        right: const DesignSystemSpinner(semanticsLabel: 'b'),
      );

      // Same theme, same style/strokeWidth, same frame -> identical fields.
      expect(a.shouldRepaint(b), isFalse);
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('returns true when only the style differs', (tester) async {
      final (track, plain) = await pumpPair(
        tester,
        left: const DesignSystemSpinner(semanticsLabel: 'track'),
        right: const DesignSystemSpinner(
          style: DesignSystemSpinnerStyle.plain,
          semanticsLabel: 'plain',
        ),
      );

      expect(track.shouldRepaint(plain), isTrue);
      expect(plain.shouldRepaint(track), isTrue);
    });

    testWidgets('returns true when only the strokeWidth differs', (
      tester,
    ) async {
      final (thin, thick) = await pumpPair(
        tester,
        left: const DesignSystemSpinner(strokeWidth: 4, semanticsLabel: 'thin'),
        right: const DesignSystemSpinner(
          strokeWidth: 12,
          semanticsLabel: 'thick',
        ),
      );

      expect(thin.shouldRepaint(thick), isTrue);
      expect(thick.shouldRepaint(thin), isTrue);
    });

    testWidgets('returns true when only the color differs', (tester) async {
      final (light, dark) = await pumpPair(
        tester,
        left: const DesignSystemSpinner(semanticsLabel: 'light'),
        right: const DesignSystemSpinner(semanticsLabel: 'dark'),
        rightTheme: DesignSystemTheme.dark(),
      );

      // interactive.enabled differs between light and dark tokens.
      expect(light.shouldRepaint(dark), isTrue);
      expect(dark.shouldRepaint(light), isTrue);
    });
  });

  group('_SkeletonPainter.shouldRepaint', () {
    Future<(CustomPainter, CustomPainter)> pumpPair(
      WidgetTester tester, {
      required DesignSystemSkeleton left,
      required DesignSystemSkeleton right,
      ThemeData? leftTheme,
      ThemeData? rightTheme,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Theme(
                  data: leftTheme ?? DesignSystemTheme.light(),
                  child: left,
                ),
              ),
              SizedBox(
                width: 100,
                child: Theme(
                  data: rightTheme ?? DesignSystemTheme.light(),
                  child: right,
                ),
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((cp) => cp.painter != null)
          .map((cp) => cp.painter!)
          .toList();
      return (painters[0], painters[1]);
    }

    testWidgets('returns false when nothing differs', (tester) async {
      final (a, b) = await pumpPair(
        tester,
        left: const DesignSystemSkeleton(semanticsLabel: 'a'),
        right: const DesignSystemSkeleton(semanticsLabel: 'b'),
      );

      expect(a.shouldRepaint(b), isFalse);
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('returns true when only the animation differs', (tester) async {
      final (wave, pulse) = await pumpPair(
        tester,
        left: const DesignSystemSkeleton(semanticsLabel: 'wave'),
        right: const DesignSystemSkeleton(
          animation: DesignSystemSkeletonAnimation.pulse,
          semanticsLabel: 'pulse',
        ),
      );

      expect(wave.shouldRepaint(pulse), isTrue);
      expect(pulse.shouldRepaint(wave), isTrue);
    });

    testWidgets('returns true when the base/shimmer colors differ', (
      tester,
    ) async {
      final (light, dark) = await pumpPair(
        tester,
        left: const DesignSystemSkeleton(semanticsLabel: 'light'),
        right: const DesignSystemSkeleton(semanticsLabel: 'dark'),
        rightTheme: DesignSystemTheme.dark(),
      );

      // text.highEmphasis (and thus baseColor + shimmerColor) differs between
      // light and dark tokens.
      expect(light.shouldRepaint(dark), isTrue);
      expect(dark.shouldRepaint(light), isTrue);
    });
  });
}
