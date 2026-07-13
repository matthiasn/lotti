import 'package:flutter/material.dart';
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

  testWidgets('pins later content while an off-screen region grows', (
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

    state.setHeight(250);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final animatedHeight = tester.getSize(find.byKey(_animatedSizeKey)).height;
    expect(animatedHeight, inExclusiveRange(50, 250));
    expect(tester.getTopLeft(find.byKey(_markerKey)).dy, closeTo(markerTop, 1));

    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(find.byKey(_animatedSizeKey)).height, 250);
    expect(tester.getTopLeft(find.byKey(_markerKey)).dy, closeTo(markerTop, 1));
    expect(state.controller.offset, closeTo(700, 1));
  });

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
  const _StableSizeHarness({super.key});

  @override
  State<_StableSizeHarness> createState() => _StableSizeHarnessState();
}

class _StableSizeHarnessState extends State<_StableSizeHarness> {
  final ScrollController controller = ScrollController();
  double height = 50;

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
                const SizedBox(key: _markerKey, height: 40),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
