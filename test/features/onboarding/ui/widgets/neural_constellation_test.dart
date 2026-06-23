import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/ui/widgets/neural_constellation.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('NeuralConstellation', () {
    Widget wrap(NeuralConstellation child) => SizedBox(
      width: 320,
      height: 240,
      child: child,
    );

    testWidgets('paints a static frame under reduced motion', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const NeuralConstellation(
              nodeColor: Colors.white,
              lineColor: Colors.blue,
              pulseColor: Colors.cyan,
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
        ),
      );

      // didChangeDependencies took the reduced-motion (controller.stop) branch
      // and a single static frame was painted.
      await tester.pump();

      expect(find.byType(NeuralConstellation), findsOneWidget);
      // RepaintBoundary + AnimatedBuilder yield CustomPaint instances.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('advances the looping animation when motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const NeuralConstellation(
              nodeColor: Colors.white,
              lineColor: Colors.blue,
              // Several pulses so the edges.isNotEmpty / pulse loop runs.
              pulseColor: Colors.cyan,
              pulseCount: 4,
              // Larger field so synapse lines (and thus edges) are produced.
              nodeCount: 40,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );

      await tester.pump();

      // Drive the 24s controller across several seconds so node drift, line
      // alpha fade, pulses and the breathing glow are all exercised in paint().
      // Never pumpAndSettle() a repeating animation.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(find.byType(NeuralConstellation), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('regenerates nodes via didUpdateWidget on input change', (
      tester,
    ) async {
      const key = ValueKey('constellation');

      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const NeuralConstellation(
              key: key,
              nodeColor: Colors.white,
              lineColor: Colors.blue,
              pulseColor: Colors.cyan,
              nodeCount: 30,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Same widget type at the same position with the SAME key but DIFFERENT
      // nodeCount + seed → Flutter reuses the element and didUpdateWidget runs
      // the _buildNodes regenerate branch.
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const NeuralConstellation(
              key: key,
              nodeColor: Colors.white,
              lineColor: Colors.blue,
              pulseColor: Colors.cyan,
              nodeCount: 12,
              seed: 9,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Still renders without error after the topology change.
      expect(find.byType(NeuralConstellation), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // Now change ONLY the seed (nodeCount stays 12) so the short-circuit
      // `||` in didUpdateWidget evaluates its right-hand operand
      // (oldWidget.seed != widget.seed) and still regenerates the nodes.
      await tester.pumpWidget(
        makeTestableWidget(
          wrap(
            const NeuralConstellation(
              key: key,
              nodeColor: Colors.white,
              lineColor: Colors.blue,
              pulseColor: Colors.cyan,
              nodeCount: 12,
              seed: 42,
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NeuralConstellation), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'paints with no edges and no pulses (sparse field, zero pulses)',
      (tester) async {
        // A tiny, sparse field keeps node distances above the link threshold so
        // the edge list stays empty and the edges.isNotEmpty pulse block is
        // skipped; pulseCount 0 also exercises the no-pulse path. Nodes still
        // paint via the breathing-glow loop.
        await tester.pumpWidget(
          makeTestableWidget(
            wrap(
              const NeuralConstellation(
                nodeColor: Colors.white,
                lineColor: Colors.blue,
                pulseColor: Colors.cyan,
                nodeCount: 2,
                pulseCount: 0,
                seed: 1,
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        expect(find.byType(NeuralConstellation), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('loop seam continuity', () {
    const size = Size(320, 240);

    test(
      'node drift + breath return to their start at the wrap (t01 1 == 0)',
      () {
        // A few representative nodes with assorted integer cycle counts.
        const nodes = [
          NeuralNode(
            base: Offset(0.3, 0.6),
            driftX: 0.04,
            driftY: 0.03,
            phase: 1.2,
            driftCycles: 1,
            breathCycles: 1,
            radius: 2,
          ),
          NeuralNode(
            base: Offset(0.7, 0.2),
            driftX: 0.02,
            driftY: 0.05,
            phase: 4.9,
            driftCycles: 3,
            breathCycles: 2,
            radius: 1.6,
          ),
        ];
        for (final node in nodes) {
          final start = node.positionAt(0, size);
          final end = node.positionAt(1, size);
          // The frame at the loop end is the same as at the start — no snap.
          expect(end.dx, closeTo(start.dx, 1e-9));
          expect(end.dy, closeTo(start.dy, 1e-9));
          expect(node.breathAt(1), closeTo(node.breathAt(0), 1e-9));
        }
      },
    );

    test('every pulse is fully faded out at the seam, alive mid-loop', () {
      const pulseCycles = 7; // e.g. a 24s loop
      for (var k = 0; k < 4; k++) {
        // Envelope is exactly zero at both ends of the loop, so no pulse jumps.
        expect(neuralPulseEnvAt(0, pulseCycles, k), closeTo(0, 1e-9));
        expect(neuralPulseEnvAt(1, pulseCycles, k), closeTo(0, 1e-9));
      }
      // Mid-loop the pulses do light up (so the effect isn't simply absent).
      final anyAlive = [
        for (var k = 0; k < 4; k++) neuralPulseEnvAt(0.5, pulseCycles, k),
      ].any((env) => env > 0.1);
      expect(anyAlive, isTrue);
    });

    test('pulse cycles per loop is a whole number >= 1', () {
      expect(neuralPulseCyclesForLoop(const Duration(seconds: 24)), 7);
      expect(neuralPulseCyclesForLoop(const Duration(seconds: 14)), 4);
      expect(
        neuralPulseCyclesForLoop(const Duration(milliseconds: 500)),
        greaterThanOrEqualTo(1),
      );
    });
  });
}
