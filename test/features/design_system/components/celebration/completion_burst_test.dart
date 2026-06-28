import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_burst_painters.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Finder burstPaint() => find.descendant(
    of: find.byType(CompletionBurst),
    matching: find.byType(CustomPaint),
  );

  CelebrationBurstPainter? painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(burstPaint()).painter
          as CelebrationBurstPainter?;

  Future<void> pump(WidgetTester tester, double progress) => tester.pumpWidget(
    makeTestableWidget(CompletionBurst(progress: progress)),
  );

  testWidgets('paints sparks only while mid-burst', (tester) async {
    await pump(tester, 0.5);
    expect(burstPaint(), findsOneWidget);
  });

  testWidgets('defaults to the sparks variant painter', (tester) async {
    await pump(tester, 0.5);
    expect(painterOf(tester), isA<SparksBurstPainter>());
  });

  testWidgets('builds the painter that matches the selected variant', (
    tester,
  ) async {
    for (final entry in const {
      CelebrationVariant.fireworks: FireworksBurstPainter,
      CelebrationVariant.confetti: ConfettiBurstPainter,
      CelebrationVariant.embers: EmbersBurstPainter,
      CelebrationVariant.bubbles: BubblesBurstPainter,
    }.entries) {
      await tester.pumpWidget(
        makeTestableWidget(
          CompletionBurst(
            progress: 0.5,
            params: CelebrationParams.defaultsFor(entry.key),
          ),
        ),
      );
      expect(
        painterOf(tester).runtimeType,
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('layers a CombinedBurstPainter when secondParams is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        CompletionBurst(
          progress: 0.5,
          params: CelebrationParams.defaultsFor(CelebrationVariant.sparks),
          secondParams: CelebrationParams.defaultsFor(
            CelebrationVariant.bubbles,
          ),
        ),
      ),
    );
    final painter = tester.widget<CustomPaint>(burstPaint()).painter;
    expect(painter, isA<CombinedBurstPainter>());
    final combined = painter! as CombinedBurstPainter;
    // Each layer keeps its own variant's painter, so the pair reads as two
    // effects firing at once.
    expect(combined.first, isA<SparksBurstPainter>());
    expect(combined.second, isA<BubblesBurstPainter>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints nothing at the burst endpoints (rest / spent)', (
    tester,
  ) async {
    await pump(tester, 0);
    expect(burstPaint(), findsNothing);
    await pump(tester, 1);
    expect(burstPaint(), findsNothing);
  });

  testWidgets('repaints across rebuilds (shouldRepaint compares every input)', (
    tester,
  ) async {
    Widget burst({
      double progress = 0.5,
      Alignment origin = const Alignment(0.82, 0),
    }) => makeTestableWidget(
      CompletionBurst(progress: progress, origin: origin),
    );

    await tester.pumpWidget(burst());
    // A fresh widget with identical inputs forces a painter swap; shouldRepaint
    // evaluates progress/origin/accent/gold (all equal → every branch runs).
    await tester.pumpWidget(burst());
    expect(burstPaint(), findsOneWidget);

    // A changed origin (same progress) exercises the origin comparison branch.
    await tester.pumpWidget(burst(origin: const Alignment(0.1, 0)));
    expect(burstPaint(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
