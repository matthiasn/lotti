import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/supersampled_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';

import '../../../widget_test_utils.dart';

Widget _host(Widget view) => makeTestableWidgetNoScroll(
  Center(child: SizedBox(width: 200, height: 300, child: view)),
);

SupersampledPainter _outer(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(CompanionView),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as SupersampledPainter;

CompanionPainter _painter(WidgetTester tester) =>
    _outer(tester).inner as CompanionPainter;

CompanionPose _pose(WidgetTester tester) => _painter(tester).pose;

/// Pumps [seconds] of frames at 60 fps, collecting the pose of each.
Future<List<CompanionPose>> _frames(WidgetTester tester, double seconds) async {
  final out = <CompanionPose>[];
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await tester.pump(const Duration(microseconds: 16667));
    out.add(_pose(tester));
  }
  return out;
}

void main() {
  testWidgets('she is alive: the pose changes frame to frame', (tester) async {
    await tester.pumpWidget(_host(const CompanionView()));
    final poses = await _frames(tester, 3);
    expect(poses.map((p) => p.breath).toSet().length, greaterThan(100));
    expect(poses.any((p) => p.blink > 0.95), isTrue);
    expect(poses.every((p) => p.mouth.open == 0), isTrue);
  });

  testWidgets('paints in the look and framing it is given', (tester) async {
    await tester.pumpWidget(
      _host(
        const CompanionView(
          look: CompanionLook.grandmaRock,
          framing: CompanionFraming.bust,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_painter(tester).look, CompanionLook.grandmaRock);
    expect(_painter(tester).framing, CompanionFraming.bust);
  });

  testWidgets('talks while the playhead is inside the track', (tester) async {
    final track = TextLipSync('Four things today, the big one at ten.');
    Duration? position;
    await tester.pumpWidget(
      _host(
        CompanionView(
          track: track,
          playhead: () => position,
          autoGestures: false,
        ),
      ),
    );
    await _frames(tester, 0.2);
    expect(_pose(tester).mouth.open, 0);

    final talking = <double>[];
    for (var i = 0; i < 60; i++) {
      position = Duration(milliseconds: i * 16);
      await tester.pump(const Duration(milliseconds: 16));
      talking.add(_pose(tester).mouth.open);
    }
    expect(talking.reduce((a, b) => a > b ? a : b), greaterThan(5));

    position = null;
    await tester.pump(const Duration(milliseconds: 16));
    expect(_pose(tester).mouth.open, 0);
  });

  testWidgets('the controller cues a gesture and lets go when disposed', (
    tester,
  ) async {
    final controller = CompanionController();
    expect(controller.isAttached, isFalse);
    controller.play(GestureName.wave); // Ignored while detached.

    expect(controller.time, 0);
    await tester.pumpWidget(_host(CompanionView(controller: controller)));
    expect(controller.isAttached, isTrue);
    controller.play(GestureName.wave);
    final poses = await _frames(tester, 1);
    expect(poses.last.right.wrist.dy, lessThan(-130));
    expect(controller.time, closeTo(1, 0.02));

    await tester.pumpWidget(_host(const SizedBox()));
    expect(controller.isAttached, isFalse);
  });

  testWidgets('a manual blink shuts her eyes', (tester) async {
    final controller = CompanionController();
    await tester.pumpWidget(_host(CompanionView(controller: controller)));
    await _frames(tester, 0.3);
    controller.blink();
    final poses = await _frames(tester, 0.15);
    expect(poses.any((p) => p.blink > 0.95), isTrue);
  });

  testWidgets('a new controller takes over from the old one', (tester) async {
    final first = CompanionController();
    final second = CompanionController();
    await tester.pumpWidget(_host(CompanionView(controller: first)));
    await tester.pumpWidget(_host(CompanionView(controller: second)));
    expect(first.isAttached, isFalse);
    expect(second.isAttached, isTrue);
  });

  testWidgets('a long stall moves her one short step, not a jump', (
    tester,
  ) async {
    final controller = CompanionController();
    await tester.pumpWidget(_host(CompanionView(controller: controller)));
    await _frames(tester, 0.5);
    controller.play(GestureName.celebrate);
    final before = _pose(tester).right.wrist;
    await tester.pump(const Duration(seconds: 5));
    final after = _pose(tester).right.wrist;
    // Five seconds of springs would land the hand overhead; one capped
    // step (1/20 s) barely starts it.
    expect((after - before).distance, lessThan(40));
  });
}
