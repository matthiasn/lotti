import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/ui/widgets/completion_glow.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BoxShadow> shadowAt(WidgetTester tester, double value) async {
    await tester.pumpWidget(makeTestableWidget(CompletionGlow(value: value)));
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(CompletionGlow),
        matching: find.byType(DecoratedBox),
      ),
    );
    return (box.decoration as BoxDecoration).boxShadow!.first;
  }

  testWidgets('blooms outward and fades as value runs 0 → 1', (tester) async {
    final start = await shadowAt(tester, 0); // instant of completion
    final later = await shadowAt(tester, 0.9); // most of the way through

    // Brightest at the start, nearly gone later.
    expect(start.color.a, greaterThan(later.color.a));
    // The halo spreads outward and softens as it dissipates.
    expect(later.spreadRadius, greaterThan(start.spreadRadius));
    expect(later.blurRadius, greaterThan(start.blurRadius));
  });

  testWidgets('is fully transparent at rest (value 1)', (tester) async {
    final rest = await shadowAt(tester, 1);
    expect(rest.color.a, 0.0);
  });
}
