import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';

import '../../../../widget_test_utils.dart';

const _contentKey = Key('content');
const _contentSize = Size(240, 100);
const _label = 'collapsing content';

/// A child whose intrinsic size is known, so painted-vs-reserved geometry can
/// be compared exactly.
Widget _content({VoidCallback? onTap}) => Semantics(
  label: _label,
  container: true,
  child: GestureDetector(
    onTap: onTap,
    child: const SizedBox(
      key: _contentKey,
      width: 240,
      height: 100,
      child: ColoredBox(color: Color(0xFF00FF00)),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool collapsed,
  bool reduceMotion = false,
  VoidCallback? onTap,
  VoidCallback? onCollapsed,
  Duration duration = const Duration(milliseconds: 300),
}) => tester.pumpWidget(
  makeTestableWidgetNoScroll(
    // Pinned top-left in a fixed-width slot so the collapse is the only thing
    // that can move the content.
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        child: SizeFadeCollapse(
          collapsed: collapsed,
          duration: duration,
          onCollapsed: onCollapsed,
          child: _content(onTap: onTap),
        ),
      ),
    ),
    mediaQueryData: phoneMediaQueryData.copyWith(
      disableAnimations: reduceMotion,
    ),
  ),
);

/// The reserved layout box vs the content's actual on-screen rect. `getSize`
/// is layout-only; `getRect` goes through `localToGlobal`, so it reflects the
/// paint transform.
({Size reserved, Rect painted, double opacity}) _measure(WidgetTester tester) =>
    (
      reserved: tester.getSize(find.byType(SizeFadeCollapse)),
      painted: tester.getRect(find.byKey(_contentKey)),
      opacity: tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(SizeFadeCollapse),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value,
    );

/// Whether the live semantics tree still announces [_label]. `find
/// .bySemanticsLabel` reads `debugSemantics`, which goes stale once a node is
/// excluded, so walk the real tree instead.
bool _announced(WidgetTester tester) {
  bool search(SemanticsNode node) {
    if (node.label == _label) return true;
    var found = false;
    node.visitChildren((child) {
      found = found || search(child);
      return true;
    });
    return found;
  }

  return search(tester.getSemantics(find.byType(MaterialApp)));
}

void main() {
  group('SizeFadeCollapse', () {
    testWidgets('shown content reserves and paints its full natural size', (
      tester,
    ) async {
      await _pump(tester, collapsed: false);

      final m = _measure(tester);
      expect(m.reserved.height, _contentSize.height);
      expect(m.painted.size, _contentSize);
      expect(m.opacity, 1);
    });

    testWidgets('initial collapsed state applies without animating', (
      tester,
    ) async {
      await _pump(tester, collapsed: true);

      // Zero on the very first frame: an animation would have started from the
      // full height and taken several frames to get here.
      expect(_measure(tester).reserved.height, 0);
    });

    testWidgets(
      'painted height matches the reserved height on every frame of the '
      'collapse',
      (tester) async {
        await _pump(tester, collapsed: false);
        await _pump(tester, collapsed: true);

        var sawIntermediateFrame = false;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          final m = _measure(tester);

          // The invariant the widget exists for: content is scaled to exactly
          // fill the shrinking box, so it is never cropped and never leaves a
          // gap. A clip-only collapse would hold painted height at 100.
          expect(
            m.painted.height,
            closeTo(m.reserved.height, 0.5),
            reason: 'frame $i',
          );
          // Uniform scale — width shrinks by the same factor as height.
          expect(
            m.painted.width / _contentSize.width,
            closeTo(m.painted.height / _contentSize.height, 0.01),
            reason: 'frame $i',
          );

          if (m.reserved.height > 0.5 && m.reserved.height < 99.5) {
            sawIntermediateFrame = true;
            // Opacity is driven by the same factor, so it tracks the shrink
            // rather than running on its own schedule.
            expect(
              m.opacity,
              closeTo(m.painted.height / _contentSize.height, 0.01),
              reason: 'frame $i',
            );
          }
        }

        expect(sawIntermediateFrame, isTrue);
        expect(_measure(tester).reserved.height, 0);
      },
    );

    testWidgets('content stays anchored to the leading edge as it shrinks', (
      tester,
    ) async {
      await _pump(tester, collapsed: false);
      final rest = tester.getRect(find.byKey(_contentKey));

      await _pump(tester, collapsed: true);
      await tester.pump(const Duration(milliseconds: 60));

      final painted = tester.getRect(find.byKey(_contentKey));
      // Scaling about top-start keeps the corner pinned, so the content
      // shrinks in place instead of drifting toward the centre.
      expect(painted.left, closeTo(rest.left, 0.5));
      expect(painted.top, closeTo(rest.top, 0.5));
      expect(painted.height, lessThan(_contentSize.height));
    });

    testWidgets('reversing restores the full size', (tester) async {
      await _pump(tester, collapsed: false);
      await _pump(tester, collapsed: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_measure(tester).reserved.height, lessThan(_contentSize.height));

      await _pump(tester, collapsed: false);
      await tester.pump(const Duration(milliseconds: 400));

      final m = _measure(tester);
      expect(m.reserved.height, _contentSize.height);
      expect(m.painted.size, _contentSize);
      expect(m.opacity, 1);
    });

    testWidgets('reduced motion snaps instead of animating', (tester) async {
      await _pump(tester, collapsed: false, reduceMotion: true);
      await _pump(tester, collapsed: true, reduceMotion: true);

      // Fully gone on the first frame after the flip — no in-between.
      expect(_measure(tester).reserved.height, 0);
    });

    testWidgets('collapsed content is untappable and hidden from semantics', (
      tester,
    ) async {
      // Disposed inline, not via addTearDown: the handle-leak check runs
      // before tear-downs do.
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await _pump(tester, collapsed: false, onTap: () => taps++);
      await tester.tap(find.byKey(_contentKey));
      expect(taps, 1);
      expect(_announced(tester), isTrue);

      // Still partly visible, but already on its way out.
      await _pump(tester, collapsed: true, onTap: () => taps++);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_measure(tester).reserved.height, greaterThan(0));

      await tester.tap(find.byKey(_contentKey), warnIfMissed: false);
      expect(taps, 1, reason: 'a leaving row must not accept taps');
      expect(_announced(tester), isFalse);

      semantics.dispose();
    });

    testWidgets(
      'onCollapsed fires once the collapse has run to the end, not before',
      (tester) async {
        var calls = 0;
        await _pump(tester, collapsed: false, onCollapsed: () => calls++);
        await _pump(tester, collapsed: true, onCollapsed: () => calls++);
        // The ticker's zero-elapsed start frame, then half the collapse.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        // Mid-collapse the content is still partly there — the owner must
        // not drop it yet.
        final mid = _measure(tester).reserved.height;
        expect(mid, greaterThan(0));
        expect(mid, lessThan(_contentSize.height));
        expect(calls, 0);

        // Past the end, not exactly at it: the simulation reports done only
        // strictly after its duration, and the callback lands post-frame.
        await tester.pump(const Duration(milliseconds: 200));
        expect(_measure(tester).reserved.height, 0);
        expect(calls, 1);
      },
    );

    testWidgets(
      'onCollapsed fires for the reduced-motion snap too',
      (tester) async {
        var calls = 0;
        await _pump(
          tester,
          collapsed: false,
          reduceMotion: true,
          onCollapsed: () => calls++,
        );
        await _pump(
          tester,
          collapsed: true,
          reduceMotion: true,
          onCollapsed: () => calls++,
        );
        expect(_measure(tester).reserved.height, 0);
        expect(calls, 1);
      },
    );

    testWidgets(
      'onCollapsed does not fire for content that starts out collapsed, nor '
      'on a reveal',
      (tester) async {
        var calls = 0;
        await _pump(tester, collapsed: true, onCollapsed: () => calls++);
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, 0);

        await _pump(tester, collapsed: false, onCollapsed: () => calls++);
        await tester.pump(const Duration(milliseconds: 300));
        expect(_measure(tester).reserved.height, _contentSize.height);
        expect(calls, 0);
      },
    );

    testWidgets('a changed duration retimes the next collapse', (tester) async {
      const slow = Duration(milliseconds: 800);
      await _pump(tester, collapsed: false);
      await _pump(tester, collapsed: false, duration: slow);
      await _pump(tester, collapsed: true, duration: slow);

      // 300ms in, a 300ms collapse would already be done; the 800ms one is not.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_measure(tester).reserved.height, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 600));
      expect(_measure(tester).reserved.height, 0);
    });
  });
}
