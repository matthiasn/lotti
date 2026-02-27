import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/ui/widgets/outbox/outbox_volume_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../widget_test_utils.dart';

Future<void> _pumpVolumeChart(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const OutboxVolumeChart(),
      overrides: overrides,
    ),
  );
}

void main() {
  group('OutboxVolumeChart', () {
    setUp(setUpTestGetIt);
    tearDown(tearDownTestGetIt);

    testWidgets('shows loading indicator while provider is loading',
        (tester) async {
      final completer = Completer<List<Observation>>();

      await _pumpVolumeChart(
        tester,
        overrides: [
          outboxDailyVolumeProvider.overrideWith(
            (ref) => completer.future,
          ),
        ],
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TimeSeriesBarChart), findsNothing);
    });

    testWidgets('renders bar chart with volume data', (tester) async {
      final observations = [
        Observation(DateTime(2024, 3, 15), 100),
        Observation(DateTime(2024, 3, 16), 200),
        Observation(DateTime(2024, 3, 17), 150),
      ];

      await _pumpVolumeChart(
        tester,
        overrides: [
          outboxDailyVolumeProvider.overrideWith(
            (ref) async => observations,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeSeriesBarChart), findsOneWidget);
      expect(find.text('Daily sync volume'), findsOneWidget);
    });

    testWidgets('passes correct properties to TimeSeriesBarChart',
        (tester) async {
      final observations = [
        Observation(DateTime(2024, 3, 15), 100),
        Observation(DateTime(2024, 3, 16), 200),
      ];

      await _pumpVolumeChart(
        tester,
        overrides: [
          outboxDailyVolumeProvider.overrideWith(
            (ref) async => observations,
          ),
        ],
      );
      await tester.pumpAndSettle();

      final chart = tester.widget<TimeSeriesBarChart>(
        find.byType(TimeSeriesBarChart),
      );
      expect(chart.data, equals(observations));
      expect(chart.unit, 'KB');
      // Range covers 30 days ending tomorrow
      final rangeDays = chart.rangeEnd.difference(chart.rangeStart).inDays;
      expect(rangeDays, 30);
    });

    testWidgets('hides when data is empty', (tester) async {
      await _pumpVolumeChart(
        tester,
        overrides: [
          outboxDailyVolumeProvider.overrideWith(
            (ref) async => <Observation>[],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeSeriesBarChart), findsNothing);
      expect(find.text('Daily sync volume'), findsNothing);
    });

    testWidgets('shows generic error text with error color', (tester) async {
      await _pumpVolumeChart(
        tester,
        overrides: [
          outboxDailyVolumeProvider.overrideWith(
            (ref) async => throw Exception('Database error'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(TimeSeriesBarChart), findsNothing);
      // Shows generic localized error, not the raw exception message
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Database error'), findsNothing);

      final errorText = tester.widget<Text>(find.text('Error'));
      final context = tester.element(find.byType(OutboxVolumeChart));
      final expectedColor = Theme.of(context).colorScheme.error;
      expect(errorText.style?.color, expectedColor);
    });
  });
}
