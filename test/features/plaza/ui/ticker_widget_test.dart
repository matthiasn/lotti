import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/ticker_widget.dart';

import '../../../widget_test_utils.dart';

void main() {
  Widget host() => makeTestableWidget2(
    const Center(
      child: SizedBox(
        width: 400,
        height: 60,
        child: TickerWidget(
          text: 'Project Waddle · 4 need attention',
          heightMeters: 1.3,
          pxPerMeter: 40,
          speedMetersPerSecond: 3,
        ),
      ),
    ),
  );

  testWidgets('draws two copies of the text and scrolls them leftward', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final copies = find.text('Project Waddle · 4 need attention');
    expect(copies, findsNWidgets(2));
    double leftOf(int i) =>
        tester.widget<Positioned>(find.byType(Positioned).at(i)).left!;
    final a0 = leftOf(0);
    final b0 = leftOf(1);
    expect(b0, greaterThan(a0)); // second copy trails the first
    await tester.pump(const Duration(milliseconds: 500));
    final a1 = leftOf(0);
    // 3 m/s × 40 px/m × 0.5 s = 60 px to the left.
    expect(a0 - a1, closeTo(60, 1));
    expect(leftOf(1) - a1, closeTo(b0 - a0, 1e-6)); // gap preserved
  });

  testWidgets('wraps around instead of drifting off forever', (tester) async {
    await tester.pumpWidget(host());
    double leftOf(int i) =>
        tester.widget<Positioned>(find.byType(Positioned).at(i)).left!;
    final gap = leftOf(1) - leftOf(0); // one copy width
    await tester.pump(const Duration(seconds: 30));
    expect(leftOf(0), greaterThan(-gap));
    expect(leftOf(0), lessThanOrEqualTo(0));
  });
}
