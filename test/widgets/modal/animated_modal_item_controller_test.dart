import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wires hover and tap controllers with the given durations', (
    tester,
  ) async {
    final controller = AnimatedModalItemController(
      vsync: tester,
      hoverDuration: const Duration(milliseconds: 300),
      tapDuration: const Duration(milliseconds: 120),
    );
    addTearDown(controller.dispose);

    expect(
      controller.hoverAnimationController.duration,
      const Duration(milliseconds: 300),
    );
    expect(
      controller.tapAnimationController.duration,
      const Duration(milliseconds: 120),
    );
    expect(controller.hoverAnimationController.value, 0);
    expect(controller.tapAnimationController.value, 0);
  });

  testWidgets('defaults to 200ms hover and 150ms tap durations', (
    tester,
  ) async {
    final controller = AnimatedModalItemController(vsync: tester);
    addTearDown(controller.dispose);

    expect(
      controller.hoverAnimationController.duration,
      const Duration(milliseconds: 200),
    );
    expect(
      controller.tapAnimationController.duration,
      const Duration(milliseconds: 150),
    );
  });

  testWidgets('startHover/endHover drive the hover controller', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final controller = AnimatedModalItemController(vsync: tester);
    addTearDown(controller.dispose);

    controller.startHover();
    expect(controller.hoverAnimationController.status, AnimationStatus.forward);
    await tester.pumpAndSettle();
    expect(controller.hoverAnimationController.value, 1);
    // The tap controller is untouched by hover.
    expect(controller.tapAnimationController.value, 0);

    controller.endHover();
    expect(controller.hoverAnimationController.status, AnimationStatus.reverse);
    await tester.pumpAndSettle();
    expect(controller.hoverAnimationController.value, 0);
  });

  testWidgets('startTap/endTap drive the tap controller', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final controller = AnimatedModalItemController(vsync: tester);
    addTearDown(controller.dispose);

    controller.startTap();
    expect(controller.tapAnimationController.status, AnimationStatus.forward);
    await tester.pumpAndSettle();
    expect(controller.tapAnimationController.value, 1);
    expect(controller.hoverAnimationController.value, 0);

    controller.endTap();
    expect(controller.tapAnimationController.status, AnimationStatus.reverse);
    await tester.pumpAndSettle();
    expect(controller.tapAnimationController.value, 0);
  });

  testWidgets('dispose releases both animation controllers', (tester) async {
    final controller = AnimatedModalItemController(vsync: tester)..dispose();

    // Using a disposed AnimationController throws — proving both inner
    // controllers were actually disposed.
    expect(controller.startHover, throwsA(isA<AssertionError>()));
    expect(controller.startTap, throwsA(isA<AssertionError>()));
  });
}
