import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_picker.dart';
import 'package:lotti/utils/device_region.dart';

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
      // Default selection is the current week (Jun 1–7 2026), so the picker
      // opens on June 2026.
      container.read(insightsRangeControllerProvider);
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
}
