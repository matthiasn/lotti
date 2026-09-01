import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';

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
  });
}
