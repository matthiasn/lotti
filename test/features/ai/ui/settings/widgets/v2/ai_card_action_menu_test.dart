import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
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

      // SizedBox.shrink instead of the popup trigger — the icon should
      // not be present, otherwise the v2 cards would show a useless `⋯`
      // button (the bug this widget was extracted to fix).
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.byType(PopupMenuButton<int>), findsNothing);
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

      // WCAG 2.5.5 — the compact 18px glyph sits inside a >=48px target.
      final size = tester.getSize(find.byType(PopupMenuButton<int>));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      'tap on the `⋯` icon opens the menu with one row per action and '
      'the destructive row is styled with the alert/error color',
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

        // Each action renders as a labelled row inside its PopupMenuItem.
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        // The destructive label resolves to the alert/error color from
        // the active design tokens; non-destructive rows render in
        // high-emphasis text and at regular weight.
        final tokens = tester.element(find.text('Delete')).designTokens;
        final deleteStyle = tester.widget<Text>(find.text('Delete')).style!;
        final editStyle = tester.widget<Text>(find.text('Edit')).style!;
        expect(deleteStyle.color, tokens.colors.alert.error.defaultColor);
        expect(editStyle.color, tokens.colors.text.highEmphasis);
        expect(deleteStyle.fontWeight, tokens.typography.weight.semiBold);
        expect(editStyle.fontWeight, tokens.typography.weight.regular);

        // Tapping the destructive row fires its callback (and only its
        // callback). The menu closes after selection.
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(editCount, 0);
        expect(deleteCount, 1);
      },
    );

    testWidgets(
      'each menu row routes its tap to the matching `onSelected` callback',
      (tester) async {
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

        // Reopen the menu and tap the first row to confirm index-routing
        // is stable across reopens (PopupMenuButton uses `value: i`).
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('First'));
        await tester.pumpAndSettle();

        expect(firstCount, 1);
        expect(secondCount, 1);
        expect(thirdCount, 0);
      },
    );
  });
}
