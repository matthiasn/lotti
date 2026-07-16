import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/edge_fade.dart';

void main() {
  group('EdgeFade constructor contract', () {
    // Each case violates one bound the gradient math relies on; an
    // unchecked value would surface later as a clamp `ArgumentError` or an
    // invalid gradient-stop range, so the constructor rejects it up front.
    <String, EdgeFade Function()>{
      'negative rampExtent': () =>
          EdgeFade(rampExtent: -1, child: const SizedBox()),
      'minFraction below 0': () => EdgeFade(
        rampExtent: 8,
        minFraction: -0.1,
        child: const SizedBox(),
      ),
      'maxFraction above 1': () => EdgeFade(
        rampExtent: 8,
        maxFraction: 1.2,
        child: const SizedBox(),
      ),
      'min greater than max': () => EdgeFade(
        rampExtent: 8,
        minFraction: 0.6,
        child: const SizedBox(),
      ),
    }.forEach((description, build) {
      test('rejects $description', () {
        expect(build, throwsA(isA<AssertionError>()));
      });
    });

    test('accepts in-bounds fractions with min <= max', () {
      expect(
        () => const EdgeFade(
          rampExtent: 8,
          minFraction: 0.04,
          maxFraction: 0.5,
          child: SizedBox(),
        ),
        returnsNormally,
      );
    });
  });

  group('EdgeFade rendering', () {
    testWidgets('alpha-masks its child inside an isolated paint boundary', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EdgeFade(
              rampExtent: 16,
              fadeTop: false,
              child: Text('faded content'),
            ),
          ),
        ),
      );

      // The fade is a shader, not a clip — the child stays in the tree and
      // remains hit-testable, it just dissolves toward the chosen edge.
      final maskFinder = find.byType(ShaderMask);
      expect(maskFinder, findsOneWidget);
      expect(tester.widget<ShaderMask>(maskFinder).blendMode, BlendMode.dstIn);
      final boundary = find.byKey(EdgeFade.paintBoundaryKey);
      expect(boundary, findsOneWidget);
      expect(
        find.descendant(of: boundary, matching: find.text('faded content')),
        findsOneWidget,
      );
    });

    testWidgets('builds a valid mask for a zero-height paint bound', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EdgeFade(
            rampExtent: 16,
            minFraction: 0.08,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));

      // A temporarily collapsed timeline block can still reach the painter
      // during layout. The fallback fraction must keep that frame renderable
      // instead of dividing by zero or creating an invalid gradient.
      expect(() => mask.shaderCallback(Rect.zero), returnsNormally);
    });
  });
}
