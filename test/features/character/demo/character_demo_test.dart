import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Chips now carry their shortcut in the label ("jump  4"), so match on a
  // substring rather than the bare name.
  Finder chip(String name) => find.descendant(
    of: find.byType(ChoiceChip),
    matching: find.textContaining(name),
  );

  testWidgets('builds with the default walk clip and neutral expression', (
    tester,
  ) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).clip.name, 'walk');
    expect(view(tester).expression.name, 'neutral');
    expect(view(tester).walkingPair, isTrue);
  });

  testWidgets('selecting a motion chip switches the clip', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.tap(chip('jump'));
    await tester.pump();
    expect(view(tester).clip.name, 'jump');
  });

  testWidgets('selecting an expression chip switches the face', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.tap(chip('happy'));
    await tester.pump();
    expect(view(tester).expression.name, 'happy');
  });

  testWidgets('number keys select the action', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.pump(); // let autofocus settle
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(view(tester).clip.name, 'run');
  });

  testWidgets('letter keys select the expression', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(view(tester).expression.name, 'happy');
  });

  testWidgets('the blink button closes the eyelids', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).eyeOpenScale, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Blink'));
    await tester.pump(); // start the blink controller
    await tester.pump(const Duration(milliseconds: 70));
    // Mid-close, the manual blink has driven the eyelids well shut.
    expect(view(tester).eyeOpenScale, lessThan(0.5));
  });

  testWidgets('the pause action freezes the painter clock', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).paused, isFalse);

    // Let the clock advance, then pause.
    await tester.pump(const Duration(milliseconds: 100));
    final beforePause = painter(tester).timeSeconds;
    expect(beforePause, greaterThan(0));

    await tester.tap(find.byTooltip('Pause (Space)'));
    await tester.pump();
    final pausedAt = painter(tester).timeSeconds;

    // Pumping more time must not advance the clock while paused.
    await tester.pump(const Duration(milliseconds: 200));
    expect(view(tester).paused, isTrue);
    expect(painter(tester).timeSeconds, pausedAt);
  });
}
