import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_origin_scroll_anchor.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  const route = '/tasks/task-1';
  late RecordingOriginScroll scroll;
  late ScrollController controller;

  setUp(() {
    scroll = RecordingOriginScroll();
    controller = ScrollController();
  });
  tearDown(() {
    controller.dispose();
    scroll.dispose();
  });

  /// A page 3000 tall in an 800 viewport: it scrolls to 2200 at most.
  Widget page({String route = route, ScrollController? using}) =>
      RecordingOriginScrollAnchor(
        route: route,
        controller: using ?? controller,
        child: ListView(
          controller: using ?? controller,
          children: const [SizedBox(height: 3000)],
        ),
      );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        SizedBox(height: 800, child: child),
        mediaQueryData: const MediaQueryData(size: Size(400, 800)),
        overrides: [recordingOriginScrollProvider.overrideWithValue(scroll)],
      ),
    );
    await tester.pump();
  }

  testWidgets('reports the offset as the page scrolls', (tester) async {
    await pump(tester, page());
    controller.jumpTo(420);
    await tester.pump();
    expect(scroll.offsetFor(route), 420);
  });

  testWidgets('a page built anew restores the offset owed to it on its '
      'first frame, once', (tester) async {
    scroll.requestRestore(route, 640);
    await pump(tester, page());

    expect(controller.offset, 640);
    expect(scroll.takeRestore(route), isNull);
  });

  testWidgets('a page still mounted restores as soon as it is asked', (
    tester,
  ) async {
    await pump(tester, page());
    controller.jumpTo(100);

    scroll.requestRestore(route, 900);
    await tester.pump();
    expect(controller.offset, 900);
  });

  testWidgets('the offset is clamped to what the page can scroll to now', (
    tester,
  ) async {
    scroll.requestRestore(route, 99999);
    await pump(tester, page());
    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets("another route's restore is left alone, still owed", (
    tester,
  ) async {
    scroll.requestRestore('/tasks/task-2', 500);
    await pump(tester, page());

    expect(controller.offset, 0);
    expect(scroll.takeRestore('/tasks/task-2'), 500);
  });

  testWidgets('going away forgets its offset and stops listening', (
    tester,
  ) async {
    await pump(tester, page());
    controller.jumpTo(300);
    await tester.pump();

    await pump(tester, const SizedBox.shrink());
    expect(scroll.offsetFor(route), isNull);
    // A request after it is gone is left for whoever stands there next.
    scroll.requestRestore(route, 50);
    expect(scroll.takeRestore(route), 50);
  });

  testWidgets('a new route forgets the old one; a new controller is the '
      'one reported', (tester) async {
    await pump(tester, page());
    controller.jumpTo(200);
    await tester.pump();

    final other = ScrollController();
    addTearDown(other.dispose);
    await pump(tester, page(route: '/tasks/task-9', using: other));
    expect(scroll.offsetFor(route), isNull);

    other.jumpTo(120);
    await tester.pump();
    expect(scroll.offsetFor('/tasks/task-9'), 120);
  });

  testWidgets('with nothing attached there is nothing to report or restore', (
    tester,
  ) async {
    final detached = ScrollController();
    addTearDown(detached.dispose);
    await pump(
      tester,
      RecordingOriginScrollAnchor(
        route: route,
        controller: detached,
        child: const SizedBox.shrink(),
      ),
    );
    scroll.requestRestore(route, 300);
    await tester.pump();
    // Nothing took it: it is still owed.
    expect(scroll.takeRestore(route), 300);
    expect(scroll.offsetFor(route), isNull);
  });
}
