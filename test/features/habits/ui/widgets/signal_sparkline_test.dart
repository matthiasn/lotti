import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/signal_sparkline.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<num?> values) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(width: 200, child: SignalSparkline(values: values)),
        ),
      );

  testWidgets("announces today's value and paints one bar per day", (
    tester,
  ) async {
    await pump(tester, [1, null, 3, 4]);
    expect(find.bySemanticsLabel('4'), findsOneWidget);
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SignalSparkline),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    expect(painter, isNotNull);
    expect(painter!.shouldRepaint(painter), isFalse);
  });

  testWidgets('an empty today has no value to announce', (tester) async {
    await pump(tester, [1, 2, null]);
    expect(find.bySemanticsLabel('1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty series renders nothing and announces nothing', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.byType(SignalSparkline), findsOneWidget);
  });

  testWidgets('all-empty and all-zero series render without dividing by zero', (
    tester,
  ) async {
    await pump(tester, [null, null, null]);
    expect(tester.takeException(), isNull);
    await pump(tester, [0, 0, 0]);
    expect(tester.takeException(), isNull);
  });
}
