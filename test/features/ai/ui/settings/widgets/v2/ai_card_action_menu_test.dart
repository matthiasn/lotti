import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('AiCardActionMenuButton', () {
    testWidgets('renders nothing when the action list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(const AiCardActionMenuButton(actions: [])),
      );

      // Empty actions short-circuit to SizedBox.shrink — no trigger at all,
      // so the v2 cards don't show a useless `⋯` button.
      expect(find.byType(DesignSystemContextMenuButton), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets('the `⋯` trigger meets the 48px minimum touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          AiCardActionMenuButton(
            actions: [
              AiCardMenuAction(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onSelected: () {},
              ),
            ],
          ),
        ),
      );

      // WCAG 2.5.5 — the compact glyph sits inside a >=48px target.
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      'tapping the `⋯` opens one row per action; the destructive row uses the '
      'alert/error color; tapping it fires only its callback and closes',
      (tester) async {
        var editCount = 0;
        var deleteCount = 0;

        await tester.pumpWidget(
          makeTestableWidget(
            AiCardActionMenuButton(
              actions: [
                AiCardMenuAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onSelected: () => editCount++,
                ),
                AiCardMenuAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  isDestructive: true,
                  onSelected: () => deleteCount++,
                ),
              ],
            ),
          ),
        );

        expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        // The destructive row resolves to the alert/error token; the
        // non-destructive row to high-emphasis text.
        final tokens = tester.element(find.text('Delete')).designTokens;
        expect(
          tester.widget<Text>(find.text('Delete')).style!.color,
          tokens.colors.alert.error.defaultColor,
        );
        expect(
          tester.widget<Text>(find.text('Edit')).style!.color,
          tokens.colors.text.highEmphasis,
        );

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(editCount, 0);
        expect(deleteCount, 1);
        // The menu closes after a selection.
        expect(find.text('Edit'), findsNothing);
      },
    );

    testWidgets('each menu row routes its tap to the matching callback', (
      tester,
    ) async {
      var firstCount = 0;
      var secondCount = 0;
      var thirdCount = 0;

      Widget harness() => makeTestableWidget(
        AiCardActionMenuButton(
          actions: [
            AiCardMenuAction(
              icon: Icons.edit_outlined,
              label: 'First',
              onSelected: () => firstCount++,
            ),
            AiCardMenuAction(
              icon: Icons.copy_outlined,
              label: 'Second',
              onSelected: () => secondCount++,
            ),
            AiCardMenuAction(
              icon: Icons.delete_outline_rounded,
              label: 'Third',
              isDestructive: true,
              onSelected: () => thirdCount++,
            ),
          ],
        ),
      );

      await tester.pumpWidget(harness());
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(firstCount, 0);
      expect(secondCount, 1);
      expect(thirdCount, 0);

      // Reopen and tap the first row to confirm routing is stable.
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();

      expect(firstCount, 1);
      expect(secondCount, 1);
      expect(thirdCount, 0);
    });
  });
}
