import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/widgets/viewport_stable_animated_size.dart';

import '../../../../widget_test_utils.dart';

void main() {
  test('task scroll scope notifies dependants only for a new controller', () {
    final firstController = ScrollController();
    final secondController = ScrollController();
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    final oldScope = TaskScrollStabilityScope(
      controller: firstController,
      child: const SizedBox.shrink(),
    );

    expect(
      TaskScrollStabilityScope(
        controller: firstController,
        child: const SizedBox.shrink(),
      ).updateShouldNotify(oldScope),
      isFalse,
    );
    expect(
      TaskScrollStabilityScope(
        controller: secondController,
        child: const SizedBox.shrink(),
      ).updateShouldNotify(oldScope),
      isTrue,
    );
  });

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
      '${scenario.name} from a descendant-only rebuild',
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

        state.resizeDescendant(scenario.finalHeight);
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

  testWidgets('also stabilizes a parent-driven wrapper update', (
    tester,
  ) async {
    final key = GlobalKey<_StableSizeHarnessState>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(_StableSizeHarness(key: key)),
    );
    await tester.pump();

    final state = key.currentState!..controller.jumpTo(500);
    await tester.pump();
    final markerTop = tester.getTopLeft(find.byKey(_markerKey)).dy;

    state.rebuildWithHeight(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(state.controller.offset, closeTo(700, 1));
    expect(tester.getTopLeft(find.byKey(_markerKey)).dy, closeTo(markerTop, 1));
  });

  testWidgets(
    'ignores an unrelated extent shrink below the anchored content',
    (tester) async {
      final paintedMarkerTops = <double>[];
      final key = GlobalKey<_StableSizeHarnessState>();
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          _StableSizeHarness(key: key, onMarkerPaint: paintedMarkerTops.add),
        ),
      );
      await tester.pump();

      final state = key.currentState!..controller.jumpTo(500);
      await tester.pump();
      final markerTop = tester.getTopLeft(find.byKey(_markerKey)).dy;
      final maxExtentBefore = state.controller.position.maxScrollExtent;
      paintedMarkerTops.clear();

      state.resizeDescendantAndTail(
        descendantHeight: 250,
        tailHeight: 1580,
      );
      await tester.pump();
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.getTopLeft(find.byKey(_markerKey)).dy,
          closeTo(markerTop, 1),
          reason: 'visible content moved during animation frame $frame',
        );
      }

      expect(paintedMarkerTops, isNotEmpty);
      expect(
        paintedMarkerTops.every((top) => (top - markerTop).abs() <= 1),
        isTrue,
      );
      expect(state.controller.offset, closeTo(700, 1));
      expect(
        state.controller.position.maxScrollExtent - maxExtentBefore,
        closeTo(180, 1),
      );
    },
  );

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

    state.resizeDescendant(250);
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

  testWidgets('does not fight an active user scroll', (tester) async {
    final key = GlobalKey<_StableSizeHarnessState>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(_StableSizeHarness(key: key)),
    );
    await tester.pump();

    final state = key.currentState!..controller.jumpTo(500);
    await tester.pump();
    state.controller.position.isScrollingNotifier.value = true;
    final offsetDuringDrag = state.controller.offset;
    final markerTopBeforeResize = tester.getTopLeft(find.byKey(_markerKey)).dy;

    state.resizeDescendant(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(state.controller.offset, offsetDuringDrag);
    expect(
      tester.getTopLeft(find.byKey(_markerKey)).dy,
      greaterThan(markerTopBeforeResize),
    );
    state.controller.position.isScrollingNotifier.value = false;
  });

  testWidgets('holds visible content while growing at the bottom extent', (
    tester,
  ) async {
    final paintedMarkerTops = <double>[];
    final key = GlobalKey<_StableSizeHarnessState>();
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        _StableSizeHarness(
          key: key,
          markerSpacer: 1200,
          onMarkerPaint: paintedMarkerTops.add,
        ),
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    state.controller.jumpTo(state.controller.position.maxScrollExtent);
    await tester.pump();
    final markerTop = tester.getTopLeft(find.byKey(_markerKey)).dy;
    paintedMarkerTops.clear();

    state.resizeDescendant(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.getTopLeft(find.byKey(_markerKey)).dy, closeTo(markerTop, 1));
    expect(paintedMarkerTops.last, closeTo(markerTop, 1));

    await tester.pump(const Duration(milliseconds: 180));
    expect(
      state.controller.offset,
      closeTo(state.controller.position.maxScrollExtent, 1),
    );
    expect(tester.getTopLeft(find.byKey(_markerKey)).dy, closeTo(markerTop, 1));
  });
}

const _animatedSizeKey = Key('stable-animated-size');
const _markerKey = Key('stable-marker');

class _StableSizeHarness extends StatefulWidget {
  const _StableSizeHarness({
    this.initialHeight = 50,
    this.markerSpacer = 0,
    this.onMarkerPaint,
    super.key,
  });

  final double initialHeight;
  final double markerSpacer;
  final ValueChanged<double>? onMarkerPaint;

  @override
  State<_StableSizeHarness> createState() => _StableSizeHarnessState();
}

class _StableSizeHarnessState extends State<_StableSizeHarness> {
  final ViewportStableScrollController controller =
      ViewportStableScrollController();
  late final ValueNotifier<double> height;
  late final ValueNotifier<double> tailHeight;

  @override
  void initState() {
    super.initState();
    height = ValueNotifier(widget.initialHeight);
    tailHeight = ValueNotifier(1600 - widget.markerSpacer);
  }

  // ignore: use_setters_to_change_properties
  void resizeDescendant(double value) => height.value = value;

  void resizeDescendantAndTail({
    required double descendantHeight,
    required double tailHeight,
  }) {
    height.value = descendantHeight;
    this.tailHeight.value = tailHeight;
  }

  void rebuildWithHeight(double value) {
    height.value = value;
    setState(() {});
  }

  @override
  void dispose() {
    height.dispose();
    tailHeight.dispose();
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
                  child: ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (context, value, child) {
                      return SizedBox(height: value);
                    },
                  ),
                ),
                SizedBox(height: widget.markerSpacer),
                PaintPositionRecorder(
                  onPaint: widget.onMarkerPaint,
                  child: const SizedBox(key: _markerKey, height: 40),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: tailHeight,
                  builder: (context, value, child) => SizedBox(height: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
