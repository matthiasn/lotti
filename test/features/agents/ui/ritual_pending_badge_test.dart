import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/ritual_pending_badge.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required int count,
    Widget child = const Text('child-widget'),
  }) {
    return makeTestableWidgetWithScaffold(
      RitualPendingBadge(child: child),
      overrides: [
        pendingRitualCountProvider.overrideWith((ref) async => count),
      ],
    );
  }

  group('RitualPendingBadge', () {
    testWidgets('wraps its child widget', (tester) async {
      await tester.pumpWidget(buildSubject(count: 0));
      await tester.pumpAndSettle();

      expect(find.text('child-widget'), findsOneWidget);
    });

    testWidgets('Badge label is hidden when count is 0', (tester) async {
      await tester.pumpWidget(buildSubject(count: 0));
      await tester.pumpAndSettle();

      // The Badge widget should be present but its label not visible
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });

    testWidgets('Badge label is visible when count is 3', (tester) async {
      await tester.pumpWidget(buildSubject(count: 3));
      await tester.pumpAndSettle();

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
    });

    testWidgets('Badge label shows the pending count as text', (tester) async {
      await tester.pumpWidget(buildSubject(count: 5));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('Badge label shows "1" when count is 1', (tester) async {
      await tester.pumpWidget(buildSubject(count: 1));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Badge label text does not appear when count is 0',
        (tester) async {
      await tester.pumpWidget(buildSubject(count: 0));
      await tester.pumpAndSettle();

      // "0" should never be rendered as a badge label when isLabelVisible is
      // false; the Badge itself uses isLabelVisible to gate rendering.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('wraps an Icon child correctly', (tester) async {
      await tester.pumpWidget(
        buildSubject(count: 2, child: const Icon(Icons.person)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
    });
  });
}
