import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/chat/chat_glide_scroll_activity.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late ScrollController controller;
  late StateSetter setHost;
  late double tailHeight;
  late double viewportHeight;
  late ScrollPhysics? physics;

  Future<void> pumpList(WidgetTester tester) async {
    controller = ScrollController();
    addTearDown(controller.dispose);
    tailHeight = 0;
    viewportHeight = 400;
    physics = null;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            setHost = setState;
            // Aligned, so the 400 holds under the test view's tight size.
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: viewportHeight,
                width: 300,
                child: ListView(
                  controller: controller,
                  physics: physics,
                  children: [
                    const SizedBox(height: 1000),
                    SizedBox(height: tailHeight),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ScrollPositionWithSingleContext position() =>
      controller.position as ScrollPositionWithSingleContext;

  ChatGlideScrollActivity glide({double speed = 100}) {
    final activity = ChatGlideScrollActivity(position(), speed: speed);
    position().beginActivity(activity);
    return activity;
  }

  testWidgets('eases in, holds its speed, and settles into the end', (
    tester,
  ) async {
    await pumpList(tester);
    final activity = glide();
    expect(position().isScrollingNotifier.value, isTrue);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // A third of the ramp: about a third of full pace.
    expect(position().pixels, inExclusiveRange(1, 10));

    await tester.pump(const Duration(milliseconds: 400));
    final atPace = position().pixels;
    await tester.pump(const Duration(seconds: 1));
    // A full second at 100 px/s.
    expect(position().pixels - atPace, moreOrLessEquals(100, epsilon: 1));

    await tester.pumpAndSettle();
    expect(position().pixels, position().maxScrollExtent);
    expect(activity.isActive, isFalse);
    expect(position().isScrollingNotifier.value, isFalse);
  });

  testWidgets('follows an end that moves while it glides', (tester) async {
    await pumpList(tester);
    glide(speed: 2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    setHost(() => tailHeight = 800);
    await tester.pumpAndSettle();

    expect(position().maxScrollExtent, 1400);
    expect(position().pixels, 1400);
  });

  testWidgets('not following growth, it holds the end once laid out', (
    tester,
  ) async {
    await pumpList(tester);
    final activity = ChatGlideScrollActivity(
      position(),
      speed: 2000,
      followGrowth: false,
    );
    position().beginActivity(activity);
    await tester.pump();
    // Within the cache extent of the end: the end is laid out and held.
    while (position().extentAfter > 250) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 16));

    setHost(() => tailHeight = 800);
    await tester.pumpAndSettle();

    expect(position().pixels, 600);
    expect(position().extentAfter, 800);
    expect(activity.destination, 600);
  });

  testWidgets('keeps driving the position the list swaps in mid-glide', (
    tester,
  ) async {
    await pumpList(tester);
    glide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final before = position();

    // Physics of another kind make the scrollable replace its position and
    // hand the running activity over, as a device pixel ratio change does.
    setHost(() => physics = const BouncingScrollPhysics());
    await tester.pump();
    expect(position(), isNot(same(before)));

    await tester.pumpAndSettle();
    expect(position().pixels, position().maxScrollExtent);
  });

  testWidgets('is brought back in range when the viewport outgrows the '
      'end mid-glide', (tester) async {
    await pumpList(tester);
    glide(speed: 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(position().pixels, greaterThan(440));

    setHost(() => viewportHeight = 580);
    await tester.pumpAndSettle();

    expect(position().maxScrollExtent, 420);
    expect(position().pixels, 420);
  });

  testWidgets('is replaced by the reader taking hold of the list', (
    tester,
  ) async {
    await pumpList(tester);
    final activity = glide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final gesture = await tester.startGesture(const Offset(10, 200));
    await tester.pump();
    final held = position().pixels;
    await tester.pump(const Duration(seconds: 2));

    expect(activity.isActive, isFalse);
    expect(position().pixels, held);
    await gesture.up();
  });

  testWidgets('leaves the content under it tappable', (tester) async {
    await pumpList(tester);
    glide();
    await tester.pump();

    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(
              of: find.byType(Scrollable),
              matching: find.byType(IgnorePointer),
            ),
          )
          .ignoring,
      isFalse,
    );
    await tester.pumpAndSettle();
  });
}
