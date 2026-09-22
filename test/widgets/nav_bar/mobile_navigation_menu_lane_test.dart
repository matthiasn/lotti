import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/navigation/ds_menu_glyph.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_menu_lane.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

const _pageKey = Key('page');

/// The shared phone fixture plus the `viewPadding` a real notched device
/// reports — without it, "took the inset off the page" would pass trivially.
final MediaQueryData _phone = phoneMediaQueryData.copyWith(
  viewPadding: phoneMediaQueryData.padding,
);

/// Past the lane's fold: a controller reports `completed` only once the
/// elapsed time *exceeds* its duration (see test/README.md).
final Duration _pastFold =
    MotionDurations.medium4 + const Duration(milliseconds: 50);

/// The top inset the page under the lane was handed.
EdgeInsets _pagePadding(WidgetTester tester) =>
    MediaQuery.paddingOf(tester.element(find.byKey(_pageKey)));

EdgeInsets _pageViewPadding(WidgetTester tester) =>
    MediaQuery.viewPaddingOf(tester.element(find.byKey(_pageKey)));

double _pageTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(_pageKey)).dy;

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(MobileNavigationMenuLane)).designTokens;

double _rowHeight(WidgetTester tester) => MobileNavigationMenuLane.rowHeight(
  tester.element(find.byType(MobileNavigationMenuLane)),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool visible,
  VoidCallback? onOpenMenu,
  MediaQueryData? mediaQueryData,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      MobileNavigationMenuLane(
        visible: visible,
        onOpenMenu: onOpenMenu ?? () {},
        child: const SizedBox.expand(key: _pageKey),
      ),
      mediaQueryData: mediaQueryData ?? _phone,
    ),
  );
}

void main() {
  group('MobileNavigationMenuLane shown', () {
    testWidgets('fixes the menu button at the top-leading corner, clear of '
        'the status bar', (tester) async {
      await _pump(tester, visible: true);

      final button = tester.getRect(
        find.byKey(MobileNavigationMenuLaneKeys.button),
      );
      final tokens = _tokens(tester);
      expect(button.left, tokens.spacing.step5);
      expect(
        button.top,
        phoneMediaQueryData.padding.top + tokens.spacing.step2,
      );
      expect(button.size, const Size.square(TapTargets.compact));
    });

    testWidgets('starts the page beneath the lane and takes the status-bar '
        'inset off it', (tester) async {
      await _pump(tester, visible: true);

      expect(
        _pageTop(tester),
        phoneMediaQueryData.padding.top + _rowHeight(tester),
      );
      // The lane already cleared the status bar; a page padding for it again
      // would open a second, empty band under the button.
      expect(_pagePadding(tester).top, 0);
      expect(_pageViewPadding(tester).top, 0);
      // The bottom inset is none of the lane's business.
      expect(_pagePadding(tester).bottom, phoneMediaQueryData.padding.bottom);
    });

    testWidgets('draws the two-stroke mark on a quiet surface disc with a '
        'hairline edge', (tester) async {
      await _pump(tester, visible: true);

      final button = tester.widget<DsGlassRoundButton>(
        find.byType(DsGlassRoundButton),
      );
      final tokens = _tokens(tester);
      expect(button.glyph, isA<DsMenuGlyph>());
      expect(button.backgroundColor, tokens.colors.background.level02);
      expect(button.outlineColor, tokens.colors.decorative.level01);
      expect(button.iconSize, IconSizes.l);
    });

    testWidgets('opens the menu on tap and says so to assistive tech', (
      tester,
    ) async {
      var opened = 0;
      final handle = tester.ensureSemantics();
      try {
        await _pump(tester, visible: true, onOpenMenu: () => opened++);

        expect(
          tester.getSemantics(find.bySemanticsLabel('Open navigation').first),
          matchesSemantics(label: 'Open navigation', isButton: true),
        );

        await tester.tap(find.byKey(MobileNavigationMenuLaneKeys.button));
        expect(opened, 1);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('keeps the button inside the horizontal safe area', (
      tester,
    ) async {
      await _pump(
        tester,
        visible: true,
        mediaQueryData: _phone.copyWith(
          padding: const EdgeInsets.only(top: 47, left: 44, bottom: 34),
        ),
      );

      expect(
        tester.getRect(find.byKey(MobileNavigationMenuLaneKeys.button)).left,
        44 + _tokens(tester).spacing.step5,
      );
    });
  });

  group('MobileNavigationMenuLane hidden', () {
    testWidgets('leaves no lane and hands the whole status-bar inset back to '
        'the page', (tester) async {
      await _pump(tester, visible: false);

      expect(find.byKey(MobileNavigationMenuLaneKeys.lane), findsNothing);
      expect(find.byKey(MobileNavigationMenuLaneKeys.button), findsNothing);
      expect(_pageTop(tester), 0);
      expect(_pagePadding(tester).top, phoneMediaQueryData.padding.top);
      expect(_pageViewPadding(tester).top, phoneMediaQueryData.padding.top);
    });
  });

  group('MobileNavigationMenuLane folding', () {
    testWidgets("folds away without the page ever jumping: the lane's height "
        'and the inset it hands back always add up', (tester) async {
      await _pump(tester, visible: true);
      final inset = phoneMediaQueryData.padding.top;
      final row = _rowHeight(tester);
      // Where the page's own content starts: its top edge plus the inset it
      // pads by. Shown, that is inset + row; hidden, just the inset.
      double contentStart() => _pageTop(tester) + _pagePadding(tester).top;
      expect(contentStart(), inset + row);

      await _pump(tester, visible: false);
      var previous = contentStart();
      for (var i = 0; i < 8; i++) {
        await tester.pump(MotionDurations.medium4 ~/ 8);
        final now = contentStart();
        // Only ever moving up, and never past where it will come to rest.
        expect(now, lessThanOrEqualTo(previous + precisionErrorTolerance));
        expect(now, greaterThanOrEqualTo(inset - precisionErrorTolerance));
        previous = now;
      }
      await tester.pump(_pastFold);

      expect(contentStart(), moreOrLessEquals(inset));
      expect(find.byKey(MobileNavigationMenuLaneKeys.button), findsNothing);
    });

    testWidgets('keeps the page mounted while the lane comes and goes', (
      tester,
    ) async {
      await _pump(tester, visible: true);
      final pageElement = tester.element(find.byKey(_pageKey));

      await _pump(tester, visible: false);
      await tester.pump(_pastFold);
      await _pump(tester, visible: true);
      await tester.pump(_pastFold);

      expect(tester.element(find.byKey(_pageKey)), same(pageElement));
      expect(find.byKey(MobileNavigationMenuLaneKeys.button), findsOneWidget);
    });

    testWidgets('snaps instead of folding when animations are disabled', (
      tester,
    ) async {
      final reduced = _phone.copyWith(disableAnimations: true);
      await _pump(tester, visible: true, mediaQueryData: reduced);

      await _pump(tester, visible: false, mediaQueryData: reduced);
      await tester.pump();

      expect(find.byKey(MobileNavigationMenuLaneKeys.button), findsNothing);
      expect(_pagePadding(tester).top, phoneMediaQueryData.padding.top);
    });
  });
}
