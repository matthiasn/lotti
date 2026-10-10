import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemContextMenuAnchor', () {
    testWidgets('the trigger toggles the menu; a row tap fires and closes', (
      tester,
    ) async {
      var taps = 0;
      var lastOpen = false;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemContextMenuAnchor(
            header: 'Heading',
            semanticsLabel: 'Anchored menu',
            items: [
              DesignSystemContextMenuItem(
                label: 'Row',
                onTap: () => taps++,
              ),
            ],
            builder: (context, {required toggle, required isOpen}) {
              lastOpen = isOpen;
              return TextButton(onPressed: toggle, child: const Text('Open'));
            },
          ),
        ),
      );

      expect(find.byType(DesignSystemContextMenu), findsNothing);
      expect(lastOpen, isFalse);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemContextMenu), findsOneWidget);
      expect(find.text('Heading'), findsOneWidget);
      expect(lastOpen, isTrue);

      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.byType(DesignSystemContextMenu), findsNothing);
      expect(lastOpen, isFalse);
    });

    testWidgets('tapping the trigger again closes an open menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemContextMenuAnchor(
            items: const [DesignSystemContextMenuItem(label: 'Row')],
            builder: (context, {required toggle, required isOpen}) =>
                TextButton(onPressed: toggle, child: const Text('Open')),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Row'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Row'), findsNothing);
    });

    testWidgets('a row without a callback stays disabled and leaves the menu '
        'open', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemContextMenuAnchor(
            items: const [DesignSystemContextMenuItem(label: 'Inert')],
            builder: (context, {required toggle, required isOpen}) =>
                TextButton(onPressed: toggle, child: const Text('Open')),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final row = tester.widget<DesignSystemContextMenu>(
        find.byType(DesignSystemContextMenu),
      );
      expect(row.items.single.onTap, isNull);

      await tester.tap(find.text('Inert'));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemContextMenu), findsOneWidget);
    });

    testWidgets('a caller-owned controller opens the menu where it says, and '
        'the trigger still toggles it', (tester) async {
      final controller = MenuController();
      var taps = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DesignSystemContextMenuAnchor(
            controller: controller,
            items: [
              DesignSystemContextMenuItem(label: 'Row', onTap: () => taps++),
            ],
            builder: (context, {required toggle, required isOpen}) => SizedBox(
              width: 300,
              height: 200,
              child: GestureDetector(
                onTap: toggle,
                onSecondaryTapUp: (details) =>
                    controller.open(position: details.localPosition),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
        ),
      );
      final trigger = find.byType(GestureDetector).first;
      final origin = tester.getTopLeft(trigger);

      await tester.tapAt(
        origin + const Offset(200, 150),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final menu = find.byType(DesignSystemContextMenu);
      expect(menu, findsOneWidget);
      // At the pointer, not beneath the trigger.
      final menuTop = tester.getTopLeft(menu);
      expect(menuTop.dy, closeTo(origin.dy + 150, 1));
      expect(menuTop.dx, closeTo(origin.dx + 200, 1));

      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(menu, findsNothing);

      await tester.tapAt(origin + const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
      expect(tester.getTopLeft(menu).dy, greaterThan(origin.dy + 150));
    });

    testWidgets('a controller handed in later, or taken away, is the one the '
        'menu answers', (tester) async {
      Widget anchored(MenuController? controller) =>
          makeTestableWidgetWithScaffold(
            DesignSystemContextMenuAnchor(
              controller: controller,
              items: const [DesignSystemContextMenuItem(label: 'Row')],
              builder: (context, {required toggle, required isOpen}) =>
                  TextButton(onPressed: toggle, child: const Text('Open')),
            ),
          );
      final first = MenuController();
      final second = MenuController();
      final menu = find.byType(DesignSystemContextMenu);

      await tester.pumpWidget(anchored(first));
      await tester.pumpWidget(anchored(second));
      second.open();
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
      second.close();
      await tester.pumpAndSettle();
      expect(menu, findsNothing);
      expect(first.isOpen, isFalse);

      // Taken away: the anchor owns one again, and the trigger still works.
      await tester.pumpWidget(anchored(null));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(menu, findsOneWidget);
      expect(second.isOpen, isFalse);
    });
  });
}
