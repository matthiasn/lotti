import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_surface_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/test_app.dart';

void main() {
  var fired = <String>[];

  setUp(() => fired = []);

  List<DesignSystemContextMenuItem> items(BuildContext context) => [
    DesignSystemContextMenuItem(
      key: const ValueKey('row-edit'),
      icon: LottiIcons.edit,
      label: 'Edit',
      onTap: () => fired.add('edit'),
    ),
    agentInternalsMenuItem(
      context: context,
      key: const ValueKey('row-internals'),
      onTap: () => fired.add('internals'),
      startsGroup: true,
    ),
    DesignSystemContextMenuItem(
      key: const ValueKey('row-delete'),
      icon: LottiIcons.delete,
      label: 'Delete',
      isDestructive: true,
      onTap: () => fired.add('delete'),
      startsGroup: true,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    Alignment alignment = Alignment.topRight,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Align(
            alignment: alignment,
            child: Builder(
              builder: (context) => AgentSurfaceMenuButton(
                semanticsLabel: 'More actions',
                items: items(context),
                triggerBuilder: (context, open) => IconButton(
                  key: const ValueKey('trigger'),
                  icon: const Icon(LottiIcons.moreVertical),
                  onPressed: open,
                ),
              ),
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 600)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('trigger')));
    await tester.pumpAndSettle();
    expect(find.byType(DesignSystemContextMenu), findsOneWidget);
  }

  testWidgets(
    'opens the design-system menu over the shared modal scrim, so the page '
    'steps back',
    (tester) async {
      await pump(tester);
      await open(tester);

      final context = tester.element(find.byType(DesignSystemContextMenu));
      final expected = ModalUtils.getModalBarrierColor(
        isDark: Theme.of(context).brightness == Brightness.dark,
        context: context,
      );
      final barriers = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .where((barrier) => barrier.color != null);
      expect(barriers.map((barrier) => barrier.color), contains(expected));
      expect(expected.a, greaterThan(0));
    },
  );

  testWidgets(
    'sits on the raised card surface, as wide as its rows need — not the '
    "page's own level, not a fixed width",
    (tester) async {
      await pump(tester);
      await open(tester);

      final menu = find.byType(DesignSystemContextMenu);
      expect(
        tester.getSize(menu).width,
        lessThan(DesignSystemContextMenu.defaultWidth),
      );
      // The card surface — a step off the page in either theme.
      expect(
        tester.widget<DesignSystemContextMenu>(menu).surfaceColor,
        dsCardSurface(tester.element(menu)),
      );
    },
  );

  testWidgets(
    "the first and last row's hover fill meets the menu's edge, no strip "
    'of padding above or below it',
    (tester) async {
      await pump(tester);
      await open(tester);

      final menu = find.byType(DesignSystemContextMenu);
      final rows = find.descendant(of: menu, matching: find.byType(InkWell));
      expect(rows, findsAtLeast(2));
      final bounds = tester.getRect(menu);
      expect(tester.getRect(rows.first).top, bounds.top);
      expect(tester.getRect(rows.last).bottom, bounds.bottom);
    },
  );

  testWidgets('hangs under its trigger, trailing edges aligned', (
    tester,
  ) async {
    await pump(tester);
    await open(tester);

    final trigger = tester.getRect(find.byKey(const ValueKey('trigger')));
    final menu = tester.getRect(find.byType(DesignSystemContextMenu));
    expect(menu.top, greaterThan(trigger.bottom));
    // Clamped inside the window margin when the trigger sits at the edge.
    expect(menu.right, lessThanOrEqualTo(800));
    expect(menu.right, greaterThan(trigger.left));
  });

  testWidgets("right to left, it hangs from the trigger's leading edge", (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Builder(
                builder: (context) => AgentSurfaceMenuButton(
                  items: items(context),
                  triggerBuilder: (context, open) => IconButton(
                    key: const ValueKey('trigger'),
                    icon: const Icon(LottiIcons.moreVertical),
                    onPressed: open,
                  ),
                ),
              ),
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(800, 600)),
      ),
    );
    await tester.pumpAndSettle();
    await open(tester);

    final trigger = tester.getRect(find.byKey(const ValueKey('trigger')));
    final menu = tester.getRect(find.byType(DesignSystemContextMenu));
    expect(menu.left, moreOrLessEquals(trigger.left));
  });

  testWidgets('follows its trigger when the window changes under it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    await open(tester);
    final before = tester.getRect(find.byType(DesignSystemContextMenu));

    // Too short for the menu under its trigger any more: it re-places
    // itself inside the window rather than running off its bottom.
    tester.view.physicalSize = const Size(800, 200);
    await tester.pumpAndSettle();

    final after = tester.getRect(find.byType(DesignSystemContextMenu));
    expect(after.bottom, lessThanOrEqualTo(200));
    expect(after.top, lessThan(before.top));
  });

  testWidgets('opens upward when there is no room below the trigger', (
    tester,
  ) async {
    await pump(tester, alignment: Alignment.bottomRight);
    await open(tester);

    final trigger = tester.getRect(find.byKey(const ValueKey('trigger')));
    final menu = tester.getRect(find.byType(DesignSystemContextMenu));
    expect(menu.bottom, lessThan(trigger.top));
  });

  testWidgets('a row closes the menu, then acts', (tester) async {
    await pump(tester);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('row-delete')));
    await tester.pumpAndSettle();

    expect(fired, ['delete']);
    expect(find.byType(DesignSystemContextMenu), findsNothing);
  });

  testWidgets('a tap on the scrim closes the menu without acting', (
    tester,
  ) async {
    await pump(tester);
    await open(tester);

    await tester.tapAt(const Offset(40, 560));
    await tester.pumpAndSettle();

    expect(fired, isEmpty);
    expect(find.byType(DesignSystemContextMenu), findsNothing);
  });

  testWidgets('Escape closes the menu without acting', (tester) async {
    await pump(tester);
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(fired, isEmpty);
    expect(find.byType(DesignSystemContextMenu), findsNothing);
  });

  testWidgets(
    'the internals row reads the same everywhere: the tune glyph and the '
    "panel's own title",
    (tester) async {
      await pump(tester);
      await open(tester);

      final row = find.byKey(const ValueKey('row-internals'));
      expect(
        find.descendant(of: row, matching: find.text('Agent internals')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(LottiIcons.tune)),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(fired, ['internals']);
    },
  );
}
