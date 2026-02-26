import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_charts_section.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    FutureOr<TemplatePerformanceMetrics> Function(Ref, String)? metricsOverride,
    FutureOr<WakeRunTimeSeries> Function(Ref, String)? timeSeriesOverride,
  }) {
    final testMetrics = makeTestMetrics(templateId: templateId);
    return makeTestableWidgetWithScaffold(
      EvolutionDashboardHeader(templateId: templateId),
      overrides: [
        templatePerformanceMetricsProvider.overrideWith(
          metricsOverride ?? (ref, id) async => testMetrics,
        ),
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

  group('EvolutionDashboardHeader', () {
    testWidgets('shows dashboard title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));
      expect(
        find.text(context.messages.agentEvolutionDashboardTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows metric tiles when data available', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));
      // Should show success rate, total wakes, active instances, and MTTR
      expect(
        find.text(context.messages.agentTemplateMetricsSuccessRate),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsTotalWakes),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsActiveInstances),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionMttrLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows no metrics message when totalWakes is 0',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: (ref, id) async => makeTestMetrics(
            totalWakes: 0,
            successCount: 0,
            failureCount: 0,
            successRate: 0,
            activeInstanceCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));
      expect(
        find.text(context.messages.agentTemplateNoMetrics),
        findsOneWidget,
      );
    });

    testWidgets('collapses and expands on tap', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));

      // Initially expanded — metric tiles visible
      expect(
        find.text(context.messages.agentTemplateMetricsSuccessRate),
        findsOneWidget,
      );

      // Tap to collapse
      await tester.tap(
        find.text(context.messages.agentEvolutionDashboardTitle),
      );
      await tester.pumpAndSettle();

      // After collapse, metrics should not be visible
      // (AnimatedSize shrinks to zero)
      expect(
        find.text(context.messages.agentTemplateMetricsSuccessRate),
        findsNothing,
      );

      // Tap to expand again
      await tester.tap(
        find.text(context.messages.agentEvolutionDashboardTitle),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentTemplateMetricsSuccessRate),
        findsOneWidget,
      );
    });

    testWidgets('shows loading indicator while metrics load', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: (ref, id) =>
              Completer<TemplatePerformanceMetrics>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows N/A for MTTR when averageDuration is null',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: (ref, id) async => makeTestMetrics(
            averageDuration: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('shows charts section when expanded with data', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChartsSection), findsOneWidget);
    });

    testWidgets('hides charts section when collapsed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));

      // Tap to collapse
      await tester.tap(
        find.text(context.messages.agentEvolutionDashboardTitle),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChartsSection), findsNothing);
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
