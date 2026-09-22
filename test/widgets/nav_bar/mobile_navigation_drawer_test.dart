import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_drawer.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

const _pageButtonKey = Key('page-button');
const _drawerContentKey = Key('drawer-content');

/// Past the slide's duration: a controller reports `completed` only once the
/// elapsed time *exceeds* it (see test/README.md).
final Duration _pastSlide =
    MotionDurations.medium2 + const Duration(milliseconds: 50);

/// A page with state of its own, so a test can tell "kept" from "rebuilt".
class _CountingPage extends StatefulWidget {
  const _CountingPage();

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: _pageButtonKey,
      onPressed: () => setState(() => taps++),
      child: Text('page taps: $taps'),
    ),
  );
}

class _Bench {
  final controller = MobileNavigationDrawerController();
  int drawerBuilds = 0;

  Widget host({MobileNavigationDrawerController? controller}) =>
      MobileNavigationDrawerHost(
        controller: controller ?? this.controller,
        drawerBuilder: (context) {
          drawerBuilds++;
          return const SizedBox.expand(
            key: _drawerContentKey,
            child: Text('drawer'),
          );
        },
        child: const _CountingPage(),
      );

  Future<void> pump(
    WidgetTester tester, {
    MediaQueryData mediaQueryData = phoneMediaQueryData,
    MobileNavigationDrawerController? controller,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        host(controller: controller),
        mediaQueryData: mediaQueryData,
      ),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    controller.open();
    await tester.pump();
    await tester.pump(_pastSlide);
  }
}

Rect _panel(WidgetTester tester) =>
    tester.getRect(find.byKey(MobileNavigationDrawerKeys.panel));

double _pageOffset(WidgetTester tester) =>
    tester.getTopLeft(find.byType(_CountingPage)).dx;

double _width(WidgetTester tester) => MobileNavigationDrawerHost.drawerWidth(
  tester.element(find.byType(MobileNavigationDrawerHost)),
);

/// A point on the strip of page the open drawer leaves showing.
Offset _peek(WidgetTester tester) {
  final host = tester.getRect(find.byType(MobileNavigationDrawerHost));
  return Offset((_width(tester) + host.right) / 2, host.center.dy);
}

void main() {
  group('MobileNavigationDrawerController', () {
    test('starts closed and reports open and close to its listeners', () {
      final controller = MobileNavigationDrawerController();
      final seen = <bool>[];
      controller.addListener(() => seen.add(controller.isOpen));

      expect(controller.isOpen, isFalse);
      controller
        ..open()
        ..open()
        ..close();

      expect(seen, [true, false]);
    });
  });

  group('MobileNavigationDrawerHost.drawerWidth', () {
    Future<double> widthAt(WidgetTester tester, double windowWidth) async {
      await _Bench().pump(
        tester,
        mediaQueryData: MediaQueryData(size: Size(windowWidth, 844)),
      );
      return _width(tester);
    }

    testWidgets('is the window less the strip of page left showing', (
      tester,
    ) async {
      final width = await widthAt(tester, 390);
      final tokens = tester
          .element(find.byType(MobileNavigationDrawerHost))
          .designTokens;

      expect(width, 390 - tokens.spacing.step11);
    });

    testWidgets("never drops below the sidebar's minimum", (tester) async {
      expect(await widthAt(tester, 240), minSidebarWidth);
    });

    testWidgets("never exceeds the sidebar's maximum", (tester) async {
      expect(await widthAt(tester, 900), maxSidebarWidth);
    });
  });

  group('MobileNavigationDrawerHost closed', () {
    testWidgets('leaves the page in place, alone and interactive', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);

      expect(_pageOffset(tester), 0);
      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
      expect(find.byKey(MobileNavigationDrawerKeys.scrim), findsNothing);
      expect(bench.drawerBuilds, 0);

      await tester.tap(find.byKey(_pageButtonKey));
      await tester.pump();
      expect(find.text('page taps: 1'), findsOneWidget);
    });

    testWidgets('starts open when its controller already is', (tester) async {
      final bench = _Bench()..controller.open();
      await bench.pump(tester);

      expect(_panel(tester).left, 0);
      expect(_pageOffset(tester), _width(tester));
    });
  });

  group('MobileNavigationDrawerHost opening', () {
    testWidgets('slides the panel in and pushes the page aside by its width', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      final width = _width(tester);

      bench.controller.open();
      await tester.pump();
      await tester.pump(MotionDurations.medium2 ~/ 4);

      // Mid-slide the panel and the page travel together: the page's leading
      // edge is always the panel's trailing edge.
      final midPanel = _panel(tester);
      expect(midPanel.left, inExclusiveRange(-width, 0));
      expect(_pageOffset(tester), moreOrLessEquals(midPanel.right));

      await tester.pump(_pastSlide);

      expect(_panel(tester), Rect.fromLTWH(0, 0, width, 844));
      expect(_pageOffset(tester), width);
      expect(find.byKey(_drawerContentKey), findsOneWidget);
    });

    testWidgets('dims the page with the shared modal scrim, in step with the '
        'slide', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);

      Color scrimColor() => tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byKey(MobileNavigationDrawerKeys.scrim),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;

      bench.controller.open();
      await tester.pump();
      await tester.pump(MotionDurations.medium2 ~/ 4);
      final midAlpha = scrimColor().a;

      await tester.pump(_pastSlide);
      final context = tester.element(find.byType(MobileNavigationDrawerHost));
      final full = ModalUtils.getModalBarrierColor(
        isDark: Theme.of(context).brightness == Brightness.dark,
        context: context,
      );

      expect(scrimColor(), full);
      expect(midAlpha, inExclusiveRange(0, full.a));
    });

    testWidgets('rounds the leading corners of the page in step with the '
        'slide, and leaves them square at rest', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      ClipRRect clip() => tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(MobileNavigationDrawerKeys.page),
          matching: find.byType(ClipRRect),
        ),
      );
      final full = tester
          .element(find.byType(MobileNavigationDrawerHost))
          .designTokens
          .radii
          .xl;

      // At rest nothing is clipped at all: the page is the whole screen.
      expect(clip().clipBehavior, Clip.none);

      bench.controller.open();
      await tester.pump();
      await tester.pump(MotionDurations.medium2 ~/ 4);
      final mid = (clip().borderRadius as BorderRadius).topLeft.x;
      expect(mid, inExclusiveRange(0, full));

      await tester.pump(_pastSlide);
      final radius = clip().borderRadius as BorderRadius;
      expect(clip().clipBehavior, Clip.antiAlias);
      expect(radius.topLeft, Radius.circular(full));
      expect(radius.bottomLeft, Radius.circular(full));
      // Only the edge that left the screen's side is rounded.
      expect(radius.topRight, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
    });

    testWidgets("slides the page across the panel's own surface, so the "
        'rounded corner reveals more sidebar', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      final tokens = tester
          .element(find.byType(MobileNavigationDrawerHost))
          .designTokens;
      Finder backdrop() => find.descendant(
        of: find.byType(MobileNavigationDrawerHost),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == tokens.colors.background.level02,
        ),
      );

      expect(backdrop(), findsNothing);

      await bench.open(tester);

      expect(backdrop(), findsOneWidget);
      expect(
        tester.getRect(backdrop()),
        tester.getRect(find.byType(MobileNavigationDrawerHost)),
      );
    });

    testWidgets('gives the panel a Material surface, so plain text inside it '
        'inherits a real text style', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);

      final surface = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(_drawerContentKey),
              matching: find.byType(Material),
            )
            .first,
      );
      final tokens = tester
          .element(find.byType(MobileNavigationDrawerHost))
          .designTokens;
      expect(surface.color, tokens.colors.background.level02);
      // Without a Material ancestor Flutter marks text with a yellow double
      // underline; the panel sits outside the page's Scaffold.
      final style = DefaultTextStyle.of(tester.element(find.text('drawer')));
      expect(style.style.decoration, isNot(TextDecoration.underline));
    });

    testWidgets('keeps the content clear of the status bar and home '
        'indicator while the surface runs edge to edge', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);

      final content = tester.getRect(find.byKey(_drawerContentKey));
      expect(_panel(tester).top, 0);
      expect(_panel(tester).bottom, 844);
      expect(content.top, phoneMediaQueryData.padding.top);
      expect(content.bottom, 844 - phoneMediaQueryData.padding.bottom);
    });

    testWidgets('jumps straight open when animations are disabled', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(
        tester,
        mediaQueryData: phoneMediaQueryData.copyWith(disableAnimations: true),
      );

      bench.controller.open();
      await tester.pump();

      // One zero-length frame and it is fully in: with animations enabled
      // the same pump leaves the panel at the start of its slide.
      expect(_panel(tester).left, 0);
      expect(_pageOffset(tester), _width(tester));
    });
  });

  group('MobileNavigationDrawerHost while open', () {
    testWidgets('makes the page inert without rebuilding it', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      await tester.tap(find.byKey(_pageButtonKey));
      await tester.pump();
      final stateBefore = tester.state(find.byType(_CountingPage));

      await bench.open(tester);
      await tester.tapAt(tester.getCenter(find.byKey(_pageButtonKey)));
      await tester.pump();

      // Same State object, same count: the tap went to the scrim, and the
      // page was moved rather than re-inflated.
      expect(tester.state(find.byType(_CountingPage)), same(stateBefore));
      expect(find.text('page taps: 1'), findsOneWidget);
    });

    testWidgets('takes keyboard focus away from the page', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final controller = MobileNavigationDrawerController();
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          MobileNavigationDrawerHost(
            controller: controller,
            drawerBuilder: (_) => const SizedBox.expand(),
            child: Material(
              child: Center(child: TextField(focusNode: focusNode)),
            ),
          ),
          mediaQueryData: phoneMediaQueryData,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      controller.open();
      await tester.pump();
      await tester.pump(_pastSlide);

      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('hides the page from assistive tech and names the way out', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        // Read from the accessibility traversal, not `bySemanticsLabel`:
        // that finder answers from each render object's cached node, which
        // outlives the subtree being excluded.
        Iterable<String> spoken() => tester.semantics
            .simulatedAccessibilityTraversal()
            .map((node) => node.label);

        final bench = _Bench();
        await bench.pump(tester);
        expect(spoken(), contains('page taps: 0'));

        await bench.open(tester);

        expect(spoken(), isNot(contains('page taps: 0')));
        expect(spoken(), containsAll(['drawer', 'Close navigation']));
      } finally {
        handle.dispose();
      }
    });
  });

  group('MobileNavigationDrawerHost closing', () {
    testWidgets('a tap on the strip of page left showing closes it', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);

      await tester.tapAt(_peek(tester));
      await tester.pump();
      expect(bench.controller.isOpen, isFalse);

      await tester.pump(_pastSlide);
      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
      expect(_pageOffset(tester), 0);
    });

    // Slow releases: no fling, so the half the panel was left in decides.
    for (final (dragFraction, staysOpen) in [(0.3, true), (0.7, false)]) {
      testWidgets('a slow drag across ${(dragFraction * 100).round()}% of the '
          'panel ${staysOpen ? 'springs back open' : 'closes it'}', (
        tester,
      ) async {
        final bench = _Bench();
        await bench.pump(tester);
        await bench.open(tester);
        final width = _width(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_drawerContentKey)),
        );
        // One move: on accepting the drag the recognizer reports the whole
        // offset travelled so far, so the panel tracks the finger exactly.
        await gesture.moveBy(Offset(-width * dragFraction, 0));
        await tester.pump();
        expect(_panel(tester).left, moreOrLessEquals(-width * dragFraction));

        await gesture.up();
        await tester.pump();
        await tester.pump(_pastSlide);

        expect(bench.controller.isOpen, staysOpen);
        expect(
          find.byKey(MobileNavigationDrawerKeys.panel),
          staysOpen ? findsOneWidget : findsNothing,
        );
        if (staysOpen) expect(_panel(tester).left, 0);
      });
    }

    testWidgets('a drag that starts on the dimmed page moves the panel too', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);
      final width = _width(tester);

      // The strip of page left showing is the natural place to grab: the
      // scrim there drives the same slide as the panel itself. Unlike the
      // panel, the scrim also listens for taps, so its drag wins the gesture
      // arena only once the finger has left the touch slop — and that first
      // stretch is not replayed. Spend it, then measure.
      final gesture = await tester.startGesture(_peek(tester));
      await gesture.moveBy(const Offset(-kTouchSlop - 2, 0));
      await tester.pump();
      expect(_panel(tester).left, 0);
      await gesture.moveBy(Offset(-width * 0.7, 0));
      await tester.pump();
      expect(_panel(tester).left, moreOrLessEquals(-width * 0.7));

      await gesture.up();
      await tester.pump();
      await tester.pump(_pastSlide);

      expect(bench.controller.isOpen, isFalse);
      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
    });

    testWidgets('a drag that carries the panel all the way shut closes it, '
        'and the menu opens it again', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);
      final width = _width(tester);

      // Grabbed on the strip of page and pulled past the screen's edge: the
      // panel reaches the closed position under the finger, and its gesture
      // detector leaves with it, so no drag end ever arrives.
      final gesture = await tester.startGesture(_peek(tester));
      await gesture.moveBy(const Offset(-kTouchSlop - 2, 0));
      await tester.pump();
      await gesture.moveBy(Offset(-width - 40, 0));
      await tester.pump();

      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
      expect(bench.controller.isOpen, isFalse);
      await gesture.up();
      await tester.pump();

      // Had the controller kept saying "open", this would change nothing.
      await bench.open(tester);
      expect(_panel(tester).left, 0);
    });

    testWidgets('a leftward fling closes it however short the drag', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);

      await tester.fling(
        find.byKey(_drawerContentKey),
        const Offset(-60, 0),
        MobileNavigationDrawerHost.flingVelocity * 3,
      );
      await tester.pump();
      await tester.pump(_pastSlide);

      expect(bench.controller.isOpen, isFalse);
    });

    testWidgets('a rightward fling reopens it even from the closed half', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);
      final width = _width(tester);

      // Dragged most of the way shut, slowly, then thrown back: released in
      // the closed half, so only the fling's direction can keep it open.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_drawerContentKey)),
      );
      await gesture.moveBy(
        Offset(-width * 0.8, 0),
        timeStamp: const Duration(milliseconds: 600),
      );
      for (var i = 1; i <= 3; i++) {
        await gesture.moveBy(
          const Offset(20, 0),
          timeStamp: Duration(milliseconds: 600 + i * 10),
        );
      }
      await tester.pump();
      expect(_panel(tester).left, lessThan(-width / 2));

      await gesture.up(timeStamp: const Duration(milliseconds: 630));
      await tester.pump();
      await tester.pump(_pastSlide);

      expect(bench.controller.isOpen, isTrue);
      expect(_panel(tester).left, 0);
    });
  });

  group('MobileNavigationDrawerHost lifecycle', () {
    testWidgets('follows a replacement controller and lets go of the old one', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      final replacement = MobileNavigationDrawerController()..open();

      await bench.pump(tester, controller: replacement);
      await tester.pump(_pastSlide);
      expect(_panel(tester).left, 0);

      // The old controller no longer drives anything.
      // ignore: invalid_use_of_protected_member
      expect(bench.controller.hasListeners, isFalse);
      replacement.close();
      await tester.pump();
      await tester.pump(_pastSlide);
      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
    });

    testWidgets('lets go of its controller, closed, once it is unmounted', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.pump(tester);
      await bench.open(tester);

      // The shell leaves with the drawer open: the window crossed into the
      // desktop layout, or the flag was switched off.
      await tester.pumpWidget(const SizedBox.shrink());

      // ignore: invalid_use_of_protected_member
      expect(bench.controller.hasListeners, isFalse);
      expect(bench.controller.isOpen, isFalse);

      // So the next host starts closed rather than open unasked.
      await bench.pump(tester);
      expect(find.byKey(MobileNavigationDrawerKeys.panel), findsNothing);
      expect(_pageOffset(tester), 0);
    });

    testWidgets('builds the panel once per visit, not on every frame of the '
        'slide or the drag', (tester) async {
      final bench = _Bench();
      await bench.pump(tester);

      bench.controller.open();
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(MotionDurations.medium2 ~/ 10);
      }
      await tester.pump(_pastSlide);
      expect(bench.drawerBuilds, 1);

      // A slow nudge, one update a frame, released in the open half.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_drawerContentKey)),
      );
      for (var i = 1; i <= 5; i++) {
        await gesture.moveBy(
          const Offset(-10, 0),
          timeStamp: Duration(milliseconds: i * 100),
        );
        await tester.pump();
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(_pastSlide);
      expect(bench.controller.isOpen, isTrue);
      expect(bench.drawerBuilds, 1);

      bench.controller.close();
      await tester.pump();
      await tester.pump(_pastSlide);
      await bench.open(tester);
      expect(bench.drawerBuilds, 2);
    });
  });

  group('mobileNavigationDrawerControllerProvider', () {
    test('hands out one closed controller and disposes it with its '
        'container', () {
      final container = ProviderContainer();
      final controller = container.read(
        mobileNavigationDrawerControllerProvider,
      );

      expect(controller.isOpen, isFalse);
      expect(
        container.read(mobileNavigationDrawerControllerProvider),
        same(controller),
      );

      container.dispose();
      expect(
        () => ChangeNotifier.debugAssertNotDisposed(controller),
        throwsFlutterError,
      );
    });
  });
}
