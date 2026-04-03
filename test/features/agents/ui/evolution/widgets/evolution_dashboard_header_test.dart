import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  final testMetrics = RitualSummaryMetrics(
    lifetimeWakeCount: 42,
    wakesSinceLastSession: 7,
    totalTokenUsageSinceLastSession: 1234,
    meanTimeToResolution: const Duration(hours: 2),
    dailyWakeCounts: List.generate(
      5,
      (index) => DailyWakeCountBucket(
        date: DateTime(2024, 3, 10 + index),
        wakeCount: index + 1,
      ),
    ),
  );

  Widget buildSubject({
    String templateId = kTestTemplateId,
    FutureOr<RitualSummaryMetrics> Function()? metricsOverride,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionDashboardHeader(templateId: templateId),
      overrides: [
        ritualSummaryMetricsProvider.overrideWith(
          (ref, id) async => await (metricsOverride?.call() ?? testMetrics),
        ),
      ],
    );
  }

  group('EvolutionDashboardHeader', () {
    testWidgets('renders compact ritual summary content', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionDashboardHeader));

      expect(
        find.text(context.messages.agentEvolutionDashboardTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentRitualSummaryWakesSinceLast),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(context.messages.agentRitualSummaryTokensSinceLast),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.text(context.messages.agentRitualSummarySubtitle),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsSuccessRate),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentTemplateMetricsActiveInstances),
        findsNothing,
      );
      expect(
        find.text(context.messages.agentEvolutionMttrLabel),
        findsNothing,
      );
    });

    testWidgets('expands to show the wake activity chart', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EvolutionDashboardHeader));
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionWakeActivityChart), findsOneWidget);
      expect(find.text('Mar 10'), findsOneWidget);
      expect(find.text('Mar 14'), findsOneWidget);
    });

    testWidgets('renders nothing while metrics are loading', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: () => Completer<RitualSummaryMetrics>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(EvolutionWakeActivityChart), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders nothing when metrics loading fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          metricsOverride: () => Future<RitualSummaryMetrics>.error(
            Exception('boom'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionWakeActivityChart), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
    });
  });
}
