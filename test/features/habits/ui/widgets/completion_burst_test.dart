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
}
