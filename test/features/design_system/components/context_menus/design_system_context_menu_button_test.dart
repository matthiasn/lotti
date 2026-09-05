import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemContextMenuButton', () {
    testWidgets('renders a >=48px trigger; the menu is closed initially', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemContextMenuButton(
            tooltip: 'More actions',
            items: [
              DesignSystemContextMenuItem(label: 'Edit', icon: LottiIcons.edit),
            ],
          ),
        ),
      );

      expect(find.byIcon(LottiIcons.more), findsOneWidget);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      // The menu surface is not in the tree until the trigger is tapped.
      expect(find.byType(DesignSystemContextMenu), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('More actions')),
        matchesSemantics(
          label: 'More actions',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets(
      'tapping the trigger toggles the DesignSystemContextMenu; tapping a row '
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
                  icon: LottiIcons.edit,
                  onTap: () => taps++,
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.byIcon(LottiIcons.more));
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemContextMenu), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);

        await tester.tap(find.byIcon(LottiIcons.more));
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemContextMenu), findsNothing);

        await tester.tap(find.byIcon(LottiIcons.more));
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemContextMenu), findsOneWidget);

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(taps, 1);
        // The popover closes after a selection.
        expect(find.byType(DesignSystemContextMenu), findsNothing);
      },
    );

    testWidgets('forwards item identity, icon color, and selected state', (
      tester,
    ) async {
      const itemKey = Key('selected-action');
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemContextMenuButton(
            tooltip: 'More actions',
            items: [
              DesignSystemContextMenuItem(
                key: itemKey,
                label: 'Current action',
                icon: LottiIcons.confirm,
                iconColor: Colors.green,
                isSelected: true,
                onTap: _noop,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(LottiIcons.more));
      await tester.pumpAndSettle();

      expect(find.byKey(itemKey), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.confirm)).color,
        Colors.green,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Current action')),
        matchesSemantics(
          label: 'Current action',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('preserves disabled menu items without invoking them', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemContextMenuButton(
            tooltip: 'More actions',
            items: [
              DesignSystemContextMenuItem(
                label: 'Archive',
                icon: LottiIcons.archive,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(LottiIcons.more));
      await tester.pumpAndSettle();

      final menu = tester.widget<DesignSystemContextMenu>(
        find.byType(DesignSystemContextMenu),
      );
      expect(menu.items.single.onTap, isNull);
      expect(
        tester.getSemantics(find.text('Archive')),
        matchesSemantics(
          label: 'Archive',
          isButton: true,
          hasEnabledState: true,
          // Explicitly assert the disabled value, not just its presence.
          // ignore: avoid_redundant_argument_values
          isEnabled: false,
        ),
      );
    });
  });
}

void _noop() {}
