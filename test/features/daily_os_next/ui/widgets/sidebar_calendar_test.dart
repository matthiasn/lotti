import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DailyOsSidebarCalendar', () {
    Widget wrap({
      Set<DateTime> planDays = const {},
      List<DateTime>? requestedMonths,
    }) {
      return ProviderScope(
        overrides: [
          dailyOsPlanDaysProvider.overrideWith((ref, month) async {
            requestedMonths?.add(month);
            return planDays;
          }),
        ],
        child: makeTestableWidget2(
          const Material(
            child: Center(
              child: SizedBox(
                width: 280,
                child: DailyOsSidebarCalendar(),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(400, 800)),
        ),
      );
    }

    testWidgets(
      'feeds plan-day dots into the month calendar and starts on the '
      'selected month',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
          final requested = <DateTime>[];
          await tester.pumpWidget(
            wrap(
              planDays: {DateTime(2026, 5, 13)},
              requestedMonths: requested,
            ),
          );
          await tester.pump();

          expect(find.text('May 2026'), findsOneWidget);
          expect(requested, [DateTime(2026, 5)]);
          final calendar = tester.widget<SidebarMonthCalendar>(
            find.byType(SidebarMonthCalendar),
          );
          expect(calendar.markedDays, {DateTime(2026, 5, 13)});
        });
      },
    );

    testWidgets(
      'tapping a day selects it in the shared date provider',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
          await tester.pumpWidget(wrap());
          await tester.pump();

          await tester.tap(find.text('13'));
          await tester.pump();

          final container = ProviderScope.containerOf(
            tester.element(find.byType(DailyOsSidebarCalendar)),
          );
          expect(
            container.read(dailyOsNextSelectedDateProvider),
            DateTime(2026, 5, 13),
          );
        });
      },
    );

    testWidgets('month chevrons page the visible month and refetch dots', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
        final requested = <DateTime>[];
        await tester.pumpWidget(
          wrap(requestedMonths: requested),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pump();
        expect(find.text('June 2026'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pump();
        expect(find.text('April 2026'), findsOneWidget);

        expect(
          requested,
          containsAll([
            DateTime(2026, 5),
            DateTime(2026, 6),
            DateTime(2026, 4),
          ]),
        );
      });
    });
  });
}
