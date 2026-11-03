import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_surface_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
