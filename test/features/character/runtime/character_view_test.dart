import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/runtime/character_painter.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/runtime/character_view.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  CharacterPainter readPainter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<CharacterPainter>()
      .first;

  Widget host({required bool paused, Clip? clip}) => Center(
    child: SizedBox(
      width: 200,
      height: 280,
      child: CharacterView(
        scene: CharacterScene(buildCatInSuitRig()),
        clip: clip ?? CatClips.walk,
        paused: paused,
      ),
    ),
  );

  testWidgets('advances the painter clock while ticking', (tester) async {
    await tester.pumpWidget(host(paused: false));
    expect(readPainter(tester).timeSeconds, 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(readPainter(tester).timeSeconds, greaterThan(0.15));
  });

  testWidgets('stays frozen when paused', (tester) async {
    await tester.pumpWidget(host(paused: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(readPainter(tester).timeSeconds, 0);
  });

  testWidgets('resumes when paused flips to false', (tester) async {
    await tester.pumpWidget(host(paused: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(readPainter(tester).timeSeconds, 0);

    await tester.pumpWidget(host(paused: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(readPainter(tester).timeSeconds, greaterThan(0));
  });

  testWidgets('resumes in place rather than replaying from the start', (
    tester,
  ) async {
    await tester.pumpWidget(host(paused: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final beforePause = readPainter(tester).timeSeconds;
    expect(beforePause, greaterThan(0));

    // Pause: the clock must hold, not reset to zero.
    await tester.pumpWidget(host(paused: true));
    await tester.pump(const Duration(milliseconds: 200));
    final whilePaused = readPainter(tester).timeSeconds;
    expect(whilePaused, closeTo(beforePause, 1e-9));

    // Resume: the clock must continue forward from where it paused.
    await tester.pumpWidget(host(paused: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(readPainter(tester).timeSeconds, greaterThan(beforePause));
  });

  testWidgets('resets the clock to zero when the clip changes', (tester) async {
    await tester.pumpWidget(host(paused: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(readPainter(tester).timeSeconds, greaterThan(0));

    // Swapping the clip on the same view must restart playback at t=0 so a
    // one-shot doesn't begin partway through.
    await tester.pumpWidget(host(paused: false, clip: CatClips.jump));
    expect(readPainter(tester).timeSeconds, 0);
  });
}
