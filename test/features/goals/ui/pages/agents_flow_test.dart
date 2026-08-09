import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/agents_location.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';

class _MockGoalAgentService extends Mock implements GoalAgentService {}

class _MockHabitsRepository extends Mock implements HabitsRepository {}

/// Drives the REAL router through the agents flow: list → detail, list →
/// create → (created) → back to the list. This is the navigation wiring
/// the per-page tests stub away.
void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const GoalCriterion.allOf(criterionId: 'f', criteria: []),
    );
  });

  late _MockGoalAgentService service;
  late _MockHabitsRepository habitsRepository;

  AgentIdentityEntity identity(String id, String name) =>
      AgentDomainEntity.agent(
            id: id,
            agentId: id,
            kind: AgentKinds.goalAgent,
            displayName: name,
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$id:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  Widget app() {
    final delegate = BeamerDelegate(
      initialPath: '/agents',
      locationBuilder: (routeInformation, _) =>
          AgentsLocation(routeInformation),
    );
    return ProviderScope(
      overrides: [
        activeGoalAgentsProvider.overrideWith(
          (ref) async => [identity('goal-fit', 'Expedition fitness')],
        ),
        goalAgentHealthProvider('goal-fit').overrideWith(
          (ref) async => (
            trackStatus: GoalTrackStatus.onTrack,
            attainment: 1.0,
            reportOneLiner: null,
            pendingProposals: 0,
            spec: null,
          ),
        ),
        selfTargetedPendingChangeSetsProvider(
          'goal-fit',
        ).overrideWith((ref) async => []),
        agentMessagesByThreadProvider(
          'goal-fit',
        ).overrideWith((ref) async => {}),
        agentReportHistoryProvider('goal-fit').overrideWith((ref) async => []),
        goalAgentServiceProvider.overrideWithValue(service),
        habitsRepositoryProvider.overrideWithValue(habitsRepository),
      ],
      child: MaterialApp.router(
        theme: resolveTestTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerDelegate: delegate,
        routeInformationParser: BeamerParser(),
      ),
    );
  }

  setUp(() {
    service = _MockGoalAgentService();
    habitsRepository = _MockHabitsRepository();
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => Stream.value(const <HabitDefinition>[]));
  });

  testWidgets('card tap opens the agent detail page', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expedition fitness'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalAgentDetailPage), findsOneWidget);
    expect(find.text('Interactions'), findsOneWidget);
  });

  testWidgets('the FAB opens creation, and a successful create returns to '
      'the list', (tester) async {
    when(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((_) async => identity('goal-new', 'Move more'));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New goal agent'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateGoalAgentPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Move more');
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateGoalAgentPage), findsNothing);
    expect(find.text('Expedition fitness'), findsOneWidget);
  });
}
