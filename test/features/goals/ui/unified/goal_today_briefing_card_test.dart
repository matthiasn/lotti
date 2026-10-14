import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/unified/goal_today_briefing_card.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';

void main() {
  AgentIdentityEntity identity(String id) => makeTestIdentity(
    id: id,
    agentId: id,
    kind: AgentKinds.goalAgent,
    displayName: 'Agent $id',
  );

  GoalAgentHealth health(GoalTrackStatus status) => (
    trackStatus: status,
    attainment: 0.5,
    reportOneLiner: null,
    pendingProposals: 0,
    spec: null,
    direction: null,
    deficit: null,
    buffer: null,
  );

  AgentReportEntity report(String oneLiner, List<String> steps) =>
      makeTestReport(
        oneLiner: oneLiner,
        provenance: {
          GoalReportProvenanceKeys.sections: {
            GoalReportSectionKeys.nextActions: steps,
          },
        },
      );

  List<Override> overrides({
    required Map<String, GoalTrackStatus> statuses,
    required Map<String, AgentReportEntity?> reports,
  }) => [
    for (final entry in statuses.entries)
      goalAgentHealthProvider(
        entry.key,
      ).overrideWith((ref) async => health(entry.value)),
    for (final entry in reports.entries)
      agentReportProvider(entry.key).overrideWith((ref) async => entry.value),
  ];

  testWidgets("lists each goal's read and first next step, the goal behind "
      'first, and opens a goal on tap', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: GoalTodayBriefingCard(
            identities: [identity('walk'), identity('sleep')],
          ),
        ),
        overrides: overrides(
          statuses: {
            'walk': GoalTrackStatus.onTrack,
            'sleep': GoalTrackStatus.offTrack,
          },
          reports: {
            'walk': report('Two walks this week.', ['Walk after lunch.']),
            'sleep': report('Three late nights.', ['Lights out by 23:00.']),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Next: Walk after lunch.'), findsOneWidget);
    expect(find.text('Next: Lights out by 23:00.'), findsOneWidget);
    // The goal behind comes first.
    expect(
      tester.getTopLeft(find.text('Agent sleep')).dy,
      lessThan(tester.getTopLeft(find.text('Agent walk')).dy),
    );
    // Each line wears the page's own status vocabulary.
    expect(find.byType(UnifiedGoalStatusPill), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('goal-today-briefing-walk')));
    expect(navigated, ['/goals/details/walk']);
  });

  testWidgets('with no goal briefed yet, the card takes no room at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalTodayBriefingCard(identities: [identity('walk')]),
        overrides: overrides(
          statuses: {'walk': GoalTrackStatus.onTrack},
          reports: {'walk': null},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('goal-today-briefing')), findsNothing);
    expect(find.text('Today'), findsNothing);
    expect(tester.getSize(find.byType(GoalTodayBriefingCard)), Size.zero);
  });
}
