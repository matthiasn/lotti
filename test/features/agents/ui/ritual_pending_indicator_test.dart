import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/ritual_pending_indicator.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  /// Creates a set of fake template IDs with the given size.
  Set<String> templateIds(int count) =>
      {for (var i = 0; i < count; i++) 'template-$i'};

  Widget buildSubject({required int count}) {
    return makeTestableWidgetWithScaffold(
      const RitualPendingIndicator(),
      overrides: [
        templatesPendingReviewProvider
            .overrideWith((ref) async => templateIds(count)),
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
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RitualPendingIndicator(),
          overrides: [
            // A Completer future that never completes keeps loading state.
            templatesPendingReviewProvider.overrideWith(
              (ref) => Future<Set<String>>.error(Exception('never'))
                  .catchError((_) => <String>{})
                  .then((_) => throw UnimplementedError()),
            ),
          ],
        ),
      );
      // Only pump once — the async hasn't resolved, so still in loading state.
      await tester.pump();

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders a Container with circular decoration when count > 0',
        (tester) async {
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

    testWidgets('dot Container has 10×10 size when count > 0', (tester) async {
      await tester.pumpWidget(buildSubject(count: 1));
      await pumpUntilResolved(tester);
      await tester.pump(const Duration(milliseconds: 16));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final dotContainer = containers.firstWhere(
        (c) {
          final d = c.decoration;
          return d is BoxDecoration && d.shape == BoxShape.circle;
        },
        orElse: () => throw TestFailure('Expected a 10×10 circular Container'),
      );

      expect(dotContainer.constraints?.maxWidth, 10);
      expect(dotContainer.constraints?.maxHeight, 10);
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
