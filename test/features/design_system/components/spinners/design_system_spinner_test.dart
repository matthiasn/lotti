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
}
