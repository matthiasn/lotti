import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('DesignSystemEmptyState', () {
    testWidgets(
      'renders the full ramp: step9 glyph, subtitle1 title, caption hint, '
      'and the action',
      (tester) async {
        var pressed = 0;
        await pump(
          tester,
          DesignSystemEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            hint: 'Add something to begin.',
            action: TextButton(
              onPressed: () => pressed++,
              child: const Text('Add'),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
        expect(icon.size, dsTokensDark.spacing.step9);
        expect(icon.color, dsTokensDark.colors.text.lowEmphasis);

        final title = tester.widget<Text>(find.text('Nothing here'));
        expect(
          title.style?.fontSize,
          dsTokensDark.typography.styles.subtitle.subtitle1.fontSize,
        );
        expect(title.style?.color, dsTokensDark.colors.text.highEmphasis);

        final hint = tester.widget<Text>(find.text('Add something to begin.'));
        expect(
          hint.style?.fontSize,
          dsTokensDark.typography.styles.others.caption.fontSize,
        );
        expect(hint.style?.color, dsTokensDark.colors.text.mediumEmphasis);

        await tester.tap(find.text('Add'));
        await tester.pump();
        expect(pressed, 1);
      },
    );

    testWidgets(
      'a hint-only block renders no title tier — the deferential variant '
      'for panes whose sibling carries the message',
      (tester) async {
        await pump(
          tester,
          const DesignSystemEmptyState(
            icon: Icons.menu_book_outlined,
            hint: 'New entries will open here.',
          ),
        );

        expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
        final hint = tester.widget<Text>(
          find.text('New entries will open here.'),
        );
        expect(
          hint.style?.fontSize,
          dsTokensDark.typography.styles.others.caption.fontSize,
        );
        // No subtitle1-sized text anywhere in the block.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.style?.fontSize ==
                    dsTokensDark.typography.styles.subtitle.subtitle1.fontSize,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('title-only block renders no hint or action slot', (
      tester,
    ) async {
      await pump(
        tester,
        const DesignSystemEmptyState(
          icon: Icons.touch_app_outlined,
          title: 'Select a task',
        ),
      );

      expect(find.text('Select a task'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      // Exactly one Text: the title.
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
