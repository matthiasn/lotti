import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(
    child: Center(child: SizedBox(width: 280, child: child)),
  ),
  mediaQueryData: const MediaQueryData(size: Size(400, 800)),
);

void main() {
  group('SidebarMonthCalendar', () {
    testWidgets(
      'renders the month header, all days of the month, and chevrons',
      (tester) async {
        var previous = 0;
        var next = 0;
        await tester.pumpWidget(
          _wrap(
            SidebarMonthCalendar(
              month: DateTime(2026, 5),
              today: DateTime(2026, 5, 24),
              onPreviousMonth: () => previous++,
              onNextMonth: () => next++,
              onDaySelected: (_) {},
            ),
          ),
        );

        expect(find.text('May 2026'), findsOneWidget);
        // May has 31 days; spot-check first/last plus today.
        expect(find.text('1'), findsOneWidget);
        expect(find.text('31'), findsOneWidget);
        expect(find.text('24'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        expect(previous, 1);
        expect(next, 1);
      },
    );

    testWidgets('today is highlighted with the teal circle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarMonthCalendar(
            month: DateTime(2026, 5),
            today: DateTime(2026, 5, 24),
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: (_) {},
          ),
        ),
      );

      final context = tester.element(find.byType(SidebarMonthCalendar));
      final tokens = context.designTokens;
      final todayLabel = tester.widget<Text>(find.text('24'));
      expect(
        todayLabel.style?.color,
        tokens.colors.text.onInteractiveAlert,
      );
      // A non-today day keeps the medium-emphasis number.
      final otherLabel = tester.widget<Text>(find.text('10'));
      expect(otherLabel.style?.color, tokens.colors.text.mediumEmphasis);
    });

    testWidgets('tapping a day reports its local midnight', (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        _wrap(
          SidebarMonthCalendar(
            month: DateTime(2026, 5),
            today: DateTime(2026, 5, 24),
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: (day) => selected = day,
          ),
        ),
      );

      await tester.tap(find.text('13'));
      expect(selected, DateTime(2026, 5, 13));
    });

    testWidgets(
      'a marked today renders its dot in the on-interactive contrast color',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SidebarMonthCalendar(
              month: DateTime(2026, 5),
              today: DateTime(2026, 5, 24),
              markedDays: {DateTime(2026, 5, 24)},
              onPreviousMonth: () {},
              onNextMonth: () {},
              onDaySelected: (_) {},
            ),
          ),
        );

        final context = tester.element(find.byType(SidebarMonthCalendar));
        final tokens = context.designTokens;
        final todayCell = find
            .ancestor(of: find.text('24'), matching: find.byType(Stack))
            .first;
        final dotColors = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: todayCell,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => (box.decoration as BoxDecoration).color)
            .toList();
        // Teal today-circle + a dot in the contrast color on top of it.
        expect(dotColors, contains(tokens.colors.interactive.enabled));
        expect(dotColors, contains(tokens.colors.text.onInteractiveAlert));
      },
    );

    testWidgets('marked days carry a plan dot; unmarked days do not', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarMonthCalendar(
            month: DateTime(2026, 5),
            today: DateTime(2026, 5, 24),
            markedDays: {DateTime(2026, 5, 13, 15, 30)},
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: (_) {},
          ),
        ),
      );

      // The marked day's cell stacks number + dot; compare descendant
      // DecoratedBox counts between a marked and an unmarked cell.
      Finder cellOf(String day) => find.ancestor(
        of: find.text(day),
        matching: find.byType(Stack),
      );
      final markedBoxes = tester
          .widgetList(
            find.descendant(
              of: cellOf('13').first,
              matching: find.byType(DecoratedBox),
            ),
          )
          .length;
      final unmarkedBoxes = tester
          .widgetList(
            find.descendant(
              of: cellOf('10').first,
              matching: find.byType(DecoratedBox),
            ),
          )
          .length;
      expect(markedBoxes, unmarkedBoxes + 1);
    });
  });
}
