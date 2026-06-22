import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/ui/widgets/aurora_hero.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Helper that wraps the aurora in a bounded box so the infinite-size
  // CustomPaint has concrete dimensions to paint into.
  Widget bounded(Widget child) => Center(
    child: SizedBox(
      width: 360,
      height: 264,
      child: child,
    ),
  );

  group('AuroraHero', () {
    testWidgets('paints a single static frame under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          bounded(
            const AuroraHero(
              colors: [Colors.purple, Colors.blue, Colors.teal],
              maxAlpha: 0.4,
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AuroraHero), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // The painter ran for all blooms without throwing.
      expect(tester.takeException(), isNull);
    });

    testWidgets('drives the repeating animation across multiple frames', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          bounded(
            const AuroraHero(
              colors: [Colors.purple, Colors.blue, Colors.teal, Colors.green],
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );
      await tester.pump();

      // Advance the repeating controller through several frames. Never
      // pumpAndSettle a repeating animation — it would time out.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AuroraHero), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // Each animated frame repainted every bloom without throwing.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shouldRepaint: rebuild with different colors and maxAlpha repaints',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            bounded(
              const AuroraHero(
                colors: [Colors.purple, Colors.blue, Colors.teal],
                maxAlpha: 0.4,
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Same widget type at the same position -> element update reuses the
        // State and feeds a new painter into shouldRepaint. Different colors
        // (length + values) and a different maxAlpha exercise the
        // !listEquals(...) and maxAlpha != branches.
        await tester.pumpWidget(
          makeTestableWidget(
            bounded(
              const AuroraHero(
                colors: [Colors.red, Colors.orange],
                maxAlpha: 0.7,
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AuroraHero), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shouldRepaint: new list instance with equal values hits listEquals path',
      (tester) async {
        const colors = [Colors.purple, Colors.blue, Colors.teal];

        await tester.pumpWidget(
          makeTestableWidget(
            bounded(
              // Reduced motion so t stays constant: the only way the painter
              // changes is through colors/maxAlpha, isolating the listEquals
              // equal-values comparison.
              const AuroraHero(colors: colors, maxAlpha: 0.4),
            ),
            mediaQueryData: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump();

        // A brand-new list instance with identical color values: listEquals
        // returns true (equal path) while maxAlpha is unchanged.
        await tester.pumpWidget(
          makeTestableWidget(
            bounded(
              AuroraHero(
                colors: List<Color>.from(colors),
                maxAlpha: 0.4,
              ),
            ),
            mediaQueryData: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AuroraHero), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disposes cleanly when removed from the tree', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          bounded(
            const AuroraHero(colors: [Colors.purple, Colors.blue]),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Replace with an empty box: the AnimationController is disposed.
      await tester.pumpWidget(
        makeTestableWidget(
          bounded(const SizedBox.shrink()),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );
      await tester.pump();

      expect(find.byType(AuroraHero), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
