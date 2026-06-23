import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/character_demo.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_view.dart';

void main() {
  CharacterView view(WidgetTester tester) =>
      tester.widget<CharacterView>(find.byType(CharacterView));

  CharacterPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<CharacterPainter>()
      .first;

  testWidgets('builds with the default walk clip and neutral expression', (
    tester,
  ) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).clip.name, 'walk');
    expect(view(tester).expression.name, 'neutral');
  });

  testWidgets('selecting a motion chip switches the clip', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.tap(find.widgetWithText(ChoiceChip, 'jump'));
    await tester.pump();
    expect(view(tester).clip.name, 'jump');
  });

  testWidgets('selecting an expression chip switches the face', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.tap(find.widgetWithText(ChoiceChip, 'happy'));
    await tester.pump();
    expect(view(tester).expression.name, 'happy');
  });

  testWidgets('the pause action freezes the painter clock', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).paused, isFalse);

    // Let the clock advance, then pause.
    await tester.pump(const Duration(milliseconds: 100));
    final beforePause = painter(tester).timeSeconds;
    expect(beforePause, greaterThan(0));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    final pausedAt = painter(tester).timeSeconds;

    // Pumping more time must not advance the clock while paused.
    await tester.pump(const Duration(milliseconds: 200));
    expect(view(tester).paused, isTrue);
    expect(painter(tester).timeSeconds, pausedAt);
  });
}
