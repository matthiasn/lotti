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
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  group('AgentsLocation', () {
    Future<List<BeamPage>> pagesFor(
      WidgetTester tester,
      String path, [
      Map<String, String> params = const {},
    ]) async {
      // Titles resolve through localizations, so buildPages needs a real
      // localized context rather than a mock.
      late BuildContext captured;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final routeInformation = RouteInformation(uri: Uri.parse(path));
      final location = AgentsLocation(routeInformation);
      final state = BeamState.fromRouteInformation(routeInformation);
      return location.buildPages(
        captured,
        state.copyWith(pathParameters: {...state.pathParameters, ...params}),
      );
    }

    test('pathPatterns cover list, create and detail', () {
      final location = AgentsLocation(
        RouteInformation(uri: Uri.parse('/agents')),
      );
      expect(location.pathPatterns, [
        '/agents',
        '/agents/create',
        '/agents/details/:agentId',
      ]);
    });

    testWidgets('the root path builds only the list page, localized', (
      tester,
    ) async {
      final pages = await pagesFor(tester, '/agents');
      expect(pages, hasLength(1));
      expect(pages.single.child, isA<AgentsPage>());
      expect(pages.single.title, 'Agents');
    });

    testWidgets('/agents/create stacks the creation page on the list', (
      tester,
    ) async {
      final pages = await pagesFor(tester, '/agents/create');
      expect(pages, hasLength(2));
      expect(pages.last.child, isA<CreateGoalAgentPage>());
      expect(pages.last.title, 'New goal agent');
    });

    testWidgets('a detail path stacks the detail page carrying the agent '
        'id', (tester) async {
      final pages = await pagesFor(tester, '/agents/details/goal-1', {
        'agentId': 'goal-1',
      });
      expect(pages, hasLength(2));
      final detail = pages.last.child as GoalAgentDetailPage;
      expect(detail.agentId, 'goal-1');
    });
  });

  group('AgentsLocation routing flows', () {
    late MockGoalAgentService service;
    late MockHabitsRepository habitsRepository;

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

    late BeamerDelegate delegate;

    Widget app() {
      delegate = BeamerDelegate(
        initialPath: '/agents',
        locationBuilder: (routeInformation, _) =>
            AgentsLocation(routeInformation),
      );
      // The pages navigate through NavService's beamToNamed so the shell
      // keeps currentPath and the persisted route in sync; here the flow
      // runs against a bare delegate.
      beamToNamedOverride = (path) => delegate.beamToNamed(path);
      addTearDown(() => beamToNamedOverride = null);
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
          agentReportHistoryProvider(
            'goal-fit',
          ).overrideWith((ref) async => []),
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

    setUpAll(() {
      registerAllFallbackValues();
      registerFallbackValue(
        const GoalCriterion.allOf(criterionId: 'f', criteria: []),
      );
    });

    setUp(() {
      service = MockGoalAgentService();
      habitsRepository = MockHabitsRepository();
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

    testWidgets('the FAB opens creation, and a successful create returns '
        'to the list', (tester) async {
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
  });
}
