import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_month_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/sidebar_subsection.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('DailyOsSidebarCalendar', () {
    Widget wrap({
      Widget child = const DailyOsSidebarCalendar(),
      Set<DateTime> planDays = const {},
      List<DateTime>? requestedMonths,
      int firstDayOfWeekIndex = 1,
    }) {
      return ProviderScope(
        overrides: [
          dailyOsPlanDaysProvider.overrideWith((ref, month) async {
            requestedMonths?.add(month);
            return planDays;
          }),
          firstDayOfWeekIndexProvider.overrideWith(
            (ref) async => firstDayOfWeekIndex,
          ),
        ],
        child: makeTestableWidget2(
          Material(
            child: Center(
              child: SizedBox(
                width: 280,
                child: child,
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
      'feeds the region-derived first weekday into the month calendar',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
          // A US device resolves to a Sunday-first week (index 0).
          await tester.pumpWidget(wrap(firstDayOfWeekIndex: 0));
          await tester.pump();

          final calendar = tester.widget<SidebarMonthCalendar>(
            find.byType(SidebarMonthCalendar),
          );
          expect(calendar.firstDayOfWeekIndex, 0);
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

    testWidgets(
      'visible month snaps to the selection when another surface changes it',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
          await tester.pumpWidget(wrap());
          await tester.pump();
          expect(find.text('May 2026'), findsOneWidget);

          final container = ProviderScope.containerOf(
            tester.element(find.byType(DailyOsSidebarCalendar)),
          );
          container
              .read(dailyOsNextSelectedDateProvider.notifier)
              .select(DateTime(2026, 7, 4));
          await tester.pump();

          expect(find.text('July 2026'), findsOneWidget);
          expect(find.text('May 2026'), findsNothing);
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

    testWidgets(
      'groups the calendar and Time Analysis action in one token-backed '
      'subsection surface',
      (tester) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 24, 9)), () async {
          final navService = MockNavService();
          final showTimeAnalysis = ValueNotifier<bool>(false);
          when(
            () => navService.desktopShowTimeAnalysis,
          ).thenReturn(showTimeAnalysis);
          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<NavService>(navService);
            },
          );
          addTearDown(() async {
            showTimeAnalysis.dispose();
            await tearDownTestGetIt();
          });

          await tester.pumpWidget(
            wrap(child: const DailyOsSidebarSection()),
          );
          await tester.pump();

          expect(find.byKey(DailyOsSidebarSectionKeys.root), findsOneWidget);
          expect(find.byType(SidebarSubsectionSurface), findsOneWidget);
          expect(find.byType(SidebarSubsectionAction), findsOneWidget);
          expect(find.byType(SidebarMonthCalendar), findsOneWidget);
          expect(find.text('Time Analysis'), findsOneWidget);

          final tokens = tester
              .element(find.byType(DailyOsSidebarSection))
              .designTokens;
          final surface = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(SidebarSubsectionSurface),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final decoration = surface.decoration as BoxDecoration;
          expect(decoration.color, tokens.colors.surface.enabled);
          expect(decoration.border, isNull);

          expect(
            tester.getTopLeft(find.byType(SidebarMonthCalendar)).dy,
            lessThan(tester.getTopLeft(find.text('Time Analysis')).dy),
            reason:
                'The calendar should read as the parent control above '
                'the Time Analysis action.',
          );
        });
      },
    );
  });
}
