import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/skeleton_agenda.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Scaffold(body: Center(child: child)),
  mediaQueryData: const MediaQueryData(size: Size(800, 1000)),
);

/// Locates the four `Container`s built by `_ShimmerCard` (each one
/// renders a 64-pixel-high decorated box).
Finder _shimmerCards() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).gradient is LinearGradient,
);

void main() {
  group('SkeletonAgenda', () {
    testWidgets('default constructor renders 4 shimmer card placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SkeletonAgenda()));
      await tester.pump();

      expect(_shimmerCards(), findsNWidgets(4));
    });

    testWidgets('cardCount overrides the placeholder count', (tester) async {
      await tester.pumpWidget(_wrap(const SkeletonAgenda(cardCount: 7)));
      await tester.pump();

      expect(_shimmerCards(), findsNWidgets(7));
    });

    testWidgets('cardCount=1 renders a single card with no spacer', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SkeletonAgenda(cardCount: 1)));
      await tester.pump();

      expect(_shimmerCards(), findsOneWidget);
      // With only one card there are no inter-card SizedBox spacers.
      expect(find.byType(SizedBox), findsNothing);
    });

    testWidgets(
      'shimmer position advances over time (gradient stops change between frames)',
      (tester) async {
        await tester.pumpWidget(_wrap(const SkeletonAgenda(cardCount: 1)));
        await tester.pump();

        final firstCard = tester.widget<Container>(_shimmerCards().first);
        final firstStops =
            (firstCard.decoration! as BoxDecoration).gradient!.stops!;

        // Advance the ticker by ~half a cycle and re-read.
        await tester.pump(const Duration(milliseconds: 900));

        final laterCard = tester.widget<Container>(_shimmerCards().first);
        final laterStops =
            (laterCard.decoration! as BoxDecoration).gradient!.stops!;

        expect(laterStops, isNot(equals(firstStops)));
      },
    );

    testWidgets('cards share the same gradient + border type across the column', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SkeletonAgenda(cardCount: 3)));
      await tester.pump();

      for (final element in _shimmerCards().evaluate()) {
        final container = element.widget as Container;
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());
        expect(decoration.border, isNotNull);
      }
    });

    testWidgets('disposing the widget cancels the ticker', (tester) async {
      await tester.pumpWidget(_wrap(const SkeletonAgenda()));
      await tester.pump();

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      // Pump past several would-be frames — nothing should throw, and
      // the now-disposed SkeletonAgenda must not rebuild its tree.
      await tester.pump(const Duration(seconds: 2));
      expect(_shimmerCards(), findsNothing);
    });
  });
}
