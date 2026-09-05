import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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

        await tester.tap(find.byIcon(LottiIcons.chevronLeft));
        await tester.tap(find.byIcon(LottiIcons.chevronRight));
        expect(previous, 1);
        expect(next, 1);
      },
    );

    testWidgets(
      'injected firstDayOfWeekIndex shifts the grid (Monday vs Sunday start)',
      (tester) async {
        Future<double> dayOneDx(int firstDayOfWeekIndex) async {
          await tester.pumpWidget(
            _wrap(
              SidebarMonthCalendar(
                month: DateTime(2026, 5),
                today: DateTime(2026, 5, 24),
                firstDayOfWeekIndex: firstDayOfWeekIndex,
                onPreviousMonth: () {},
                onNextMonth: () {},
                onDaySelected: (_) {},
              ),
            ),
          );
          return tester.getCenter(find.text('1')).dx;
        }

        // 1 May 2026 is a Friday. With a Monday-start week it sits in the 5th
        // column; switching to a Sunday-start week shifts it one column right.
        final mondayStartDx = await dayOneDx(DateTime.monday % 7); // 1
        final sundayStartDx = await dayOneDx(DateTime.sunday % 7); // 0
        expect(sundayStartDx, greaterThan(mondayStartDx));
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

    testWidgets('exposes each day with its full date and independent states', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SidebarMonthCalendar(
            month: DateTime(2026, 5),
            today: DateTime(2026, 5, 24),
            selectedDay: DateTime(2026, 5, 13),
            markedDays: {DateTime(2026, 5, 13), DateTime(2026, 5, 24)},
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('May 2026')),
        matchesSemantics(label: 'May 2026', isHeader: true),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Wednesday, May 13, 2026, Has plan'),
        ),
        matchesSemantics(
          label: 'Wednesday, May 13, 2026, Has plan',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Sunday, May 24, 2026, Today, Has plan'),
        ),
        matchesSemantics(
          label: 'Sunday, May 24, 2026, Today, Has plan',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );

      semantics.dispose();
    });

    testWidgets('semantic day activation reports its local midnight', (
      tester,
    ) async {
      final selectedDays = <DateTime>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          SidebarMonthCalendar(
            month: DateTime(2026, 5),
            today: DateTime(2026, 5, 24),
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: selectedDays.add,
          ),
        ),
      );

      final day = tester.getSemantics(
        find.bySemanticsLabel('Wednesday, May 13, 2026'),
      );
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        day.id,
        SemanticsAction.tap,
      );
      await tester.pump();

      final expectedDay = DateTime(2026, 5, 13);
      expect(selectedDays, [expectedDay]);

      await tester.tap(find.text('13'));
      expect(selectedDays, [expectedDay, expectedDay]);
      semantics.dispose();
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

      final tokens = tester
          .element(find.byType(SidebarMonthCalendar))
          .designTokens;
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
      expect(
        find.descendant(
          of: cellOf('13').first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == tokens.spacing.step2 &&
                widget.height == tokens.spacing.step2,
          ),
        ),
        findsOneWidget,
      );
    });

    // A month occupies four to six week rows depending on its length and
    // starting weekday, so an unpadded grid changes height as the host pages
    // through months. [reserveFullMonthHeight] pads every month out to the
    // six-row worst case.
    group('reserveFullMonthHeight', () {
      /// Rendered height of the day grid for [month].
      Future<double> gridHeight(
        WidgetTester tester,
        DateTime month, {
        required bool reserve,
        int firstDayOfWeekIndex = 1,
      }) async {
        await tester.pumpWidget(
          _wrap(
            SidebarMonthCalendar(
              month: month,
              today: DateTime(2026, 2, 15),
              firstDayOfWeekIndex: firstDayOfWeekIndex,
              reserveFullMonthHeight: reserve,
              onPreviousMonth: () {},
              onNextMonth: () {},
              onDaySelected: (_) {},
            ),
          ),
        );
        return tester.getSize(find.byType(GridView)).height;
      }

      // Monday-first 2026: February needs five week rows, March six — the
      // pair that made the picker card jump a whole row mid-browse.
      testWidgets('a short and a long month render at the same height', (
        tester,
      ) async {
        final february = await gridHeight(
          tester,
          DateTime(2026, 2),
          reserve: true,
        );
        final march = await gridHeight(
          tester,
          DateTime(2026, 3),
          reserve: true,
        );

        expect(february, march);
      });

      testWidgets('without it those months differ — the defect', (
        tester,
      ) async {
        final february = await gridHeight(
          tester,
          DateTime(2026, 2),
          reserve: false,
        );
        final march = await gridHeight(
          tester,
          DateTime(2026, 3),
          reserve: false,
        );

        expect(february, lessThan(march));
      });

      testWidgets('every month of a year renders at one height', (
        tester,
      ) async {
        final heights = <double>{};
        for (var month = 1; month <= 12; month++) {
          heights.add(
            await gridHeight(tester, DateTime(2026, month), reserve: true),
          );
        }

        expect(heights, hasLength(1));
      });

      testWidgets('holds a six-week month without clipping a day', (
        tester,
      ) async {
        // March 2026 starts on a Sunday and has 31 days — the case that spills
        // into a sixth week. The padding must not displace the real days.
        await gridHeight(tester, DateTime(2026, 3), reserve: true);

        expect(find.text('1'), findsOneWidget);
        expect(find.text('31'), findsOneWidget);
      });

      testWidgets('the reserved space is empty, not extra tappable days', (
        tester,
      ) async {
        // February has 28 days; the padding must add blanks, not cells that
        // would answer to a tap or read out to a screen reader.
        final tapped = <DateTime>[];
        await tester.pumpWidget(
          _wrap(
            SidebarMonthCalendar(
              month: DateTime(2026, 2),
              today: DateTime(2026, 2, 15),
              firstDayOfWeekIndex: 1,
              reserveFullMonthHeight: true,
              onPreviousMonth: () {},
              onNextMonth: () {},
              onDaySelected: tapped.add,
            ),
          ),
        );

        expect(find.text('29'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(InkWell),
          ),
          findsNWidgets(28),
        );

        // Monday-first February 2026 starts on a Sunday, so the day cells run
        // from index 6 to 33 of the 42-cell grid and the whole sixth week row
        // is padding. Tapping into it must reach nothing — a padding cell that
        // was a real `_DayCell` would report a day here.
        final grid = tester.getRect(find.byType(GridView));
        final rowHeight = grid.height / 7; // weekday header + six week rows
        await tester.tapAt(
          Offset(grid.center.dx, grid.bottom - rowHeight / 2),
        );
        await tester.pump();

        expect(tapped, isEmpty);
      });

      testWidgets('a Sunday-first region is padded to the same height', (
        tester,
      ) async {
        // The leading blank count differs by region, so the trailing padding
        // has to be derived from it rather than assumed.
        final monday = await gridHeight(
          tester,
          DateTime(2026, 5),
          reserve: true,
        );
        final sunday = await gridHeight(
          tester,
          DateTime(2026, 5),
          reserve: true,
          firstDayOfWeekIndex: 0,
        );

        expect(monday, sunday);
      });
    });
  });
}
