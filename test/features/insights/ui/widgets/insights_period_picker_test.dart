import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_picker.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('tapping a day jumps the period to that date', (tester) async {
    final container = ProviderContainer(
      overrides: [
        // Synchronous so AsyncData lands at build time; an async override
        // resolves on a microtask and leaves Riverpod's refresh timer pending
        // past teardown.
        firstDayOfWeekIndexProvider.overrideWith(
          (ref) => DateTime.monday % 7,
        ),
      ],
    );
    addTearDown(container.dispose);

    await withClock(Clock.fixed(DateTime(2026, 6, 7, 16)), () async {
      // The default is month-to-date; switch to the current week (Jun 1–8,
      // Monday-start) so the picker tests a week-granularity jump and opens on
      // June 2026.
      container
          .read(insightsRangeControllerProvider.notifier)
          .selectUnit(InsightsPeriodUnit.week);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            const Material(child: InsightsPeriodPickerBody()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('15'));
      await tester.pump();
    });

    final selection = container.read(insightsRangeControllerProvider);
    // Mon 15 Jun 2026 is the Monday of the tapped day's week; the granularity
    // (week) is unchanged.
    expect(selection.unit.name, 'week');
    expect(dayStart(selection.range.startDay), DateTime(2026, 6, 15));
  });

  group('card height', () {
    /// Pumps the picker opened on the month containing [now].
    Future<void> pumpAt(WidgetTester tester, DateTime now) async {
      final container = ProviderContainer(
        overrides: [
          firstDayOfWeekIndexProvider.overrideWith(
            (ref) => DateTime.monday % 7,
          ),
        ],
      );
      addTearDown(container.dispose);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: makeTestableWidget2(
              const Material(child: InsightsPeriodPickerBody()),
            ),
          ),
        );
        await tester.pump();
      });
    }

    // Monday-first 2026 needs six week rows only in March, August and
    // November; every other month fits in five. Both directions of that
    // boundary have to hold the card still, so each test below pairs a
    // five-row month with a six-row one — pairing two five-row months would
    // pass with `reserveFullMonthHeight` switched back off.
    testWidgets('paging back from a 6-row to a 5-row month holds height', (
      tester,
    ) async {
      // March 2026 (six week rows) → February 2026 (five), via the backwards
      // chevron.
      await pumpAt(tester, DateTime(2026, 3, 15, 16));
      final march = tester.getSize(find.byType(GridView)).height;

      await tester.tap(find.byIcon(LottiIcons.chevronLeft));
      await tester.pump();

      expect(find.text('February 2026'), findsOneWidget);
      expect(tester.getSize(find.byType(GridView)).height, march);
    });

    testWidgets('paging from a 5-row to a 6-row month does not resize it', (
      tester,
    ) async {
      // February 2026 (five week rows) → March 2026 (six) is the step that
      // grew the card and moved the chevrons out from under the pointer.
      await pumpAt(tester, DateTime(2026, 2, 15, 16));
      final february = tester.getSize(find.byType(GridView)).height;

      await tester.tap(find.byIcon(LottiIcons.chevronRight));
      await tester.pump();

      expect(find.text('March 2026'), findsOneWidget);
      expect(tester.getSize(find.byType(GridView)).height, february);
    });
  });
}
