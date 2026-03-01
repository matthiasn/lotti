import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_charts_section.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_history_dashboard.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    FutureOr<EvolutionSessionStats> Function(Ref, String)? statsOverride,
    FutureOr<List<AgentDomainEntity>> Function(Ref, String)? sessionsOverride,
    FutureOr<WakeRunTimeSeries> Function(Ref, String)? timeSeriesOverride,
    FutureOr<TaskResolutionTimeSeries> Function(Ref, String)?
        resolutionOverride,
  }) {
    return makeTestableWidgetWithScaffold(
      const EvolutionHistoryDashboard(templateId: kTestTemplateId),
      overrides: [
        evolutionSessionStatsProvider.overrideWith(
          statsOverride ??
              (ref, id) async => const EvolutionSessionStats(
                    totalSessions: 0,
                    completedCount: 0,
                    abandonedCount: 0,
                    approvalRate: 0,
                  ),
        ),
        evolutionSessionsProvider.overrideWith(
          sessionsOverride ?? (ref, id) async => [],
        ),
        templateWakeRunTimeSeriesProvider.overrideWith(
          timeSeriesOverride ??
              (ref, id) async => const WakeRunTimeSeries(
                    dailyBuckets: [],
                    versionBuckets: [],
                  ),
        ),
        templateTaskResolutionTimeSeriesProvider.overrideWith(
          resolutionOverride ??
              (ref, id) async =>
                  const TaskResolutionTimeSeries(dailyBuckets: []),
        ),
      ],
    );
  }

  group('EvolutionHistoryDashboard', () {
    testWidgets('shows evolution history title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionHistoryTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows session history section label', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentRitualReviewSessionHistory),
        findsOneWidget,
      );
    });

    testWidgets('includes EvolutionChartsSection child', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChartsSection), findsOneWidget);
    });

    testWidgets('includes EvolutionSessionTimeline child', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionSessionTimeline), findsOneWidget);
    });

    testWidgets('stats row shows total session count', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 7,
            completedCount: 5,
            abandonedCount: 2,
            approvalRate: 0.71,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('stats row shows sessions label', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 3,
            completedCount: 2,
            abandonedCount: 1,
            approvalRate: 0.67,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionSessionCount),
        findsOneWidget,
      );
    });

    testWidgets('stats row shows approval rate label', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 4,
            completedCount: 3,
            abandonedCount: 1,
            approvalRate: 0.75,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionApprovalRate),
        findsOneWidget,
      );
    });

    testWidgets('stats row shows formatted approval rate percentage',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 4,
            completedCount: 2,
            abandonedCount: 2,
            approvalRate: 0.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // approvalRate 0.5 → 50%
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('stats row rounds approval rate to nearest integer percent',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 3,
            completedCount: 2,
            abandonedCount: 1,
            approvalRate: 0.6666,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // (0.6666 * 100).toStringAsFixed(0) == '67'
      expect(find.text('67%'), findsOneWidget);
    });

    testWidgets('shows empty SizedBox (no crash) while stats loading',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) => Completer<EvolutionSessionStats>().future,
        ),
      );
      await tester.pump();

      // Dashboard title still shown; stats row is an empty SizedBox(height:48)
      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionHistoryTitle),
        findsOneWidget,
      );
      // Session count chip not yet visible
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows session timeline with sessions from provider',
        (tester) async {
      final sessions = <AgentDomainEntity>[
        makeTestEvolutionSession(
          id: 'evo-1',
          status: EvolutionSessionStatus.completed,
          createdAt: DateTime(2024, 3, 15, 10, 30),
        ),
        makeTestEvolutionSession(
          id: 'evo-2',
          sessionNumber: 2,
          // ignore: avoid_redundant_argument_values
          status: EvolutionSessionStatus.active,
          createdAt: DateTime(2024, 3, 20, 9),
        ),
      ];

      await tester.pumpWidget(
        buildSubject(
          sessionsOverride: (ref, id) async => sessions,
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 2,
            completedCount: 1,
            abandonedCount: 1,
            approvalRate: 0.5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(1)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentEvolutionSessionTitle(2)),
        findsOneWidget,
      );
    });

    testWidgets(
        'stats row hides on error (renders SizedBox.shrink), '
        'rest of dashboard still visible', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) =>
              Future<EvolutionSessionStats>.error(Exception('db error')),
        ),
      );
      await tester.pumpAndSettle();

      // Title and session-history label still present
      final context = tester.element(find.byType(EvolutionHistoryDashboard));
      expect(
        find.text(context.messages.agentEvolutionHistoryTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentRitualReviewSessionHistory),
        findsOneWidget,
      );
      // No stat chips rendered
      expect(
        find.text(context.messages.agentEvolutionSessionCount),
        findsNothing,
      );
    });

    testWidgets('zero approval rate shown as 0%', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 3,
            completedCount: 0,
            abandonedCount: 3,
            approvalRate: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('100% approval rate shown as 100%', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          statsOverride: (ref, id) async => const EvolutionSessionStats(
            totalSessions: 5,
            completedCount: 5,
            abandonedCount: 0,
            approvalRate: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
    });
  });
}
