import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/widgets/viewport_stable_animated_size.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('is a direct pass-through outside the task scroll scope', (
    tester,
  ) async {
    const childKey = Key('pass-through-child');
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Align(
          alignment: Alignment.topLeft,
          child: ViewportStableAnimatedSize(
            key: _animatedSizeKey,
            child: SizedBox(key: childKey, width: 120, height: 80),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(_animatedSizeKey),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
    expect(tester.getSize(find.byKey(childKey)), const Size(120, 80));
  });

  for (final scenario in [
    (
      name: 'grows',
      initialHeight: 50.0,
      finalHeight: 250.0,
      initialOffset: 500.0,
      finalOffset: 700.0,
    ),
    (
      name: 'shrinks',
      initialHeight: 250.0,
      finalHeight: 50.0,
      initialOffset: 700.0,
      finalOffset: 500.0,
    ),
  ]) {
    testWidgets(
      'pins later content before paint while an off-screen region '
      '${scenario.name}',
      (tester) async {
        final paintedMarkerTops = <double>[];
        final key = GlobalKey<_StableSizeHarnessState>();
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            _StableSizeHarness(
              key: key,
              initialHeight: scenario.initialHeight,
              onMarkerPaint: paintedMarkerTops.add,
            ),
          ),
        );
        await tester.pump();

        final state = key.currentState!
          ..controller.jumpTo(scenario.initialOffset);
        await tester.pump();
        final markerTop = tester.getTopLeft(find.byKey(_markerKey)).dy;
        paintedMarkerTops.clear();

        state.setHeight(scenario.finalHeight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        final animatedHeight = tester
            .getSize(find.byKey(_animatedSizeKey))
            .height;
        final lowerHeight = scenario.initialHeight < scenario.finalHeight
            ? scenario.initialHeight
            : scenario.finalHeight;
        final upperHeight = scenario.initialHeight > scenario.finalHeight
            ? scenario.initialHeight
            : scenario.finalHeight;
        expect(
          animatedHeight,
          inExclusiveRange(lowerHeight, upperHeight),
        );
        expect(
          tester.getTopLeft(find.byKey(_markerKey)).dy,
          closeTo(markerTop, 1),
        );
        expect(paintedMarkerTops.last, closeTo(markerTop, 1));

        await tester.pump(const Duration(milliseconds: 180));
        expect(
          tester.getSize(find.byKey(_animatedSizeKey)).height,
          scenario.finalHeight,
        );
        expect(
          tester.getTopLeft(find.byKey(_markerKey)).dy,
          closeTo(markerTop, 1),
        );
        expect(
          state.controller.offset,
          closeTo(scenario.finalOffset, 1),
        );
      },
    );
  }

  testWidgets('keeps scroll offset fixed when the growing region is visible', (
    tester,
  ) async {
    final key = GlobalKey<_StableSizeHarnessState>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(_StableSizeHarness(key: key)),
    );
    await tester.pump();

    final state = key.currentState!..controller.jumpTo(300);
    await tester.pump();
    final offsetBefore = state.controller.offset;
    final topBefore = tester.getTopLeft(find.byKey(_animatedSizeKey)).dy;

    state.setHeight(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(state.controller.offset, offsetBefore);
    expect(
      tester.getTopLeft(find.byKey(_animatedSizeKey)).dy,
      closeTo(topBefore, 0.1),
    );
    expect(
      tester.getSize(find.byKey(_animatedSizeKey)).height,
      inExclusiveRange(50, 250),
    );
  });
}

const _animatedSizeKey = Key('stable-animated-size');
const _markerKey = Key('stable-marker');

class _StableSizeHarness extends StatefulWidget {
  const _StableSizeHarness({
    this.initialHeight = 50,
    this.onMarkerPaint,
    super.key,
  });

  final double initialHeight;
  final ValueChanged<double>? onMarkerPaint;

  @override
  State<_StableSizeHarness> createState() => _StableSizeHarnessState();
}

class _StableSizeHarnessState extends State<_StableSizeHarness> {
  final ScrollController controller = ScrollController();
  late double height;

  @override
  void initState() {
    super.initState();
    height = widget.initialHeight;
  }

  void setHeight(double value) => setState(() => height = value);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: 600,
        child: TaskScrollStabilityScope(
          controller: controller,
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 400),
                ViewportStableAnimatedSize(
                  key: _animatedSizeKey,
                  child: SizedBox(height: height),
                ),
                _PaintPositionRecorder(
                  onPaint: widget.onMarkerPaint,
                  child: const SizedBox(key: _markerKey, height: 40),
                ),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaintPositionRecorder extends SingleChildRenderObjectWidget {
  const _PaintPositionRecorder({
    required this.onPaint,
    required super.child,
  });

  final ValueChanged<double>? onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPaintPositionRecorder(onPaint);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaintPositionRecorder renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderPaintPositionRecorder extends RenderProxyBox {
  _RenderPaintPositionRecorder(this.onPaint);

  ValueChanged<double>? onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint?.call(localToGlobal(Offset.zero).dy);
    super.paint(context, offset);
  }
}
