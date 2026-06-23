import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemContextMenuButton', () {
    testWidgets('renders a >=48px trigger; the menu is closed initially', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemContextMenuButton(
            tooltip: 'More actions',
            items: [
              DesignSystemContextMenuItem(label: 'Edit', icon: Icons.edit),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      // The menu surface is not in the tree until the trigger is tapped.
      expect(find.byType(DesignSystemContextMenu), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets(
      'tapping the trigger opens the DesignSystemContextMenu; tapping a row '
      'fires its callback and closes the menu',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DesignSystemContextMenuButton(
              tooltip: 'More actions',
              items: [
                DesignSystemContextMenuItem(
                  label: 'Edit',
                  icon: Icons.edit,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemContextMenu), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(taps, 1);
        // The popover closes after a selection.
        expect(find.byType(DesignSystemContextMenu), findsNothing);
      },
    );
  });
}
