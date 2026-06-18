import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/completion_burst.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Finder burstPaint() => find.descendant(
    of: find.byType(CompletionBurst),
    matching: find.byType(CustomPaint),
  );

  Future<void> pump(WidgetTester tester, double progress) => tester.pumpWidget(
    makeTestableWidget(CompletionBurst(progress: progress)),
  );

  testWidgets('paints sparks only while mid-burst', (tester) async {
    await pump(tester, 0.5);
    expect(burstPaint(), findsOneWidget);
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
