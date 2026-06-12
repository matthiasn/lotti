import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required List<DesignSystemFiveSlotNavBarItem> items,
    double width = 390,
    MediaQueryData? mediaQueryData,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          width: width,
          child: DesignSystemFiveSlotNavBar(items: items),
        ),
        theme: DesignSystemTheme.light(),
        mediaQueryData: mediaQueryData,
      ),
    );
  }

  DesignSystemFiveSlotNavBarItem item(
    String label, {
    bool active = false,
    VoidCallback? onTap,
    String? semanticsLabel,
  }) {
    return DesignSystemFiveSlotNavBarItem(
      label: label,
      icon: const Icon(Icons.circle_outlined),
      activeIcon: const Icon(Icons.circle),
      active: active,
      onTap: onTap,
      semanticsLabel: semanticsLabel,
    );
  }

  List<DesignSystemFiveSlotNavBarItem> barItems() => [
    item('Tasks', active: true),
    item('Journal'),
    item('Settings'),
    item('More'),
  ];

  const slotLabels = ['Tasks', 'Journal', 'Settings', 'More'];

  group('DesignSystemFiveSlotNavBar', () {
    testWidgets('gives all slots an equal share of the width', (
      tester,
    ) async {
      await pumpBar(tester, items: barItems());

      final widths = <double>[
        for (final label in slotLabels)
          tester
              .getSize(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .width,
      ];

      // Equal flex: every slot gets the same width, in left-to-right order.
      expect(widths.toSet(), hasLength(1));
      final centers = <double>[
        for (final label in slotLabels) tester.getCenter(find.text(label)).dx,
      ];
      expect(centers, List.of(centers)..sort());
    });

    testWidgets('renders one equal-width slot per item beyond five', (
      tester,
    ) async {
      // Wide mobile windows show every destination in its own slot — the
      // bar imposes no slot cap; the overflow budget is the shell's call.
      const labels = [
        'Tasks',
        'DailyOS',
        'Projects',
        'Habits',
        'Insights',
        'Logbook',
        'Settings',
      ];
      await pumpBar(
        tester,
        width: 800,
        items: [for (final label in labels) item(label)],
        mediaQueryData: const MediaQueryData(size: Size(800, 1200)),
      );

      final widths = <double>[
        for (final label in labels)
          tester
              .getSize(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .width,
      ];
      expect(widths.toSet(), hasLength(1));
    });

    testWidgets('allSlotsFit adapts to window width and text scale', (
      tester,
    ) async {
      const sevenLabels = [
        'Tasks',
        'DailyOS',
        'Projects',
        'Habits',
        'Insights',
        'Logbook',
        'Settings',
      ];

      Future<BuildContext> contextWith(MediaQueryData mediaQueryData) async {
        late BuildContext captured;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
            theme: DesignSystemTheme.light(),
            mediaQueryData: mediaQueryData,
          ),
        );
        return captured;
      }

      // Wide window at default text scale: all seven destinations fit.
      var context = await contextWith(
        const MediaQueryData(size: Size(800, 1200)),
      );
      expect(
        DesignSystemFiveSlotNavBar.allSlotsFit(context, sevenLabels),
        isTrue,
      );

      // The same window at 3× text scale: the widened labels outgrow the
      // row, so the caller must fall back to the More overflow.
      context = await contextWith(
        const MediaQueryData(
          size: Size(800, 1200),
          textScaler: TextScaler.linear(3),
        ),
      );
      expect(
        DesignSystemFiveSlotNavBar.allSlotsFit(context, sevenLabels),
        isFalse,
      );

      // Phone width: seven destinations overflow…
      context = await contextWith(
        const MediaQueryData(size: Size(390, 844)),
      );
      expect(
        DesignSystemFiveSlotNavBar.allSlotsFit(context, sevenLabels),
        isFalse,
      );
      // …but a short line-up fits even there.
      expect(
        DesignSystemFiveSlotNavBar.allSlotsFit(
          context,
          const ['Tasks', 'Logbook', 'Settings'],
        ),
        isTrue,
      );
    });

    testWidgets('labels stay full-size on a 360px-wide device', (tester) async {
      await pumpBar(tester, width: 360, items: barItems());

      // No FittedBox scaling: the rendered label height matches the caption
      // line height exactly, so the text is not shrunk.
      final labelRect = tester.getRect(find.text('Tasks'));
      expect(
        labelRect.height,
        dsTokensLight.typography.lineHeight.caption,
      );
    });

    testWidgets('grows with the system text scale instead of clipping', (
      tester,
    ) async {
      await pumpBar(
        tester,
        items: barItems(),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.5),
        ),
      );

      // No RenderFlex overflow at 1.5× font scale (an overflow would fail
      // the test via the exception handler), and the rendered bar still
      // matches the shared height contract, which now exceeds the
      // unscaled minimum row height.
      final context = tester.element(find.byType(DesignSystemFiveSlotNavBar));
      final barRect = tester.getRect(find.byType(DesignSystemFiveSlotNavBar));
      expect(barRect.height, DesignSystemFiveSlotNavBar.barHeight(context));
      expect(
        DesignSystemFiveSlotNavBar.contentHeight(context),
        greaterThan(DesignSystemFiveSlotNavBar.minTapTarget),
      );
    });

    testWidgets('keeps slots clear of horizontal safe-area insets', (
      tester,
    ) async {
      const leftInset = 30.0;
      const rightInset = 48.0;
      await pumpBar(
        tester,
        items: barItems(),
        mediaQueryData: const MediaQueryData(
          size: Size(844, 390),
          padding: EdgeInsets.only(left: leftInset, right: rightInset),
        ),
      );

      final barRect = tester.getRect(find.byType(DesignSystemFiveSlotNavBar));
      final firstSlot = tester.getRect(
        find.ancestor(of: find.text('Tasks'), matching: find.byType(InkWell)),
      );
      final lastSlot = tester.getRect(
        find.ancestor(of: find.text('More'), matching: find.byType(InkWell)),
      );

      // The surface spans the full width, but the tappable slots stay
      // clear of notches / landscape navigation buttons on either side.
      expect(firstSlot.left - barRect.left, greaterThanOrEqualTo(leftInset));
      expect(barRect.right - lastSlot.right, greaterThanOrEqualTo(rightInset));
    });

    testWidgets('docks flush: surface absorbs the bottom safe-area inset', (
      tester,
    ) async {
      const inset = 34.0;
      await pumpBar(
        tester,
        items: barItems(),
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: inset),
        ),
      );

      final barRect = tester.getRect(find.byType(DesignSystemFiveSlotNavBar));
      final slotRect = tester.getRect(
        find.ancestor(of: find.text('Tasks'), matching: find.byType(InkWell)),
      );

      // The rendered bar height matches the shared height contract...
      expect(
        barRect.height,
        DesignSystemFiveSlotNavBar.barHeight(
          tester.element(find.byType(DesignSystemFiveSlotNavBar)),
        ),
      );
      // ...and the surface extends exactly the absorbed inset
      // (bottomInsetFraction of the OS-reported one) plus the hairline
      // border below the slot row: the
      // trimmed inset replaces the internal bottom padding instead of
      // stacking onto it, so home-indicator devices get no dead space.
      expect(
        barRect.bottom - slotRect.bottom,
        moreOrLessEquals(
          inset * DesignSystemFiveSlotNavBar.bottomInsetFraction +
              DesignSystemNavigationFrostedSurface.borderWidth,
        ),
      );
    });

    testWidgets('active slot uses the interactive tint and active icon', (
      tester,
    ) async {
      await pumpBar(
        tester,
        items: [
          item('Tasks', active: true),
          item('Journal'),
          item('Settings'),
        ],
      );
      // Let the tint animation settle.
      await tester.pump(DesignSystemFiveSlotNavBar.tintDuration);

      // Active slot swaps to the filled icon; inactive slots keep the
      // outlined one.
      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));

      final activeLabel = tester.widget<Text>(find.text('Tasks'));
      final inactiveLabel = tester.widget<Text>(find.text('Journal'));
      expect(
        activeLabel.style!.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        inactiveLabel.style!.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
    });

    testWidgets('tapping a slot invokes only its own callback', (tester) async {
      final taps = <String>[];
      await pumpBar(
        tester,
        items: [
          item('Tasks', active: true, onTap: () => taps.add('tasks')),
          item('Journal', onTap: () => taps.add('journal')),
          item('Settings', onTap: () => taps.add('settings')),
        ],
      );

      await tester.tap(find.text('Journal'));
      expect(taps, ['journal']);
    });

    testWidgets('every slot meets the 44px minimum tap target', (tester) async {
      await pumpBar(tester, items: barItems());

      for (final label in slotLabels) {
        final slot = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          slot.height,
          greaterThanOrEqualTo(DesignSystemFiveSlotNavBar.minTapTarget),
          reason: '$label slot height',
        );
        expect(
          slot.width,
          greaterThanOrEqualTo(DesignSystemFiveSlotNavBar.minTapTarget),
          reason: '$label slot width',
        );
      }
    });

    testWidgets('announces semantics label, selection, and overrides', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(
        tester,
        items: [
          item('Tasks', active: true, onTap: () {}),
          item(
            'More',
            semanticsLabel: 'More, 4 additional destinations',
            onTap: () {},
          ),
        ],
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Tasks')),
        matchesSemantics(
          label: 'Tasks',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
          // The InkWell's own semantics merge into the slot node now that
          // the subtree is no longer excluded (keeps badges announced).
          hasFocusAction: true,
          isFocusable: true,
          hasSelectedState: true,
        ),
      );
      // The More slot announces the hidden-destination count instead of
      // its short visual label.
      expect(
        find.bySemanticsLabel('More, 4 additional destinations'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('keeps badge decorations on the icon in the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBar(
        tester,
        items: [
          item('Tasks', active: true, onTap: () {}),
          DesignSystemFiveSlotNavBarItem(
            label: 'Settings',
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.settings_outlined),
            ),
            onTap: () {},
          ),
        ],
      );

      // The slot replaces only the label text's semantics; the icon
      // subtree keeps its own, so the pending-count badge stays announced
      // alongside the slot label.
      expect(find.bySemanticsLabel(RegExp('Settings')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('3')), findsOneWidget);
      handle.dispose();
    });
  });
}
