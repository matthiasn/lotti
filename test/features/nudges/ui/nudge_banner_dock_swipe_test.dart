import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock_swipe.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<String> pages;
  late int pageScrolls;

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    pages = [];
    pageScrolls = 0;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        // A vertical scrollable behind the swipe surface: what the dock sits
        // over on a real page, and what must keep its vertical scroll.
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (_) {
            pageScrolls++;
            return false;
          },
          child: ListView(
            children: [
              NudgeBannerDockSwipe(
                enabled: enabled,
                onNext: () => pages.add('next'),
                onPrevious: () => pages.add('previous'),
                child: const SizedBox(
                  key: ValueKey('surface'),
                  height: 120,
                  width: 400,
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
  }

  Offset surface(WidgetTester tester) =>
      tester.getCenter(find.byKey(const ValueKey('surface')));

  Future<void> scroll(
    WidgetTester tester,
    Offset delta, {
    required Duration at,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: at,
        position: surface(tester),
        scrollDelta: delta,
        kind: PointerDeviceKind.trackpad,
      ),
    );
    await tester.pump();
  }

  group('a drag', () {
    testWidgets('a finger swiped left shows the next banner, right the '
        'previous — the content follows the finger', (tester) async {
      await pump(tester);
      await tester.dragFrom(surface(tester), const Offset(-120, 0));
      await tester.dragFrom(surface(tester), const Offset(120, 0));
      expect(pages, ['next', 'previous']);
    });

    testWidgets('a short, slow drift pages nothing: a tap that wanders is '
        'not a swipe', (tester) async {
      await pump(tester);
      final gesture = await tester.startGesture(surface(tester));
      // Past the touch slop, so the drag is recognised, but under the
      // swipe distance, in steps slow enough to stay below a fling.
      // About 40 px/s, a hair under the 50 px/s fling floor.
      for (var i = 1; i <= 6; i++) {
        await gesture.moveBy(
          const Offset(-6, 0),
          timeStamp: Duration(milliseconds: 150 * i),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 901));
      expect(pages, isEmpty);
    });

    testWidgets('a quick flick pages even when it is short', (tester) async {
      await pump(tester);
      // 40 px — under the swipe distance — at about 2000 px/s.
      final gesture = await tester.startGesture(surface(tester));
      for (var i = 1; i <= 5; i++) {
        await gesture.moveBy(
          const Offset(-8, 0),
          timeStamp: Duration(milliseconds: 4 * i),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 21));
      expect(pages, ['next']);
    });

    testWidgets('two fingers on a trackpad page the same way a finger does', (
      tester,
    ) async {
      await pump(tester);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      await gesture.panZoomStart(surface(tester));
      for (var i = 1; i <= 8; i++) {
        await gesture.panZoomUpdate(
          surface(tester),
          pan: Offset(-15.0 * i, 0),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.panZoomEnd();
      await tester.pump();
      expect(pages, ['next']);
    });

    testWidgets('a mouse drag pages nothing — pressing the dock is a tap', (
      tester,
    ) async {
      await pump(tester);
      await tester.dragFrom(
        surface(tester),
        const Offset(-200, 0),
        kind: PointerDeviceKind.mouse,
      );
      expect(pages, isEmpty);
    });
  });

  group('horizontal scroll signals', () {
    testWidgets('one burst pages once, however long its momentum runs, and '
        'a pause starts the next swipe', (tester) async {
      await pump(tester);
      // Scrolling right is a leftward swipe: the next banner.
      for (var ms = 0; ms <= 200; ms += 20) {
        await scroll(
          tester,
          const Offset(30, 0),
          at: Duration(milliseconds: ms),
        );
      }
      expect(pages, ['next']);

      final later = const Duration(milliseconds: 200) + nudgeBannerDockSwipeGap;
      await scroll(tester, const Offset(-30, 0), at: later);
      await scroll(
        tester,
        const Offset(-30, 0),
        at: later + const Duration(milliseconds: 20),
      );
      expect(pages, ['next', 'previous']);
    });

    testWidgets('a mostly vertical scroll is left to the page behind', (
      tester,
    ) async {
      await pump(tester);
      await scroll(tester, const Offset(20, 80), at: Duration.zero);
      expect(pages, isEmpty);
      expect(pageScrolls, greaterThan(0));
    });

    testWidgets('a horizontal scroll is claimed: the page does not move', (
      tester,
    ) async {
      await pump(tester);
      await scroll(tester, const Offset(80, 10), at: Duration.zero);
      expect(pages, ['next']);
      expect(pageScrolls, 0);
    });
  });

  testWidgets('disabled — a lone banner — leaves every gesture alone', (
    tester,
  ) async {
    await pump(tester, enabled: false);
    await tester.dragFrom(surface(tester), const Offset(-120, 0));
    await scroll(tester, const Offset(80, 0), at: Duration.zero);
    expect(pages, isEmpty);
  });

  testWidgets('switching paging on keeps the child mounted: a second banner '
      'arriving must not remount the tenant it wraps', (tester) async {
    late StateSetter setEnabled;
    var enabled = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) {
            setEnabled = setState;
            return NudgeBannerDockSwipe(
              enabled: enabled,
              onNext: () {},
              onPrevious: () {},
              child: const SizedBox(key: ValueKey('surface'), height: 120),
            );
          },
        ),
      ),
    );
    final before = tester.element(find.byKey(const ValueKey('surface')));

    setEnabled(() => enabled = true);
    await tester.pump();

    expect(tester.element(find.byKey(const ValueKey('surface'))), same(before));
  });
}
