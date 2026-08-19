import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_menu_list_item.dart';

import '../../../../../test_utils/hover_divider_harness.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('CreateMenuListItem', () {
    Future<void> pump(
      WidgetTester tester, {
      String title = 'Write a note',
      String subtitle = 'Jot down details in a linked note.',
      bool opensSheet = false,
      VoidCallback? onTap,
      ValueChanged<bool>? onHoverChanged,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: LottiIcons.note,
            title: title,
            subtitle: subtitle,
            opensSheet: opensSheet,
            onTap: onTap ?? () {},
            onHoverChanged: onHoverChanged,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('is a DesignSystemListItem carrying the row content — the '
        'sheet rides the same component family as the first-run card', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byType(DesignSystemListItem), findsOneWidget);
      expect(find.text('Write a note'), findsOneWidget);
      expect(find.text('Jot down details in a linked note.'), findsOneWidget);
      expect(find.byIcon(LottiIcons.note), findsOneWidget);
    });

    testWidgets('trailing glyph says what the tap does: + creates in place, '
        'chevron opens another surface', (tester) async {
      await pump(tester);
      expect(find.byIcon(LottiIcons.add), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);

      await pump(tester, opensSheet: true);
      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
      expect(find.byIcon(LottiIcons.add), findsNothing);
    });

    testWidgets(
      'glyph colours follow the card contract: accent leading, '
      'mediumEmphasis trailing — the behavioural glyph must outrank the '
      'dividers it sits between',
      (tester) async {
        await pump(tester);

        final tokens = tester
            .element(find.byType(CreateMenuListItem))
            .designTokens;
        final leading = tester.widget<Icon>(find.byIcon(LottiIcons.note));
        final trailing = tester.widget<Icon>(find.byIcon(LottiIcons.add));

        expect(leading.color, tokens.colors.interactive.enabled);
        expect(leading.size, tokens.spacing.step5);
        expect(trailing.color, tokens.colors.text.mediumEmphasis);
        // step5, matching the leading glyph and the chevron: the plus and
        // the chevron must carry equal ink for the behavioural signal to
        // read in both directions.
        expect(trailing.size, tokens.spacing.step5);
      },
    );

    testWidgets('forwards taps', (tester) async {
      var tapped = 0;
      await pump(tester, onTap: () => tapped++);

      await tester.tap(find.byType(CreateMenuListItem));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets(
      'every row carries its subtitle — the two-line cadence is the '
      "component's contract, not the caller's choice",
      (tester) async {
        await pump(tester);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.subtitle, 'Jot down details in a linked note.');
      },
    );

    group('onHoverChanged', () {
      testWidgets(
        'reports pointer enter and leave — the sheet owns the hairlines '
        'bracketing this row and cannot see the pointer any other way',
        (tester) async {
          final reported = <bool>[];
          await pump(tester, onHoverChanged: reported.add);

          final gesture = await hoverListRow(
            tester,
            find.byType(CreateMenuListItem),
          );
          expect(reported, [true]);

          await unhoverRows(tester, gesture);
          expect(reported, [true, false]);
        },
      );

      testWidgets(
        'is optional — a row used outside a divided list passes none',
        (tester) async {
          await pump(tester);

          expect(
            tester
                .widget<DesignSystemListItem>(find.byType(DesignSystemListItem))
                .onHoverChanged,
            isNull,
          );
        },
      );
    });
  });
}
