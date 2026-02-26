import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_charts_section.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_mttr_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_sparkline_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_version_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_wake_bar_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    FutureOr<WakeRunTimeSeries> Function(Ref, String)? timeSeriesOverride,
  }) {
    return makeTestableWidgetWithScaffold(
      const EvolutionChartsSection(templateId: kTestTemplateId),
      overrides: [
        templateWakeRunTimeSeriesProvider.overrideWith(
          timeSeriesOverride ??
              (ref, id) async => WakeRunTimeSeries(
                    dailyBuckets: _makeDaily(5),
                    versionBuckets: _makeVersions(3),
                  ),
        ),
      ],
    );
  }

  group('EvolutionChartsSection', () {
    testWidgets('renders 4 chart labels when data available', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChartsSection));
      expect(
        find.text(context.messages.agentEvolutionChartSuccessRateTrend),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionChartWakeHistory),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionChartVersionPerformance),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionChartMttrTrend),
        findsOneWidget,
      );
    });

    testWidgets('renders all 4 chart widget types', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionSparklineChart), findsOneWidget);
      expect(find.byType(EvolutionWakeBarChart), findsOneWidget);
      expect(find.byType(EvolutionVersionChart), findsOneWidget);
      expect(find.byType(EvolutionMttrChart), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when insufficient data',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          timeSeriesOverride: (ref, id) async => const WakeRunTimeSeries(
            dailyBuckets: [],
            versionBuckets: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionSparklineChart), findsNothing);
      expect(find.byType(EvolutionWakeBarChart), findsNothing);
    });

    testWidgets('renders SizedBox.shrink while loading', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          timeSeriesOverride: (ref, id) =>
              Completer<WakeRunTimeSeries>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      // During loading, no charts should be visible
      expect(find.byType(EvolutionSparklineChart), findsNothing);
    });

    testWidgets('renders SizedBox.shrink on error', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          timeSeriesOverride: (ref, id) =>
              Future<WakeRunTimeSeries>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionSparklineChart), findsNothing);
    });
  });
}

List<DailyWakeBucket> _makeDaily(int count) {
  return List.generate(
    count,
    (i) => DailyWakeBucket(
      date: DateTime(2024, 3, 15 + i),
      successCount: 8,
      failureCount: 2,
      successRate: 0.8,
      averageDuration: Duration(seconds: 10 + i),
    ),
  );
}

List<VersionPerformanceBucket> _makeVersions(int count) {
  return List.generate(
    count,
    (i) => VersionPerformanceBucket(
      versionId: 'v${i + 1}',
      versionNumber: i + 1,
      totalRuns: 10,
      successRate: 0.7 + i * 0.1,
      averageDuration: const Duration(seconds: 10),
    ),
  );
}
