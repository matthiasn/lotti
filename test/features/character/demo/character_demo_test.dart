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

  testWidgets('builds with the default dance trio and neutral expression', (
    tester,
  ) async {
    await tester.pumpWidget(const CharacterDemoApp());
    expect(view(tester).clip.name, 'dance');
    expect(view(tester).expression.name, 'neutral');
    expect(view(tester).walkingPair, isTrue);
    expect(view(tester).ensembleScenes.length, 2);
    expect(view(tester).ensembleExpressions.length, 3);
    expect(
      view(tester).ensembleClips.map((clip) => clip.name),
      ['dance', 'danceBackupLeft', 'danceBackupRight'],
    );
    expect(view(tester).synchronousEnsemble, isTrue);
    expect(view(tester).playbackRate, closeTo(124 / 120, 1e-9));
    expect(view(tester).backdrop, CharacterBackdrop.waterfront);
    expect(find.text('BPM 124'), findsOneWidget);
  });

  testWidgets('selecting a motion chip switches the clip', (tester) async {
    await tester.pumpWidget(const CharacterDemoApp());
    await tester.tap(chip('jump'));
    await tester.pump();
    expect(view(tester).clip.name, 'jump');
    expect(view(tester).backdrop, CharacterBackdrop.none);
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

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(view(tester).clip.name, 'kick');

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(view(tester).clip.name, 'dance');
    expect(view(tester).backdrop, CharacterBackdrop.waterfront);
    expect(view(tester).walkingPair, isTrue);
    expect(view(tester).partnerScene, isNotNull);
    expect(view(tester).ensembleScenes.length, 2);
    expect(view(tester).ensembleExpressions.length, 3);
    expect(
      view(tester).ensembleClips.map((clip) => clip.name),
      ['dance', 'danceBackupLeft', 'danceBackupRight'],
    );
    expect(view(tester).synchronousEnsemble, isTrue);
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

  testWidgets('the BPM slider controls dance playback up to 240', (
    tester,
  ) async {
    await tester.pumpWidget(const CharacterDemoApp());
    final slider = tester.widget<Slider>(find.byType(Slider));

    expect(slider.min, 80);
    expect(slider.max, 240);
    expect(slider.value, 124);

    await tester.drag(find.byType(Slider), const Offset(500, 0));
    await tester.pump();

    expect(view(tester).playbackRate, greaterThan(1));
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
