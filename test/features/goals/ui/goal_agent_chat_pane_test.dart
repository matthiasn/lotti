import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/goal_record_offer_card.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  testWidgets('identifies the agent and its goal above the durable composer', (
    tester,
  ) async {
    final identity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.goalAgent,
              displayName: 'Juno',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'goal-1:state',
              config: const AgentConfig(),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Fitness',
              statement: 'Show up for three workouts each week.',
              criteria: const GoalCriterion.habit(
                criterionId: 'gym',
                habitId: 'gym',
                window: GoalWindow.rollingDays(count: 7),
                targetCount: 3,
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentChatPane(agentId: 'goal-1')),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
          goalAgentHealthProvider('goal-1').overrideWith(
            (ref) async => (
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1.0,
              reportOneLiner: null,
              pendingProposals: 0,
              spec: spec,
              direction: null,
              deficit: null,
              buffer: null,
            ),
          ),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juno'), findsOneWidget);
    // The subtitle is current STATE, not the aspiration statement — the
    // statement next to a Behind chip elsewhere read as a status claim.
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Not enough data'), findsNothing);
    expect(
      find.text('Show up for three workouts each week.'),
      findsNothing,
    );
    expect(find.text('Talk to Juno…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'What should I do today?');
    await tester.pump();
    expect(find.byIcon(LottiIcons.send), findsOneWidget);
  });

  testWidgets('an unresolved health load shows NO coarse label — loading is '
      'not a data-gap verdict', (tester) async {
    final identity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.goalAgent,
              displayName: 'Juno',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'goal-1:state',
              config: const AgentConfig(),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: GoalAgentChatPane(agentId: 'goal-1')),
        overrides: [
          agentIdentityProvider(
            'goal-1',
          ).overrideWith((ref) async => identity),
          // Never resolves: the first health load is still in flight.
          goalAgentHealthProvider(
            'goal-1',
          ).overrideWith((ref) => Completer<GoalAgentHealth>().future),
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Juno'), findsOneWidget);
    expect(find.text('Not enough data'), findsNothing);
    expect(find.text('On track'), findsNothing);
  });

  testWidgets('user turns get a receipt, nothing, or an offer card depending '
      'on the recorded decision and on what they said', (tester) async {
    // Tall enough that the lazily built history lays out every turn.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 8, 12, 10);
    final identity =
        AgentDomainEntity.agent(
              id: 'goal-1',
              agentId: 'goal-1',
              kind: AgentKinds.goalAgent,
              displayName: 'Juno',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'goal-1:state',
              config: const AgentConfig(),
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              vectorClock: null,
            )
            as AgentIdentityEntity;
    final spec =
        AgentDomainEntity.goalSpecVersion(
              id: 'goal-1:spec-v1',
              agentId: 'goal-1',
              version: 1,
              status: GoalSpecVersionStatus.active,
              authoredBy: 'user',
              title: 'Reading',
              statement: 'Read sixty pages a week.',
              criteria: const GoalCriterion.measurable(
                criterionId: 'reading',
                dataTypeId: 'pages',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.sum,
                target: 60,
              ),
              createdAt: DateTime(2026),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final pages = MeasurableDataType(
      id: 'pages',
      createdAt: now,
      updatedAt: now,
      displayName: 'Pages read',
      description: '',
      unitName: 'pages',
      version: 1,
      vectorClock: null,
    );
    AgentChatMessage message(String id, String text, {AgentChatRole? role}) =>
        AgentChatMessage(
          id: id,
          role: role ?? AgentChatRole.user,
          text: text,
          createdAt: now,
        );
    final db = MockJournalDb();
    when(
      () => db.getMeasurementsByType(
        type: 'pages',
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const Scaffold(body: GoalAgentChatPane(agentId: 'goal-1')),
          overrides: [
            agentIdentityProvider(
              'goal-1',
            ).overrideWith((ref) async => identity),
            goalAgentHealthProvider('goal-1').overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.onTrack,
                attainment: 1.0,
                reportOneLiner: null,
                pendingProposals: 0,
                spec: spec,
                direction: null,
                deficit: null,
                buffer: null,
              ),
            ),
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value([pages]),
            ),
            goalMeasurableCaptureDecisionsProvider('goal-1').overrideWith(
              (ref) async => const {
                'recorded': GoalMeasurableCaptureDecision(
                  sourceMessageId: 'recorded',
                  recorded: true,
                  entryCount: 2,
                ),
                'dismissed': GoalMeasurableCaptureDecision(
                  sourceMessageId: 'dismissed',
                  recorded: false,
                  entryCount: 0,
                ),
              },
            ),
            agentChatProjectionProvider('goal-1').overrideWith(
              (ref) async => [
                message('recorded', 'I read 30 pages yesterday.'),
                message('dismissed', 'I read 10 pages on Monday.'),
                message('chatter', 'Reading felt good today.'),
                message(
                  'agent-echo',
                  'You read 5 pages today.',
                  role: AgentChatRole.agent,
                ),
                message('fresh', 'I read 20 pages today.'),
              ],
            ),
            journalDbProvider.overrideWithValue(db),
          ],
        ),
      );
      await tester.pumpAndSettle();
    });

    // A recorded decision renders the receipt, crediting the pane's agent
    // when the decision carries no name of its own.
    expect(find.byType(GoalRecordReceipt), findsOneWidget);
    expect(
      find.text('Recorded · 2 entries · said by you, recorded by Juno'),
      findsOneWidget,
    );
    // Dismissed, quantity-free and agent-authored turns carry no card; the
    // one fresh quantity gets exactly one offer, keyed to its message.
    expect(find.byType(GoalRecordOfferCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-record-offer-fresh')),
      findsOneWidget,
    );
    final card = tester.widget<GoalRecordOfferCard>(
      find.byType(GoalRecordOfferCard),
    );
    expect(card.agentName, 'Juno');
    expect(card.offer.items.single.value, 20);
    expect(card.offer.items.single.day, DateTime.utc(2026, 8, 12));
  });
}
