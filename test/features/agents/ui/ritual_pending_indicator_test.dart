import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/ritual_pending_indicator.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  /// Creates a set of fake template IDs with the given size.
  Set<String> templateIds(int count) => {
    for (var i = 0; i < count; i++) 'template-$i',
  };

  Widget buildSubject({required int count}) {
    return makeTestableWidgetWithScaffold(
      const RitualPendingIndicator(),
      overrides: [
        templatesPendingReviewProvider.overrideWith(
          (ref) async => templateIds(count),
        ),
      ],
    );
  }

  /// Advances past the provider's async resolution without running the
  /// repeating animation to completion (which would never settle).
  Future<void> pumpUntilResolved(WidgetTester tester) async {
    // One pump to start the async future, one more to resolve it.
    await tester.pump();
    await tester.pump();
  }

  group('RitualPendingIndicator', () {
    testWidgets('renders SizedBox.shrink when count is 0', (tester) async {
      await tester.pumpWidget(buildSubject(count: 0));
      await pumpUntilResolved(tester);

      // When count is 0, the widget returns SizedBox.shrink — no Container
      // with a circular BoxDecoration is rendered.
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders SizedBox.shrink during loading state', (tester) async {
      final pending = Completer<Set<String>>();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RitualPendingIndicator(),
          overrides: [
            templatesPendingReviewProvider.overrideWith(
              (ref) => pending.future,
            ),
          ],
        ),
      );
      // Only pump once — the async hasn't resolved, so still in loading state.
      await tester.pump();

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders a Container with circular decoration when count > 0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(count: 3));
      await pumpUntilResolved(tester);

      // Advance one animation frame so AnimatedBuilder emits its first frame.
      await tester.pump(const Duration(milliseconds: 16));

      // When count > 0 the widget renders an AnimatedBuilder that builds a
      // 10×10 Container with a circular BoxDecoration.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dotContainer = containers.firstWhere(
        (c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        },
        orElse: () => throw TestFailure(
          'Expected a Container with circular BoxDecoration',
        ),
      );

      final decoration = dotContainer.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('dot Container has 10×10 rendered size when count > 0', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(count: 1));
      await pumpUntilResolved(tester);
      await tester.pump(const Duration(milliseconds: 16));

      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final d = widget.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        }
        return false;
      });
      expect(dotFinder, findsOneWidget);
      expect(tester.getSize(dotFinder), const Size(10, 10));
    });

    testWidgets('reduced motion shows a steady, full-strength dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RitualPendingIndicator(),
          mediaQueryData: const MediaQueryData(disableAnimations: true),
          overrides: [
            templatesPendingReviewProvider.overrideWith(
              (ref) async => templateIds(2),
            ),
          ],
        ),
      );
      await pumpUntilResolved(tester);

      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final d = widget.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        }
        return false;
      });
      expect(dotFinder, findsOneWidget);

      // The dot renders at full strength (the pulse's brightest frame) and
      // stays there — under reduced motion there is no pulse loop, so the
      // looping 0.4→1.0 fade never runs. A pumped second leaves it unchanged.
      final decoration =
          tester.widget<Container>(dotFinder).decoration! as BoxDecoration;
      expect(decoration.color!.a, 1.0);
      await tester.pump(const Duration(seconds: 1));
      final after =
          tester.widget<Container>(dotFinder).decoration! as BoxDecoration;
      expect(after.color!.a, 1.0);
    });

    testWidgets('dot Container has a boxShadow when count > 0', (tester) async {
      await tester.pumpWidget(buildSubject(count: 2));
      await pumpUntilResolved(tester);
      await tester.pump(const Duration(milliseconds: 16));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final dotContainer = containers.firstWhere(
        (c) {
          final d = c.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        },
        orElse: () => throw TestFailure('Expected circular Container'),
      );

      final decoration = dotContainer.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNotEmpty);
    });
  });
}
