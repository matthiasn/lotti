import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_repaint.dart';

import '../../../widget_test_utils.dart';

class _PaintProbe extends CustomPainter {
  _PaintProbe(this.record);
  final VoidCallback record;

  @override
  void paint(Canvas canvas, Size size) => record();

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}

void main() {
  testWidgets('frames paint the scene without rebuilding its hosted subtree', (
    tester,
  ) async {
    final frames = ChangeNotifier();
    addTearDown(frames.dispose);
    var builds = 0;
    var paints = 0;
    var taps = 0;
    await tester.pumpWidget(
      makeTestableWidget2(
        PlazaRepaint(
          frames: frames,
          child: Builder(
            builder: (_) {
              builds++;
              return GestureDetector(
                onTap: () => taps++,
                child: CustomPaint(
                  painter: _PaintProbe(() => paints++),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ),
    );
    final initialPaints = paints;
    final initialBuilds = builds;
    frames.notifyListeners();
    await tester.pump();
    expect(paints, initialPaints + 1);
    expect(builds, initialBuilds);
    await tester.tap(find.byType(CustomPaint).last);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
    expect(frames.hasListeners, isFalse);
  });

  testWidgets('replacing the clock detaches the old listener', (tester) async {
    final old = ChangeNotifier();
    final next = ChangeNotifier();
    addTearDown(old.dispose);
    addTearDown(next.dispose);
    Widget host(Listenable clock) => makeTestableWidget2(
      PlazaRepaint(frames: clock, child: const SizedBox.expand()),
    );
    await tester.pumpWidget(host(old));
    expect(old.hasListeners, isTrue);
    await tester.pumpWidget(host(next));
    expect(old.hasListeners, isFalse);
    expect(next.hasListeners, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(next.hasListeners, isFalse);
  });
}
