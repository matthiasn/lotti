import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<BoxShadow> shadowAt(
    WidgetTester tester,
    double value, {
    double intensity = 1.0,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(CompletionGlow(value: value, intensity: intensity)),
    );
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

  testWidgets('intensity scales the peak opacity', (tester) async {
    // At the instant of completion (value 0), a 0.1 intensity glow is a tenth
    // as bright as a full-strength one — a soft acknowledgement, not a flash.
    final full = await shadowAt(tester, 0);
    final dim = await shadowAt(tester, 0, intensity: 0.1);

    expect(dim.color.a, closeTo(full.color.a * 0.1, 0.001));
    // Geometry (blur/spread) is unchanged — only the brightness drops.
    expect(dim.blurRadius, full.blurRadius);
    expect(dim.spreadRadius, full.spreadRadius);
  });
}
