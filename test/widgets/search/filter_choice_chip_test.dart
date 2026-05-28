import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

import '../../widget_test_utils.dart';

void main() {
  group('FilterChoiceChip', () {
    Widget pump({required bool isSelected}) {
      return makeTestableWidgetWithScaffold(
        FilterChoiceChip(
          label: 'Inbox',
          isSelected: isSelected,
          onTap: () {},
          selectedColor: Colors.blue,
        ),
        theme: DesignSystemTheme.light(),
      );
    }

    testWidgets(
      'labelPadding nudges the label step1 past the chip start so the text '
      'does not sit flush against the leading border',
      (tester) async {
        await tester.pumpWidget(pump(isSelected: false));

        final chip = tester.widget<Chip>(
          find.descendant(
            of: find.byType(FilterChoiceChip),
            matching: find.byType(Chip),
          ),
        );

        final tokens = tester
            .element(find.byType(FilterChoiceChip))
            .designTokens;

        // Directional so the nudge follows reading order in RTL locales.
        expect(
          chip.labelPadding,
          EdgeInsetsDirectional.only(
            start: tokens.spacing.step3 + tokens.spacing.step1,
            end: tokens.spacing.step3,
          ),
        );
      },
    );

    testWidgets(
      'left nudge is applied identically whether the chip is selected or not',
      (tester) async {
        await tester.pumpWidget(pump(isSelected: false));
        final unselectedRect = tester.getRect(find.text('Inbox'));

        await tester.pumpWidget(pump(isSelected: true));
        final selectedRect = tester.getRect(find.text('Inbox'));

        // Selecting only swaps the fill colour and text colour; it must
        // not shift the label horizontally.
        expect(selectedRect.left, unselectedRect.left);
      },
    );

    testWidgets(
      'tap invokes onTap and long-press invokes onLongPress',
      (tester) async {
        var tapped = 0;
        var longPressed = 0;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            FilterChoiceChip(
              label: 'Work',
              isSelected: false,
              onTap: () => tapped++,
              onLongPress: () => longPressed++,
              selectedColor: Colors.green,
            ),
            theme: DesignSystemTheme.light(),
          ),
        );

        await tester.tap(find.text('Work'));
        await tester.pump();
        expect(tapped, 1);
        expect(longPressed, 0);

        await tester.longPress(find.text('Work'));
        await tester.pump();
        expect(tapped, 1);
        expect(longPressed, 1);
      },
    );
  });
}
