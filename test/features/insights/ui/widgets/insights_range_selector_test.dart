import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_range_selector.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const desktopMq = MediaQueryData(size: Size(1280, 900));
  final now = DateTime(2026, 6, 7, 16);

  Future<void> pumpSelector(
    WidgetTester tester, {
    required InsightsRange range,
    ValueChanged<InsightsRangePreset>? onPreset,
    void Function(DateTime, DateTime)? onCustom,
  }) {
    return tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsRangeSelector(
          range: range,
          onPresetSelected: onPreset ?? (_) {},
          onCustomRangeSelected: onCustom ?? (_, _) {},
        ),
      ),
    );
  }

  testWidgets('renders all six preset pills and the active range label', (
    tester,
  ) async {
    await pumpSelector(
      tester,
      range: resolvePreset(InsightsRangePreset.d7, now),
    );

    for (final label in ['1d', '7d', '30d', 'MTD', 'YTD', 'Last month']) {
      expect(find.text(label), findsOneWidget);
    }
    // Jun 1 – Jun 7 for the trailing week ending Sunday Jun 7 2026.
    expect(find.text('Jun 1 – Jun 7'), findsOneWidget);
  });

  testWidgets('marks exactly the active preset as selected', (tester) async {
    // getSemantics requires an active semantics client; without the
    // handle the semantics tree may not be generated on all platforms.
    // Disposed in the test body — teardown runs after the framework's
    // end-of-test handle verification.
    final semanticsHandle = tester.ensureSemantics();
    await pumpSelector(
      tester,
      range: resolvePreset(InsightsRangePreset.ytd, now),
    );

    final semantics = tester.getSemantics(
      find
          .ancestor(
            of: find.text('YTD'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);

    final unselected = tester.getSemantics(
      find
          .ancestor(
            of: find.text('7d'),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(unselected.flagsCollection.isSelected, isNot(Tristate.isTrue));
    semanticsHandle.dispose();
  });

  testWidgets('tapping a preset pill reports the preset', (tester) async {
    final selected = <InsightsRangePreset>[];
    await pumpSelector(
      tester,
      range: resolvePreset(InsightsRangePreset.d7, now),
      onPreset: selected.add,
    );

    await tester.tap(find.text('30d'));
    await tester.tap(find.text('Last month'));
    expect(selected, [InsightsRangePreset.d30, InsightsRangePreset.lastMonth]);
  });

  testWidgets('single-day ranges render a single-date label', (tester) async {
    await pumpSelector(
      tester,
      range: resolvePreset(InsightsRangePreset.d1, now),
    );
    expect(find.text('Jun 7'), findsOneWidget);
  });

  testWidgets(
    'the range button opens the date-range picker and confirms a pick',
    (tester) async {
      final picks = <(DateTime, DateTime)>[];
      await pumpSelector(
        tester,
        range: InsightsRange(
          startDay: epochDay(DateTime(2026, 6)),
          endDayExclusive: epochDay(DateTime(2026, 6, 4)),
        ),
        onCustom: (a, b) => picks.add((a, b)),
      );

      await tester.tap(find.text('Jun 1 – Jun 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Material date range picker is shown with the current range.
      expect(find.byType(TextButton), findsWidgets);
      // Confirm via the save button without changing the selection.
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(picks, hasLength(1));
      expect(picks.single.$1, DateTime(2026, 6));
      expect(picks.single.$2, DateTime(2026, 6, 3));
    },
  );
}
