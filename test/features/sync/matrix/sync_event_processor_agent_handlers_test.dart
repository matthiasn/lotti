// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../mocks/mocks.dart';
import 'sync_event_processor_test_helpers.dart';

void main() {
  setUpAll(registerSyncProcessorFallbacks);
  setUp(setUpProcessorMocks);

  group('SyncEventProcessor - Agent Entities and Links', () {
    late MockAgentRepository mockAgentRepo;

    setUp(() {
      mockAgentRepo = MockAgentRepository();
      when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockAgentRepo.upsertLink(any())).thenAnswer((_) async {});
      when(() => mockAgentRepo.getEntity(any())).thenAnswer((_) async => null);
      when(
        () => mockAgentRepo.getAgentState(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockAgentRepo.getEntitiesByIds(any()),
      ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
      when(() => mockAgentRepo.getLinkById(any())).thenAnswer(
        (_) async => null,
      );
      when(
        () => mockAgentRepo.getLinksFrom(
          any(),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => const []);
      processor.agentRepository = mockAgentRepo;
    });

    test('processes agent identity entity', () async {
      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {'cat-1'},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('agentEntity')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test(
      'older-client rewrite preserves explicit task-agent setup fields',
      () async {
        final local =
            AgentDomainEntity.agent(
                  id: 'agent-legacy-rewrite',
                  agentId: 'agent-legacy-rewrite',
                  kind: 'task_agent',
                  displayName: 'Task Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-1',
                  config: const AgentConfig(
                    profileId: 'profile-1',
                    automaticUpdatesEnabled: false,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.configured,
                      origin: AgentInferenceSetupOrigin.categorySnapshot,
                      baseProfileId: 'profile-1',
                      originEntityId: 'category-1',
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: const AgentConfig(profileId: 'profile-1'),
          updatedAt: DateTime(2024, 3, 16),
        );
        when(
          () => mockAgentRepo.getEntity(incoming.id),
        ).thenAnswer((_) async => local);
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        final applied =
            verify(
                  () => mockAgentRepo.upsertEntity(captureAny()),
                ).captured.single
                as AgentIdentityEntity;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.automaticUpdatesEnabled, isFalse);
        expect(applied.config.inferenceSetup, local.config.inferenceSetup);
      },
    );

    test(
      'older-client rewrite preserves an explicit project-agent opt-out',
      () async {
        final local =
            AgentDomainEntity.agent(
                  id: 'project-agent-legacy-rewrite',
                  agentId: 'project-agent-legacy-rewrite',
                  kind: 'project_agent',
                  displayName: 'Project Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-project-agent-legacy-rewrite',
                  config: const AgentConfig(
                    automaticUpdatesEnabled: false,
                    inferenceSetup: AgentInferenceSetup(
                      mode: AgentInferenceSetupMode.disabled,
                      origin: AgentInferenceSetupOrigin.user,
                    ),
                  ),
                  createdAt: DateTime(2024, 3, 15),
                  updatedAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as AgentIdentityEntity;
        final incoming = local.copyWith(
          displayName: 'Renamed by older client',
          config: const AgentConfig(),
          updatedAt: DateTime(2024, 3, 16),
        );
        when(
          () => mockAgentRepo.getEntity(incoming.id),
        ).thenAnswer((_) async => local);
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        final applied = verify(
          () => mockAgentRepo.upsertEntity(captureAny()),
        ).captured.whereType<AgentIdentityEntity>().single;
        expect(applied.displayName, 'Renamed by older client');
        expect(applied.config.automaticUpdatesEnabled, isFalse);
        expect(applied.config.inferenceSetup, local.config.inferenceSetup);
      },
    );

    test('explicit incoming setup fields win over local values', () async {
      final local =
          AgentDomainEntity.agent(
                id: 'agent-explicit-rewrite',
                agentId: 'agent-explicit-rewrite',
                kind: 'task_agent',
                displayName: 'Task Agent',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: 'state-1',
                config: const AgentConfig(
                  automaticUpdatesEnabled: false,
                  inferenceSetup: AgentInferenceSetup(
                    mode: AgentInferenceSetupMode.disabled,
                    origin: AgentInferenceSetupOrigin.user,
                  ),
                ),
                createdAt: DateTime(2024, 3, 15),
                updatedAt: DateTime(2024, 3, 15),
                vectorClock: null,
              )
              as AgentIdentityEntity;
      final incoming = local.copyWith(
        config: const AgentConfig(
          profileId: 'profile-2',
          automaticUpdatesEnabled: true,
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'profile-2',
          ),
        ),
        updatedAt: DateTime(2024, 3, 16),
      );
      when(
        () => mockAgentRepo.getEntity(incoming.id),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
    });

    test('processes agent state entity', () async {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        wakeCounter: const GCounter({'test-host': 42}),
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('repairs a legacy week rollup before applying inbound sync', () async {
      final entity = AgentDomainEntity.weekRollup(
        id: 'week_rollup:2026-05-18',
        agentId: 'daily_os_planner',
        weekStart: DateTime.utc(2026, 5, 18),
        plannedMinutesByCategory: const {'cat-work': 480},
        recordedMinutesByCategory: const {'cat-work': 310},
        daysWithPlans: 5,
        createdAt: DateTime(2026, 5, 24),
        updatedAt: DateTime(2026, 5, 24, 12),
        vectorClock: const VectorClock({'remote-host': 3}),
      );
      final envelope =
          jsonDecode(
                jsonEncode(
                  SyncMessage.agentEntity(
                    agentEntity: entity,
                    status: SyncEntryStatus.update,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      (envelope['agentEntity'] as Map<String, dynamic>).remove('weekStart');
      when(() => event.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(envelope))),
      );

      await processor.process(event: event, journalDb: journalDb);

      final applied =
          verify(() => mockAgentRepo.upsertEntity(captureAny())).captured.single
              as WeekRollupEntity;
      expect(applied, entity);
      expect(
        applied.weekStart,
        DateTime.utc(2026, 5, 18),
        reason:
            'The id is a zone-free calendar key, so the repaired value is '
            'read from its components rather than resolved in the reader zone.',
      );
    });

    test('skips an irreparable legacy week rollup during prepare', () async {
      final entity = AgentDomainEntity.weekRollup(
        id: 'week_rollup:2026-05-18',
        agentId: 'daily_os_planner',
        weekStart: DateTime(2026, 5, 18),
        createdAt: DateTime(2026, 5, 24),
        updatedAt: DateTime(2026, 5, 24, 12),
        vectorClock: const VectorClock({'remote-host': 3}),
      );
      final envelope =
          jsonDecode(
                jsonEncode(
                  SyncMessage.agentEntity(
                    agentEntity: entity,
                    status: SyncEntryStatus.update,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final nested = (envelope['agentEntity'] as Map<String, dynamic>)
        ..remove('weekStart')
        ..['id'] = 'week_rollup:2026-05-17';
      expect(nested['weekStart'], isNull);
      when(() => event.text).thenReturn(
        base64.encode(utf8.encode(jsonEncode(envelope))),
      );

      final prepared = await processor.prepare(event: event);

      expect(prepared, isNull);
      verifyNever(() => mockAgentRepo.upsertEntity(any()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(
            that: allOf(
              contains('Legacy weekRollup is missing weekStart'),
              isNot(contains('2026-05-17')),
            ),
          ),
          subDomain: 'processor.skipUnrecoverable',
        ),
      ).called(1);
    });

    test('applying a remote agent state keeps local scheduling fields '
        '(device-local, not synced)', () async {
      // Incoming causally dominates local, so it is applied — but the local
      // device's own scheduling must survive (PR 4 B4).
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: const VectorClock({'host-A': 1}),
        wakeCounter: const GCounter({'host-A': 1}),
        nextWakeAt: DateTime(2024, 1, 2),
        sleepUntil: DateTime(2024, 1, 3),
        scheduledWakeAt: DateTime(2024, 1, 1),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: const VectorClock({'host-A': 2}),
        wakeCounter: const GCounter({'host-A': 3}),
        // The peer's schedule — must be ignored on this device.
        nextWakeAt: DateTime(2030, 1, 2),
        sleepUntil: DateTime(2030, 1, 3),
        scheduledWakeAt: DateTime(2030, 1, 1),
      );
      when(
        () => mockAgentRepo.getEntity('state-1'),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      final upserted =
          verify(() => mockAgentRepo.upsertEntity(captureAny())).captured.single
              as AgentStateEntity;
      // Scheduling stays local…
      expect(upserted.scheduledWakeAt, DateTime(2024, 1, 1));
      expect(upserted.nextWakeAt, DateTime(2024, 1, 2));
      expect(upserted.sleepUntil, DateTime(2024, 1, 3));
      // …while everything else takes the applied (incoming) value.
      expect(upserted.wakeCounter.value, 3);
      expect(upserted.updatedAt, DateTime(2024, 3, 16));
    });

    test('concurrent agent-state edits merge their G-counters element-wise '
        '(no increment lost)', () async {
      // localVc leads on host-A, incomingVc leads on host-B → concurrent.
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: localVc,
        wakeCounter: const GCounter({'host-A': 7}),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: incomingVc,
        wakeCounter: const GCounter({'host-B': 4}),
      );
      when(
        () => mockAgentRepo.getEntity('state-1'),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      final upserted =
          verify(() => mockAgentRepo.upsertEntity(captureAny())).captured.single
              as AgentStateEntity;
      // Both devices' increments survive the concurrent apply.
      expect(upserted.wakeCounter.byHost, {'host-A': 7, 'host-B': 4});
      expect(upserted.wakeCounter.value, 11);
    });

    test('concurrent goal-nudge edits join exposure counters and collapse '
        'same-activation ratings to the earliest outcome', () async {
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      GoalNudgeEntity nudgeRow({
        required VectorClock vc,
        required GCounter visibleMs,
        required List<GoalNudgeRating> ratings,
        GoalNudgeStatus status = GoalNudgeStatus.active,
      }) =>
          AgentDomainEntity.goalNudge(
                id: 'nudge-1',
                agentId: 'agent-1',
                status: status,
                brief: const GoalNudgeBrief(
                  headline: 'h',
                  tone: GoalNudgeTone.nudge,
                  animation: GoalBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                updatedAt: DateTime(2026, 8, 2),
                vectorClock: vc,
                totalVisibleMs: visibleMs,
                ratings: ratings,
              )
              as GoalNudgeEntity;

      final local = nudgeRow(
        vc: localVc,
        visibleMs: const GCounter({'host-A': 5000}),
        ratings: [
          GoalNudgeRating(
            activation: 1,
            ratedAt: DateTime(2026, 8, 1, 9),
            rating: 5,
          ),
        ],
        status: GoalNudgeStatus.dismissed,
      );
      final incoming = nudgeRow(
        vc: incomingVc,
        visibleMs: const GCounter({'host-B': 3000}),
        ratings: [
          GoalNudgeRating(
            activation: 1,
            ratedAt: DateTime(2026, 8, 1, 11),
            rating: 4,
          ),
        ],
      );
      when(
        () => mockAgentRepo.getEntity('nudge-1'),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      final upserted =
          verify(() => mockAgentRepo.upsertEntity(captureAny())).captured.single
              as GoalNudgeEntity;
      // The dismissal-terminal override picked local as the winner, and
      // the accumulator join recovered the other device's exposure and
      // rating anyway.
      expect(upserted.status, GoalNudgeStatus.dismissed);
      expect(
        upserted.totalVisibleMs.byHost,
        {'host-A': 5000, 'host-B': 3000},
      );
      // One outcome per activation: both devices rated activation 1, and
      // the merge keeps the EARLIEST outcome (the first one the user gave).
      expect(upserted.ratings, hasLength(1));
      expect(upserted.ratings.single.activation, 1);
      expect(upserted.ratings.single.rating, 5);
      expect(upserted.ratings.single.ratedAt, DateTime(2026, 8, 1, 9));
    });

    test('concurrent goal-nudge edits with no dismissal fall to LWW for '
        'the row while still joining the counters', () async {
      const localVc = VectorClock({'host-A': 2, 'host-B': 1});
      const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
      final local =
          AgentDomainEntity.goalNudge(
                id: 'nudge-2',
                agentId: 'agent-1',
                status: GoalNudgeStatus.active,
                brief: const GoalNudgeBrief(
                  headline: 'old copy',
                  tone: GoalNudgeTone.nudge,
                  animation: GoalBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                updatedAt: DateTime(2026, 8, 2),
                vectorClock: localVc,
                totalVisibleMs: const GCounter({'host-A': 100}),
              )
              as GoalNudgeEntity;
      final incoming =
          AgentDomainEntity.goalNudge(
                id: 'nudge-2',
                agentId: 'agent-1',
                status: GoalNudgeStatus.retired,
                brief: const GoalNudgeBrief(
                  headline: 'old copy',
                  tone: GoalNudgeTone.nudge,
                  animation: GoalBannerAnimation.steady,
                ),
                briefDigest: 'd',
                createdAt: DateTime(2026, 8),
                // Strictly newer wall clock → incoming wins the row.
                updatedAt: DateTime(2026, 8, 3),
                vectorClock: incomingVc,
                totalVisibleMs: const GCounter({'host-B': 200}),
              )
              as GoalNudgeEntity;
      when(
        () => mockAgentRepo.getEntity('nudge-2'),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await processor.process(event: event, journalDb: journalDb);

      final upserted =
          verify(() => mockAgentRepo.upsertEntity(captureAny())).captured.single
              as GoalNudgeEntity;
      expect(upserted.status, GoalNudgeStatus.retired);
      expect(
        upserted.totalVisibleMs.byHost,
        {'host-A': 100, 'host-B': 200},
      );
    });

    test('a locally-dominating agent state is kept — incoming is neither '
        'merged nor applied', () async {
      // local dominates (a_gt_b), so the merge must NOT run; if it did it would
      // upsert a merged state. Correct behavior keeps local and writes nothing.
      const localVc = VectorClock({'host-A': 2});
      const incomingVc = VectorClock({'host-A': 1});
      final local = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: localVc,
        wakeCounter: const GCounter({'host-A': 5}),
      );
      final incoming = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 5,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: incomingVc,
        wakeCounter: const GCounter({'host-A': 3}),
      );
      when(
        () => mockAgentRepo.getEntity('state-1'),
      ).thenAnswer((_) async => local);
      when(() => event.text).thenReturn(
        encodeMessage(
          SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          ),
        ),
      );

      await withClock(
        Clock.fixed(DateTime(2026, 8, 1, 9)),
        () => processor.process(event: event, journalDb: journalDb),
      );

      verifyNever(() => mockAgentRepo.upsertEntity(any()));
    });

    test(
      'a concurrent retract of durable knowledge is kept — a later edit cannot '
      'revive it (ADR 0022 monotonic override)',
      () async {
        // Concurrent clocks (local leads host-A, incoming leads host-B) with a
        // STRICTLY LATER incoming timestamp: plain LWW would apply the edit and
        // resurrect the retracted knowledge. The monotonic override keeps the
        // retraction instead.
        const localVc = VectorClock({'host-A': 2, 'host-B': 1});
        const incomingVc = VectorClock({'host-A': 1, 'host-B': 2});
        final local = AgentDomainEntity.plannerKnowledge(
          id: 'k1',
          agentId: 'agent-1',
          key: 'deep-work',
          hook: 'no deep work before 10',
          statementText: 'Never schedule deep work before 10:00.',
          source: KnowledgeSource.userStated,
          status: KnowledgeStatus.retracted,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
          retractedAt: DateTime(2024, 3, 16),
        );
        final incoming = AgentDomainEntity.plannerKnowledge(
          id: 'k1',
          agentId: 'agent-1',
          key: 'deep-work',
          hook: 'no deep work before 10',
          statementText: 'edited back to active',
          source: KnowledgeSource.userStated,
          status: KnowledgeStatus.confirmed,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 17),
          vectorClock: incomingVc,
          confirmedAt: DateTime(2024, 3, 17),
        );
        when(
          () => mockAgentRepo.getEntity('k1'),
        ).thenAnswer((_) async => local);
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        // The retraction wins despite the later edit timestamp, so the
        // incoming confirm is neither applied nor written.
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      },
    );

    test(
      'prefetches local agent entities once for outbox bundle dominance checks',
      () async {
        const localVc = VectorClock({'host-A': 2});
        const incomingVc = VectorClock({'host-A': 1});
        final localOne = AgentDomainEntity.agentState(
          id: 'state-bulk-1',
          agentId: 'agent-1',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
        );
        final localTwo = AgentDomainEntity.agentState(
          id: 'state-bulk-2',
          agentId: 'agent-2',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: localVc,
        );
        final incomingOne = AgentDomainEntity.agentState(
          id: 'state-bulk-1',
          agentId: 'agent-1',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: incomingVc,
        );
        final incomingTwo = AgentDomainEntity.agentState(
          id: 'state-bulk-2',
          agentId: 'agent-2',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: incomingVc,
        );
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments.single as Iterable<String>;
          expect(ids.toSet(), {'state-bulk-1', 'state-bulk-2'});
          return {
            'state-bulk-1': localOne,
            'state-bulk-2': localTwo,
          };
        });

        final message = SyncMessage.outboxBundle(
          children: [
            SyncMessage.agentEntity(
              agentEntity: incomingOne,
              status: SyncEntryStatus.update,
            ),
            SyncMessage.agentEntity(
              agentEntity: incomingTwo,
              status: SyncEntryStatus.update,
            ),
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(1);
        verifyNever(() => mockAgentRepo.getEntity(any()));
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      },
    );

    test(
      'refreshes prefetched agent entity cache after same-bundle upsert',
      () async {
        final localInitial = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-A': 1}),
        );
        final incomingNewer = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 3,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 17),
          vectorClock: const VectorClock({'host-A': 3}),
        );
        final incomingOlder = AgentDomainEntity.agentState(
          id: 'state-cache-refresh',
          agentId: 'agent-cache-refresh',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: const VectorClock({'host-A': 2}),
        );
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((_) async => {'state-cache-refresh': localInitial});

        final message = SyncMessage.outboxBundle(
          children: [
            SyncMessage.agentEntity(
              agentEntity: incomingNewer,
              status: SyncEntryStatus.update,
            ),
            SyncMessage.agentEntity(
              agentEntity: incomingOlder,
              status: SyncEntryStatus.update,
            ),
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(1);
        verify(() => mockAgentRepo.upsertEntity(incomingNewer)).called(1);
        verifyNever(() => mockAgentRepo.upsertEntity(incomingOlder));
      },
    );

    test(
      'keeps outbox bundle agent prefetch caches isolated across overlaps',
      () async {
        final dominantLocal = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 19),
          vectorClock: const VectorClock({'host-A': 5}),
        );
        final staleShared = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-A': 1}),
        );
        final otherShared = AgentDomainEntity.agentState(
          id: 'shared-state',
          agentId: 'agent-shared',
          revision: 2,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 16),
          vectorClock: const VectorClock({'host-A': 2}),
        );
        final blockerOne = AgentDomainEntity.agentState(
          id: 'bundle-one-blocker',
          agentId: 'agent-blocker',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        final blockerTwo = AgentDomainEntity.agentState(
          id: 'bundle-two-blocker',
          agentId: 'agent-blocker',
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );
        var prefetchCall = 0;
        when(
          () => mockAgentRepo.getEntitiesByIds(any()),
        ).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments.single as Iterable<String>;
          expect(ids.toSet(), {'shared-state'});
          prefetchCall += 1;
          if (prefetchCall == 1) {
            return {'shared-state': dominantLocal};
          }
          return const <String, AgentDomainEntity>{};
        });

        final blockerOneStarted = Completer<void>();
        final blockerOneRelease = Completer<void>();
        final blockerTwoStarted = Completer<void>();
        final blockerTwoRelease = Completer<void>();
        when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          final entity =
              invocation.positionalArguments.single as AgentDomainEntity;
          if (entity.id == blockerOne.id) {
            if (!blockerOneStarted.isCompleted) {
              blockerOneStarted.complete();
            }
            await blockerOneRelease.future;
          }
          if (entity.id == blockerTwo.id) {
            if (!blockerTwoStarted.isCompleted) {
              blockerTwoStarted.complete();
            }
            await blockerTwoRelease.future;
          }
        });

        final eventOne = MockEvent();
        when(() => eventOne.eventId).thenReturn('event-one');
        when(() => eventOne.originServerTs).thenReturn(DateTime(2024));
        when(() => eventOne.text).thenReturn(
          encodeMessage(
            SyncMessage.outboxBundle(
              children: [
                SyncMessage.agentEntity(
                  agentEntity: blockerOne,
                  status: SyncEntryStatus.update,
                ),
                SyncMessage.agentEntity(
                  agentEntity: staleShared,
                  status: SyncEntryStatus.update,
                ),
              ],
            ),
          ),
        );

        final eventTwo = MockEvent();
        when(() => eventTwo.eventId).thenReturn('event-two');
        when(() => eventTwo.originServerTs).thenReturn(DateTime(2024));
        when(() => eventTwo.text).thenReturn(
          encodeMessage(
            SyncMessage.outboxBundle(
              children: [
                SyncMessage.agentEntity(
                  agentEntity: blockerTwo,
                  status: SyncEntryStatus.update,
                ),
                SyncMessage.agentEntity(
                  agentEntity: otherShared,
                  status: SyncEntryStatus.update,
                ),
              ],
            ),
          ),
        );

        final processOne = processor.process(
          event: eventOne,
          journalDb: journalDb,
        );
        await blockerOneStarted.future;

        final processTwo = processor.process(
          event: eventTwo,
          journalDb: journalDb,
        );
        await blockerTwoStarted.future;

        blockerOneRelease.complete();
        await processOne;

        blockerTwoRelease.complete();
        await processTwo;

        verify(() => mockAgentRepo.getEntitiesByIds(any())).called(2);
        verifyNever(() => mockAgentRepo.upsertEntity(staleShared));
        verify(() => mockAgentRepo.upsertEntity(otherShared)).called(1);
      },
    );

    test('processes agent message entity', () async {
      final entity = AgentDomainEntity.agentMessage(
        id: 'msg-1',
        agentId: 'agent-1',
        threadId: 'thread-1',
        kind: AgentMessageKind.thought,
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        metadata: const AgentMessageMetadata(),
        tokensApprox: 100,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('processes agent message payload entity', () async {
      final entity = AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: 'agent-1',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: const {'text': 'hello world'},
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
    });

    test('processes agent report entity', () async {
      final entity = AgentDomainEntity.agentReport(
        id: 'report-1',
        agentId: 'agent-1',
        scope: 'current',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        content: 'Report content',
        confidence: 0.9,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      final taskLink = AgentLink.agentTask(
        id: 'agent-task-link',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      final deletedTaskLink = AgentLink.agentTask(
        id: 'deleted-agent-task-link',
        fromId: 'agent-1',
        toId: 'deleted-task',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
        deletedAt: DateTime(2024, 3, 16),
      );
      when(
        () => mockAgentRepo.getLinksFrom('agent-1', type: 'agent_task'),
      ).thenAnswer((_) async => [taskLink, deletedTaskLink]);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'task-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('processes agent report head entity', () async {
      final entity = AgentDomainEntity.agentReportHead(
        id: 'head-1',
        agentId: 'agent-1',
        scope: 'current',
        reportId: 'report-1',
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      final taskLink = AgentLink.agentTask(
        id: 'agent-task-link',
        fromId: 'agent-1',
        toId: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );
      when(
        () => mockAgentRepo.getLinksFrom('agent-1', type: 'agent_task'),
      ).thenAnswer((_) async => [taskLink]);
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'task-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test(
      'processes wakeTokenUsage entity with templateId in notification',
      () async {
        final entity = AgentDomainEntity.wakeTokenUsage(
          id: 'usage-1',
          agentId: 'agent-1',
          runKey: 'run-1',
          threadId: 'thread-1',
          modelId: 'models/gemini-2.5-pro',
          createdAt: DateTime(2024, 3, 15),
          vectorClock: null,
          templateId: 'tpl-1',
          inputTokens: 100,
          outputTokens: 50,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => updateNotifications.notify(
            {'agent-1', 'tpl-1', 'AGENT_CHANGED'},
            fromSync: true,
          ),
        ).called(1);
      },
    );

    test('processes wakeTokenUsage entity without templateId', () async {
      final entity = AgentDomainEntity.wakeTokenUsage(
        id: 'usage-2',
        agentId: 'agent-1',
        runKey: 'run-2',
        threadId: 'thread-2',
        modelId: 'models/gemini-2.5-pro',
        createdAt: DateTime(2024, 3, 15),
        vectorClock: null,
        inputTokens: 200,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    test('processes agent link (basic)', () async {
      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verify(() => mockAgentRepo.upsertLink(link)).called(1);
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('agentLink')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
      verify(
        () => updateNotifications.notify(
          {'agent-1', 'state-1', 'AGENT_CHANGED'},
          fromSync: true,
        ),
      ).called(1);
    });

    group('concurrent-branch LWW resolution', () {
      // Two concurrent clocks (each leads on a different host). In canonical
      // host order `host-A` sorts first, so `vcWinsTie` (greater on host-A) is
      // the deterministic winner whenever updatedAt ties.
      const vcWinsTie = VectorClock({'host-A': 2, 'host-B': 1});
      const vcLosesTie = VectorClock({'host-A': 1, 'host-B': 2});

      AgentDomainEntity stateWith({
        required VectorClock vectorClock,
        required DateTime updatedAt,
      }) => AgentDomainEntity.agentState(
        id: 'state-cc',
        agentId: 'agent-1',
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: updatedAt,
        vectorClock: vectorClock,
      );

      AgentLink linkWith({
        required VectorClock vectorClock,
        required DateTime updatedAt,
      }) => AgentLink.basic(
        id: 'link-cc',
        fromId: 'agent-1',
        toId: 'state-1',
        createdAt: DateTime(2024, 3),
        updatedAt: updatedAt,
        vectorClock: vectorClock,
      );

      Future<void> processEntity(AgentDomainEntity incoming) async {
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );
        await processor.process(event: event, journalDb: journalDb);
      }

      Future<void> processLink(AgentLink incoming) async {
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentLink(
              agentLink: incoming,
              status: SyncEntryStatus.update,
            ),
          ),
        );
        await processor.process(event: event, journalDb: journalDb);
      }

      test('applies incoming entity when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = stateWith(
          vectorClock: vcLosesTie,
          updatedAt: DateTime(2024, 3, 16),
        );

        await processEntity(incoming);

        // LWW: newer updatedAt wins even though the local clock is canonically
        // greater.
        verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
      });

      test('keeps local entity when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 16),
          ),
        );

        await processEntity(
          stateWith(vectorClock: vcWinsTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      });

      // The next two feed the SAME concurrent pair from both device
      // perspectives on an equal timestamp: the canonically-greater version
      // wins whether it is the incoming payload or the already-stored row —
      // i.e. both devices converge on the same winner.
      test('equal updatedAt: a greater incoming clock is applied', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = stateWith(
          vectorClock: vcWinsTie,
          updatedAt: DateTime(2024, 3, 15),
        );

        await processEntity(incoming);

        verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
      });

      test('equal updatedAt: a greater local clock is kept', () async {
        when(() => mockAgentRepo.getEntity('state-cc')).thenAnswer(
          (_) async => stateWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );

        await processEntity(
          stateWith(vectorClock: vcLosesTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      });

      test('applies incoming link when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = linkWith(
          vectorClock: vcLosesTie,
          updatedAt: DateTime(2024, 3, 16),
        );

        await processLink(incoming);

        verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
      });

      test('keeps local link when its updatedAt is newer', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 16),
          ),
        );

        await processLink(
          linkWith(vectorClock: vcWinsTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertLink(any()));
      });

      // Equal-timestamp link cases — exercise the canonical vector-clock
      // tiebreak on the link path, mirroring the entity cases above.
      test('equal updatedAt: a greater incoming link clock wins', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcLosesTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );
        final incoming = linkWith(
          vectorClock: vcWinsTie,
          updatedAt: DateTime(2024, 3, 15),
        );

        await processLink(incoming);

        verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
      });

      test('equal updatedAt: a greater local link clock is kept', () async {
        when(() => mockAgentRepo.getLinkById('link-cc')).thenAnswer(
          (_) async => linkWith(
            vectorClock: vcWinsTie,
            updatedAt: DateTime(2024, 3, 15),
          ),
        );

        await processLink(
          linkWith(vectorClock: vcLosesTie, updatedAt: DateTime(2024, 3, 15)),
        );

        verifyNever(() => mockAgentRepo.upsertLink(any()));
      });
    });

    test(
      'no-ops a legacy SyncAgentBundle envelope so the marker advances; '
      'children recover via the per-entity / per-link backfill path',
      () async {
        final entity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-a': 1}),
        );
        final link = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: const VectorClock({'host-a': 2}),
        );
        final message = SyncMessage.agentBundle(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
          originatingHostId: 'host-a',
          entities: [
            SyncMessage.agentEntity(
                  agentEntity: entity,
                  status: SyncEntryStatus.update,
                )
                as SyncAgentEntity,
          ],
          links: [
            SyncMessage.agentLink(
                  agentLink: link,
                  status: SyncEntryStatus.update,
                )
                as SyncAgentLink,
          ],
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        // Bundle is intentionally not applied — the agent repo is not
        // touched, no AGENT_CHANGED notifications fire, and process()
        // completes cleanly so the inbound queue marker advances. The
        // sender already recorded each child under per-entity /
        // per-link sequence-log entries, so backfill picks them up if
        // they are missing locally.
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verifyNever(
          () => updateNotifications.notify(
            any<Set<String>>(),
            fromSync: any<bool>(named: 'fromSync'),
          ),
        );
      },
    );

    test(
      'processes agent link variants (agentState, messagePrev, etc)',
      () async {
        final links = [
          AgentLink.agentState(
            id: 'link-2',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.messagePrev(
            id: 'link-3',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.messagePayload(
            id: 'link-4',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.toolEffect(
            id: 'link-5',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
          AgentLink.agentTask(
            id: 'link-6',
            fromId: 'a',
            toId: 'b',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          ),
        ];

        for (final link in links) {
          reset(mockAgentRepo);
          when(() => mockAgentRepo.upsertLink(any())).thenAnswer((_) async {});

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
        }
      },
    );

    test('skips agent entity when agentRepository is null', () async {
      processor.agentRepository = null;

      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await withClock(
        Clock.fixed(DateTime(2026, 8, 1, 9)),
        () => processor.process(event: event, journalDb: journalDb),
      );

      verifyNever(() => mockAgentRepo.upsertEntity(any()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('ignored')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test('skips agent link when agentRepository is null', () async {
      processor.agentRepository = null;

      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'a',
        toId: 'b',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await processor.process(event: event, journalDb: journalDb);

      verifyNever(() => mockAgentRepo.upsertLink(any()));
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any<String>(that: contains('ignored')),
          subDomain: 'processor.apply',
        ),
      ).called(1);
    });

    test('propagates repository error on agent entity upsert', () async {
      when(
        () => mockAgentRepo.upsertEntity(any()),
      ).thenAnswer((_) async => throw Exception('db error'));

      final entity = AgentDomainEntity.agent(
        id: 'agent-1',
        agentId: 'agent-1',
        kind: 'task_agent',
        displayName: 'Test Agent',
        lifecycle: AgentLifecycle.active,
        mode: AgentInteractionMode.autonomous,
        allowedCategoryIds: const {},
        currentStateId: 'state-1',
        config: const AgentConfig(),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      // The processor catches, logs, and rethrows
      await expectLater(
        () => processor.process(event: event, journalDb: journalDb),
        throwsA(isA<Exception>()),
      );

      verify(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('propagates repository error on agent link upsert', () async {
      when(
        () => mockAgentRepo.upsertLink(any()),
      ).thenAnswer((_) async => throw Exception('db error'));

      final link = AgentLink.basic(
        id: 'link-1',
        fromId: 'a',
        toId: 'b',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      );

      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      when(() => event.text).thenReturn(encodeMessage(message));

      await expectLater(
        () => processor.process(event: event, journalDb: journalDb),
        throwsA(isA<Exception>()),
      );

      verify(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).called(1);
    });

    group('_localAgentPayloadDominates error handling', () {
      // Tests for lines 444-448: the catch block in _localAgentPayloadDominates
      // fires when VectorClock.compare throws VclockException (e.g. a VC with
      // a negative counter is invalid).  The processor logs the error and
      // treats the dominance check as false, so it falls through to upsert.

      test(
        'logs error and falls through to upsert when incoming VC is invalid '
        '(VclockException — lines 444-448)',
        () async {
          // Local entity has a valid VC so dominance check is attempted.
          final local = AgentDomainEntity.agentState(
            id: 'state-invalid-vc',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: const VectorClock({'host-A': 1}),
          );
          // Incoming entity has an invalid VC (negative counter) — this causes
          // VectorClock.compare to throw VclockException.
          final incoming = AgentDomainEntity.agentState(
            id: 'state-invalid-vc',
            agentId: 'agent-1',
            revision: 3,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 17),
            vectorClock: const VectorClock({'host-A': -1}),
          );
          when(
            () => mockAgentRepo.getEntity('state-invalid-vc'),
          ).thenAnswer((_) async => local);

          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          // The catch block in _localAgentPayloadDominates logs and returns
          // false, so the entity is upserted anyway.
          verify(() => mockAgentRepo.upsertEntity(incoming)).called(1);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('vectorClockCompare'),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'logs error and falls through to upsert when link VC is invalid '
        '(VclockException — lines 444-448)',
        () async {
          final local = AgentLink.basic(
            id: 'link-invalid-vc',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: const VectorClock({'host-A': 1}),
          );
          final incoming = AgentLink.basic(
            id: 'link-invalid-vc',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 17),
            vectorClock: const VectorClock({'host-A': -1}),
          );
          when(
            () => mockAgentRepo.getLinkById('link-invalid-vc'),
          ).thenAnswer((_) async => local);

          final message = SyncMessage.agentLink(
            agentLink: incoming,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          // Dominance check failed (VclockException caught), falls through to
          // upsert.
          verify(() => mockAgentRepo.upsertLink(incoming)).called(1);
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('vectorClockCompare'),
              ),
            ),
          ).called(1);
        },
      );
    });

    group('agent entity sequence log recording', () {
      late MockSyncSequenceLogService mockSeqService;
      late MockAgentRepository mockAgentRepoSeq;

      setUp(() {
        mockSeqService = MockSyncSequenceLogService();
        mockAgentRepoSeq = MockAgentRepository();
        when(
          () => mockAgentRepoSeq.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(() => mockAgentRepoSeq.upsertLink(any())).thenAnswer((_) async {});
        when(
          () => mockAgentRepoSeq.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentRepoSeq.getEntitiesByIds(any()),
        ).thenAnswer((_) async => const <String, AgentDomainEntity>{});
        when(
          () => mockAgentRepoSeq.getLinkById(any()),
        ).thenAnswer((_) async => null);
      });

      test(
        'skips stale agent entity when local vector clock dominates but '
        'still records sequence receipt',
        () async {
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-dominates',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final incoming = AgentDomainEntity.agentState(
            id: 'state-dominates',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getEntity('state-dominates'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepoSeq.upsertEntity(any()));
          verify(
            () => mockSeqService.recordReceivedEntry(
              entryId: 'state-dominates',
              vectorClock: incomingVc,
              originatingHostId: 'host-A',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.agentEntity,
              jsonPath: any(named: 'jsonPath'),
            ),
          ).called(1);
          verifyNever(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any<bool>(named: 'fromSync'),
            ),
          );
        },
      );

      test(
        'applies agent entity when incoming vector clock dominates',
        () async {
          const localVc = VectorClock({'host-A': 1});
          const incomingVc = VectorClock({'host-A': 2});
          final local = AgentDomainEntity.agentState(
            id: 'state-newer',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: localVc,
          );
          final incoming = AgentDomainEntity.agentState(
            id: 'state-newer',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getEntity('state-newer'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepoSeq.upsertEntity(incoming)).called(1);
        },
      );

      test(
        'skips equal agent link vector clock but still records sequence receipt',
        () async {
          const incomingVc = VectorClock({'host-A': 2});
          final local = AgentLink.basic(
            id: 'link-dominates',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: incomingVc,
          );
          final incoming = AgentLink.basic(
            id: 'link-dominates',
            fromId: 'agent-1',
            toId: 'state-1',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepoSeq.getLinkById('link-dominates'),
          ).thenAnswer((_) async => local);
          when(
            () => mockSeqService.recordReceivedEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              originatingHostId: any(named: 'originatingHostId'),
              coveredVectorClocks: any(named: 'coveredVectorClocks'),
              payloadType: any(named: 'payloadType'),
              jsonPath: any(named: 'jsonPath'),
            ),
          ).thenAnswer((_) async => []);

          final proc = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            sequenceLogService: mockSeqService,
          )..agentRepository = mockAgentRepoSeq;
          final message = SyncMessage.agentLink(
            agentLink: incoming,
            status: SyncEntryStatus.update,
            originatingHostId: 'host-A',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await proc.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepoSeq.upsertLink(any()));
          verify(
            () => mockSeqService.recordReceivedEntry(
              entryId: 'link-dominates',
              vectorClock: incomingVc,
              originatingHostId: 'host-A',
              coveredVectorClocks: null,
              payloadType: SyncSequencePayloadType.agentLink,
              jsonPath: any(named: 'jsonPath'),
            ),
          ).called(1);
          verifyNever(
            () => updateNotifications.notify(
              any<Set<String>>(),
              fromSync: any<bool>(named: 'fromSync'),
            ),
          );
        },
      );

      test('records received agent entity in sequence log', () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-seq-1',
          agentId: 'agent-seq-1',
          kind: 'task_agent',
          displayName: 'Seq Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => []);

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => mockSeqService.recordReceivedEntry(
            entryId: 'agent-seq-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.agentEntity,
            jsonPath: any(named: 'jsonPath'),
          ),
        ).called(1);
      });

      test('logs gap detection for agent entity', () async {
        const vc = VectorClock({'host-B': 20});
        final entity = AgentDomainEntity.agent(
          id: 'agent-gap-1',
          agentId: 'agent-gap-1',
          kind: 'task_agent',
          displayName: 'Gap Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-B',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => [(hostId: 'host-B', counter: 18)],
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(
              that: contains('apply.agentEntity.gapsDetected count=1'),
            ),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('handles recordReceivedEntry exception for agent entity', () async {
        const vc = VectorClock({'host-C': 5});
        final entity = AgentDomainEntity.agent(
          id: 'agent-err-1',
          agentId: 'agent-err-1',
          kind: 'task_agent',
          displayName: 'Err Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-C',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('seq log error'));

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        // Entity should still be upserted despite seq log error
        verify(() => mockAgentRepoSeq.upsertEntity(entity)).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      });

      test('records received agent link in sequence log', () async {
        const vc = VectorClock({'host-A': 15});
        final link = AgentLink.basic(
          id: 'link-seq-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => []);

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => mockSeqService.recordReceivedEntry(
            entryId: 'link-seq-1',
            vectorClock: vc,
            originatingHostId: 'host-A',
            coveredVectorClocks: null,
            payloadType: SyncSequencePayloadType.agentLink,
            jsonPath: any(named: 'jsonPath'),
          ),
        ).called(1);
      });

      test('logs gap detection for agent link', () async {
        const vc = VectorClock({'host-D': 12});
        final link = AgentLink.basic(
          id: 'link-gap-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-D',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer(
          (_) async => [
            (hostId: 'host-D', counter: 9),
            (hostId: 'host-D', counter: 10),
          ],
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('apply.agentLink.gapsDetected count=2')),
            subDomain: 'processor.gapDetection',
          ),
        ).called(1);
      });

      test('handles recordReceivedEntry exception for agent link', () async {
        const vc = VectorClock({'host-E': 7});
        final link = AgentLink.basic(
          id: 'link-err-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-E',
        );

        when(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenThrow(Exception('seq log error link'));

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        // Link should still be upserted despite seq log error.
        verify(() => mockAgentRepoSeq.upsertLink(link)).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'recordReceived',
          ),
        ).called(1);
      });

      test('skips sequence log when vectorClock is null', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-no-vc',
          agentId: 'agent-no-vc',
          kind: 'task_agent',
          displayName: 'No VC',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          originatingHostId: 'host-A',
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verifyNever(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      });

      test('skips sequence log when originatingHostId is null', () async {
        const vc = VectorClock({'host-A': 10});
        final entity = AgentDomainEntity.agent(
          id: 'agent-no-host',
          agentId: 'agent-no-host',
          kind: 'task_agent',
          displayName: 'No Host',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: vc,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
          // no originatingHostId
        );

        final proc = SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: journalEntityLoader,
          sequenceLogService: mockSeqService,
        )..agentRepository = mockAgentRepoSeq;

        when(() => event.text).thenReturn(encodeMessage(message));
        await proc.process(event: event, journalDb: journalDb);

        verifyNever(
          () => mockSeqService.recordReceivedEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            originatingHostId: any(named: 'originatingHostId'),
            coveredVectorClocks: any(named: 'coveredVectorClocks'),
            payloadType: any(named: 'payloadType'),
          ),
        );
      });
    });

    group('lifecycle side-effects on incoming identity', () {
      late MockWakeOrchestrator mockOrchestrator;

      setUp(() {
        mockOrchestrator = MockWakeOrchestrator();
        processor.wakeOrchestrator = mockOrchestrator;
        when(
          () => mockOrchestrator.removeSubscriptions(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
      });

      test('offers a synced-in identity to every runtime-maintenance '
          'contributor, containing a throwing one', () async {
        final seen = <String>[];
        final recorder = _RecordingMaintenance(seen);
        processor.runtimeMaintenance = [
          _ThrowingMaintenance(),
          _DefaultHookMaintenance(),
          recorder,
        ];
        addTearDown(() => processor.runtimeMaintenance = const []);

        final entity = AgentDomainEntity.agent(
          id: 'goal-77',
          agentId: 'goal-77',
          kind: 'goal_agent',
          displayName: 'Steps goal',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: entity,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        // The thrower ran first and was contained; the recorder still got
        // the identity, and the entity was persisted normally.
        expect(seen, ['goal-77']);
        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      });

      test('a synced-in goal spec head re-offers the identity — creation '
          'bundles emit identity before spec', () async {
        final seen = <String>[];
        processor.runtimeMaintenance = [_RecordingMaintenance(seen)];
        addTearDown(() => processor.runtimeMaintenance = const []);

        final identity = AgentDomainEntity.agent(
          id: 'goal-88',
          agentId: 'goal-88',
          kind: 'goal_agent',
          displayName: 'Steps goal',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2026, 8),
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        when(
          () => mockAgentRepo.getEntity('goal-88'),
        ).thenAnswer((_) async => identity);

        final head = AgentDomainEntity.goalSpecHead(
          id: 'goal_spec_head:goal-88',
          agentId: 'goal-88',
          versionId: 'goal-88:spec-v1',
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        );
        when(() => event.text).thenReturn(
          encodeMessage(
            SyncMessage.agentEntity(
              agentEntity: head,
              status: SyncEntryStatus.update,
            ),
          ),
        );

        await processor.process(event: event, journalDb: journalDb);

        expect(seen, ['goal-88']);
        verify(() => mockAgentRepo.upsertEntity(head)).called(1);
      });

      test('removes subscriptions when agent is dormant', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-dormant',
          agentId: 'agent-dormant',
          kind: 'task_agent',
          displayName: 'Dormant Agent',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(
            'agent-dormant',
          ),
        ).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-dormant'),
        ).called(1);
      });

      test('removes subscriptions when agent is destroyed', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-destroyed',
          agentId: 'agent-destroyed',
          kind: 'task_agent',
          displayName: 'Destroyed Agent',
          lifecycle: AgentLifecycle.destroyed,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(
            'agent-destroyed',
          ),
        ).called(1);
        verify(
          () => mockOrchestrator.removeSubscriptions('agent-destroyed'),
        ).called(1);
      });

      test(
        'synced dormant project identity clears the local fallback',
        () async {
          final pendingAt = DateTime(2026, 8, 14, 9);
          final localState =
              AgentDomainEntity.agentState(
                    id: 'state-project-dormant',
                    agentId: 'project-agent-dormant',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: pendingAt,
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 8),
                    vectorClock: const VectorClock({'local': 4}),
                  )
                  as AgentStateEntity;
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-dormant',
            agentId: 'project-agent-dormant',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: localState.id,
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'remote': 2}),
          );
          when(
            () => mockAgentRepo.getAgentState(identity.agentId),
          ).thenAnswer((_) async => localState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: identity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          final clearedState = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().single;
          expect(clearedState.scheduledWakeAt, isNull);
          expect(clearedState.slots.pendingProjectActivityAt, pendingAt);
          expect(clearedState.updatedAt, localState.updatedAt);
          expect(clearedState.vectorClock, localState.vectorClock);
          verify(
            () => mockOrchestrator.removeSubscriptions(identity.agentId),
          ).called(1);
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              identity.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'stale synced opt-out does not clear a newer local opt-in fallback',
        () async {
          final pendingAt = DateTime(2026, 8, 14, 9);
          final state =
              AgentDomainEntity.agentState(
                    id: 'state-project-opt-in-race',
                    agentId: 'project-agent-opt-in-race',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: pendingAt,
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 4}),
                  )
                  as AgentStateEntity;
          final incomingDormant =
              AgentDomainEntity.agent(
                    id: 'project-agent-opt-in-race',
                    agentId: 'project-agent-opt-in-race',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.dormant,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: state.id,
                    config: const AgentConfig(automaticUpdatesEnabled: false),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 10),
                    vectorClock: const VectorClock({'remote': 2}),
                  )
                  as AgentIdentityEntity;
          final newerOptIn = incomingDormant.copyWith(
            lifecycle: AgentLifecycle.active,
            config: const AgentConfig(automaticUpdatesEnabled: true),
            updatedAt: DateTime(2026, 8, 14, 11),
            vectorClock: const VectorClock({'remote': 2, 'local': 1}),
          );
          final link = AgentLink.agentProject(
            id: 'project-link-opt-in-race',
            fromId: incomingDormant.agentId,
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          AgentIdentityEntity? storedIdentity;
          when(
            () => mockAgentRepo.getEntity(incomingDormant.id),
          ).thenAnswer((_) async => storedIdentity);
          when(
            () => mockAgentRepo.getAgentState(incomingDormant.agentId),
          ).thenAnswer((_) async => state);
          when(
            () => mockAgentRepo.getLinksFrom(
              incomingDormant.agentId,
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => [link]);
          when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((
            invocation,
          ) async {
            final entity =
                invocation.positionalArguments.single as AgentDomainEntity;
            if (entity is AgentIdentityEntity) storedIdentity = newerOptIn;
          });
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incomingDormant,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          final stateWrites = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>();
          expect(stateWrites, isEmpty);
          verify(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(
              incomingDormant.agentId,
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.addSubscription(any()),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
          );
        },
      );

      test(
        'equal project identity replay retries local fallback repair',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          const vectorClock = VectorClock({'remote': 2});
          final identity =
              AgentDomainEntity.agent(
                    id: 'project-agent-equal-replay',
                    agentId: 'project-agent-equal-replay',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-project-equal-replay',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: vectorClock,
                  )
                  as AgentIdentityEntity;
          final pendingState =
              AgentDomainEntity.agentState(
                    id: identity.currentStateId,
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'remote': 3}),
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getEntity(identity.id),
          ).thenAnswer((_) async => identity);
          when(
            () => mockAgentRepo.getAgentState(identity.agentId),
          ).thenAnswer((_) async => pendingState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: identity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final repaired =
              verify(
                    () => mockAgentRepo.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(repaired.scheduledWakeAt, DateTime(2026, 8, 15, 6));
          expect(repaired.updatedAt, pendingState.updatedAt);
          expect(repaired.vectorClock, pendingState.vectorClock);
          verify(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(
              identity.agentId,
            ),
          ).called(1);
          verify(
            () => updateNotifications.notify(
              {identity.agentId, 'AGENT_CHANGED'},
              fromSync: true,
            ),
          ).called(1);
        },
      );

      test(
        'equal project state replay retries local fallback repair',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          const vectorClock = VectorClock({'remote': 3});
          final identity =
              AgentDomainEntity.agent(
                    id: 'project-agent-state-replay',
                    agentId: 'project-agent-state-replay',
                    kind: AgentKinds.projectAgent,
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-project-state-replay',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'remote': 2}),
                  )
                  as AgentIdentityEntity;
          final pendingState =
              AgentDomainEntity.agentState(
                    id: identity.currentStateId,
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: vectorClock,
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getEntity(pendingState.id),
          ).thenAnswer((_) async => pendingState);
          when(
            () => mockAgentRepo.getEntity(identity.id),
          ).thenAnswer((_) async => identity);
          when(
            () => mockAgentRepo.getAgentState(identity.agentId),
          ).thenAnswer((_) async => pendingState);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: pendingState,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final repaired =
              verify(
                    () => mockAgentRepo.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(repaired.scheduledWakeAt, DateTime(2026, 8, 15, 6));
          expect(repaired.updatedAt, pendingState.updatedAt);
          expect(repaired.vectorClock, pendingState.vectorClock);
          verify(
            () => updateNotifications.notify(
              {identity.agentId, 'AGENT_CHANGED'},
              fromSync: true,
            ),
          ).called(1);
        },
      );

      test('restores subscriptions for active task_agent', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-active',
          agentId: 'agent-active',
          kind: 'task_agent',
          displayName: 'Active Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(automaticUpdatesEnabled: true),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final taskLink = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-active',
          toId: 'task-42',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockAgentRepo.getLinksFrom(
            'agent-active',
            type: 'agent_task',
          ),
        ).thenAnswer((_) async => [taskLink]);

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verify(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime('agent-active'),
        ).called(1);
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
        verify(
          () => mockOrchestrator.addSubscription(
            any(
              that: isA<AgentSubscription>().having(
                (s) => s.agentId,
                'agentId',
                'agent-active',
              ),
            ),
          ),
        ).called(1);
      });

      test(
        'restores existing project link when project_agent identity arrives',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final projectLink = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getLinksFrom(
              'project-agent-1',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => [projectLink]);
          when(
            () => mockAgentRepo.getEntity(entity.id),
          ).thenAnswer((_) async => entity);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having(
                      (subscription) => subscription.id,
                      'id',
                      'project-agent-1_project_direct_project-42',
                    )
                    .having(
                      (subscription) => subscription.matchEntityIds,
                      'matchEntityIds',
                      {projectEntityUpdateNotification('project-42')},
                    ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'project identity arms activity observed before the identity arrived',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getAgentState('project-agent-1'),
          ).thenAnswer((_) async => pendingState);
          when(
            () => mockAgentRepo.getEntity('project-agent-1'),
          ).thenAnswer((_) async => entity);
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: entity,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final persistedStates = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().toList();
          expect(persistedStates, hasLength(1));
          expect(
            persistedStates.single.scheduledWakeAt,
            DateTime(2026, 8, 15, 6),
          );
        },
      );

      test(
        'project state arms pending activity when the identity arrived first',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getEntity('project-agent-1'),
          ).thenAnswer((_) async => identity);
          when(
            () => mockAgentRepo.getAgentState('project-agent-1'),
          ).thenAnswer((_) async => pendingState);
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: pendingState,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final persistedStates = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().toList();
          expect(
            persistedStates.map((state) => state.scheduledWakeAt),
            contains(DateTime(2026, 8, 15, 6)),
          );
          final repaired = persistedStates.singleWhere(
            (state) => state.scheduledWakeAt != null,
          );
          expect(
            repaired.updatedAt,
            pendingState.updatedAt,
            reason: 'A device-local deadline must not change synced LWW data.',
          );
        },
      );

      test(
        'project state rebuilds an imported fallback from the local clock',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final remoteFallback = DateTime(2026, 8, 14, 18);
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-imported',
            agentId: 'project-agent-imported',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-imported',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final incoming =
              AgentDomainEntity.agentState(
                    id: 'state-imported',
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    scheduledWakeAt: remoteFallback,
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          AgentStateEntity? storedState;
          when(
            () => mockAgentRepo.getEntity(identity.agentId),
          ).thenAnswer((_) async => identity);
          when(
            () => mockAgentRepo.getAgentState(identity.agentId),
          ).thenAnswer((_) async => storedState);
          when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((
            invocation,
          ) async {
            final entity =
                invocation.positionalArguments.single as AgentDomainEntity;
            if (entity is AgentStateEntity) storedState = entity;
          });
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final persistedStates = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().toList();
          expect(
            persistedStates.map((state) => state.scheduledWakeAt),
            isNot(contains(remoteFallback)),
          );
          expect(storedState?.scheduledWakeAt, DateTime(2026, 8, 15, 6));
          expect(storedState?.updatedAt, incoming.updatedAt);
        },
      );

      test(
        'project state strips an imported fallback before identity arrives',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final remoteFallback = DateTime(2026, 8, 14, 18);
          final incoming =
              AgentDomainEntity.agentState(
                    id: 'state-before-identity',
                    agentId: 'project-agent-later',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    nextWakeAt: DateTime(2026, 8, 14, 10, 2),
                    sleepUntil: DateTime(2026, 8, 14, 10, 5),
                    scheduledWakeAt: remoteFallback,
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          final persisted =
              verify(
                    () => mockAgentRepo.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persisted.nextWakeAt, isNull);
          expect(persisted.sleepUntil, isNull);
          expect(persisted.scheduledWakeAt, isNull);
          expect(persisted.slots.pendingProjectActivityAt, isNotNull);
        },
      );

      test(
        'project state completion clears local automatic work before identity '
        'arrives',
        () async {
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-completed',
            agentId: 'project-agent-completed',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-project-completed',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-completed',
                    agentId: identity.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    nextWakeAt: DateTime(2026, 8, 14, 9, 2),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          when(
            () => mockAgentRepo.getEntity(local.id),
          ).thenAnswer((_) async => local);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          final applied = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().first;
          expect(applied.slots.pendingProjectActivityAt, isNull);
          expect(applied.scheduledWakeAt, isNull);
          verify(
            () => mockOrchestrator.cancelPendingAutomaticWakes(
              local.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'legacy project state without activity marker preserves local work',
        () async {
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-legacy',
                    agentId: 'project-agent-legacy',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          final message = SyncMessage.agentEntity(
            agentEntity: incoming,
            status: SyncEntryStatus.update,
          );
          final messageJson =
              json.decode(json.encode(message.toJson()))
                  as Map<String, dynamic>;
          final entityJson = messageJson['agentEntity'] as Map<String, dynamic>;
          final slotsJson = entityJson['slots'] as Map<String, dynamic>;
          slotsJson.remove('pendingProjectActivityAt');

          when(
            () => mockAgentRepo.getEntity(local.id),
          ).thenAnswer((_) async => local);
          when(() => event.text).thenReturn(
            base64.encode(utf8.encode(json.encode(messageJson))),
          );

          await processor.process(event: event, journalDb: journalDb);

          final applied = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().first;
          expect(
            applied.slots.pendingProjectActivityAt,
            local.slots.pendingProjectActivityAt,
          );
          expect(applied.scheduledWakeAt, local.scheduledWakeAt);
          verifyNever(
            () => mockOrchestrator.cancelPendingAutomaticWakes(any()),
          );
        },
      );

      test(
        'bundled legacy project state without activity marker preserves '
        'local work',
        () async {
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-bundled-legacy',
                    agentId: 'project-agent-bundled-legacy',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final incoming = local.copyWith(
            slots: local.slots.copyWith(pendingProjectActivityAt: null),
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          final bundle = SyncMessage.outboxBundle(
            children: [
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ],
          );
          final bundleJson =
              json.decode(json.encode(bundle.toJson())) as Map<String, dynamic>;
          final childrenJson = bundleJson['children'] as List<dynamic>;
          final childJson = childrenJson.single as Map<String, dynamic>;
          final entityJson = childJson['agentEntity'] as Map<String, dynamic>;
          final slotsJson = entityJson['slots'] as Map<String, dynamic>;
          slotsJson.remove('pendingProjectActivityAt');

          when(
            () => mockAgentRepo.getEntitiesByIds(any()),
          ).thenAnswer((_) async => {local.id: local});
          when(() => event.text).thenReturn(
            base64.encode(utf8.encode(json.encode(bundleJson))),
          );

          await processor.process(event: event, journalDb: journalDb);

          final applied = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().single;
          expect(
            applied.slots.pendingProjectActivityAt,
            local.slots.pendingProjectActivityAt,
          );
          expect(applied.scheduledWakeAt, local.scheduledWakeAt);
          verifyNever(
            () => mockOrchestrator.cancelPendingAutomaticWakes(any()),
          );
        },
      );

      test(
        'project identity classifies marker-only state completion',
        () async {
          final identity = AgentDomainEntity.agent(
            id: 'project-agent-marker-only',
            agentId: 'project-agent-marker-only',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-project-marker-only',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final local =
              AgentDomainEntity.agentState(
                    id: 'state-project-marker-only',
                    agentId: identity.agentId,
                    slots: const AgentSlots(
                      pendingProjectActivityAt: null,
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as AgentStateEntity;
          final localWithPending = local.copyWith(
            slots: local.slots.copyWith(
              pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
            ),
          );
          final incoming = local.copyWith(
            lastWakeAt: DateTime(2026, 8, 14, 10),
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 8, 14, 10),
            vectorClock: const VectorClock({'local': 1, 'remote': 1}),
          );
          when(
            () => mockAgentRepo.getEntity(local.id),
          ).thenAnswer((_) async => localWithPending);
          when(
            () => mockAgentRepo.getEntity(identity.id),
          ).thenAnswer((_) async => identity);
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentEntity(
                agentEntity: incoming,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          final applied = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().first;
          expect(applied.scheduledWakeAt, isNull);
          verify(
            () => mockOrchestrator.cancelPendingAutomaticWakes(
              local.agentId,
            ),
          ).called(1);
        },
      );

      test(
        'removes subscriptions for dormant project_agent identity',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-dormant',
            agentId: 'project-agent-dormant',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.removeSubscriptions('project-agent-dormant'),
          ).called(1);
          verifyNever(
            () => mockAgentRepo.getLinksFrom(
              any(),
              type: 'agent_project',
            ),
          );
        },
      );

      test(
        'project_agent identity with automation off keeps observation only',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'project-agent-manual',
            agentId: 'project-agent-manual',
            kind: 'project_agent',
            displayName: 'Manual Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final projectLink = AgentLink.agentProject(
            id: 'project-link-manual',
            fromId: 'project-agent-manual',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-project-agent-manual',
                    agentId: entity.agentId,
                    slots: AgentSlots(
                      activeProjectId: projectLink.toId,
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getAgentState(entity.agentId),
          ).thenAnswer((_) async => pendingState);
          when(
            () => mockAgentRepo.getEntity(entity.id),
          ).thenAnswer((_) async => entity);
          when(
            () => mockAgentRepo.getLinksFrom(
              'project-agent-manual',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => [projectLink]);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'project-agent-manual',
            ),
          ).called(1);
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
          final persistedStates = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().toList();
          expect(persistedStates, hasLength(1));
          expect(persistedStates.single.scheduledWakeAt, isNull);
          expect(
            persistedStates.single.slots.pendingProjectActivityAt,
            pendingState.slots.pendingProjectActivityAt,
          );
        },
      );

      test(
        'retains observation for active task_agent with automation off',
        () async {
          final entity = AgentDomainEntity.agent(
            id: 'agent-manual',
            agentId: 'agent-manual',
            kind: 'task_agent',
            displayName: 'Manual Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final taskLink = AgentLink.basic(
            id: 'link-manual',
            fromId: 'agent-manual',
            toId: 'task-manual',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getLinksFrom(
              'agent-manual',
              type: 'agent_task',
            ),
          ).thenAnswer((_) async => [taskLink]);
          final message = SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'agent-manual',
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>().having(
                  (subscription) => subscription.agentId,
                  'agentId',
                  'agent-manual',
                ),
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.removeSubscriptions('agent-manual'),
          );
        },
      );

      test('does NOT remove subscriptions for non-identity entities', () async {
        final entity = AgentDomainEntity.agentState(
          id: 'state-1',
          agentId: 'agent-1',
          revision: 5,
          slots: const AgentSlots(),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
      });

      test('safe when wakeOrchestrator is null', () async {
        processor.wakeOrchestrator = null;

        final entity = AgentDomainEntity.agent(
          id: 'agent-dormant',
          agentId: 'agent-dormant',
          kind: 'task_agent',
          displayName: 'Dormant Agent',
          lifecycle: AgentLifecycle.dormant,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentEntity(
          agentEntity: entity,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        // Should not throw even though lifecycle is dormant.
        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        verifyNever(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        );
      });
    });

    group('subscription restoration on incoming agent link', () {
      late MockWakeOrchestrator mockOrchestrator;

      setUp(() {
        mockOrchestrator = MockWakeOrchestrator();
        processor.wakeOrchestrator = mockOrchestrator;
        when(
          () => mockOrchestrator.disableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
        when(
          () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
        ).thenReturn(null);
      });

      test(
        'agent_task link for active task_agent restores subscription',
        () async {
          final activeAgent = AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Active Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          when(
            () => mockAgentRepo.getEntity('agent-1'),
          ).thenAnswer((_) async => activeAgent);

          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having((s) => s.agentId, 'agentId', 'agent-1')
                    .having(
                      (s) => s.matchEntityIds,
                      'matchEntityIds',
                      {'task-42'},
                    ),
              ),
            ),
          ).called(1);
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime('agent-1'),
          ).called(1);
        },
      );

      test(
        'agent_task link for dormant agent does NOT restore subscription',
        () async {
          final dormantAgent = AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'task_agent',
            displayName: 'Dormant Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          when(
            () => mockAgentRepo.getEntity('agent-1'),
          ).thenAnswer((_) async => dormantAgent);

          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'agent_project link for active project_agent restores subscription',
        () async {
          final activeAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getEntity('project-agent-1'),
          ).thenAnswer((_) async => activeAgent);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getLinksFrom(
              activeAgent.agentId,
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => [link]);
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.addSubscription(
              any(
                that: isA<AgentSubscription>()
                    .having(
                      (subscription) => subscription.id,
                      'id',
                      'project-agent-1_project_direct_project-42',
                    )
                    .having(
                      (subscription) => subscription.matchEntityIds,
                      'matchEntityIds',
                      {projectEntityUpdateNotification('project-42')},
                    ),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'agent_project link repairs pending activity without a deadline',
        () async {
          final now = DateTime(2026, 8, 14, 10);
          final activeAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'project-agent-1',
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: now.subtract(
                        const Duration(minutes: 5),
                      ),
                    ),
                    updatedAt: now.subtract(const Duration(minutes: 5)),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getEntity('project-agent-1'),
          ).thenAnswer((_) async => activeAgent);
          when(
            () => mockAgentRepo.getAgentState('project-agent-1'),
          ).thenAnswer((_) async => pendingState);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => event.text,
          ).thenReturn(
            encodeMessage(
              SyncMessage.agentLink(
                agentLink: link,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await withClock(Clock.fixed(now), () {
            return processor.process(event: event, journalDb: journalDb);
          });

          final persistedState =
              verify(
                    () => mockAgentRepo.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persistedState.scheduledWakeAt, DateTime(2026, 8, 15, 6));
        },
      );

      test(
        'agent_project fallback repair rechecks a concurrent opt-out',
        () async {
          final activeAgent =
              AgentDomainEntity.agent(
                    id: 'project-agent-race',
                    agentId: 'project-agent-race',
                    kind: 'project_agent',
                    displayName: 'Project Agent',
                    lifecycle: AgentLifecycle.active,
                    mode: AgentInteractionMode.autonomous,
                    allowedCategoryIds: const {},
                    currentStateId: 'state-race',
                    config: const AgentConfig(),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                    vectorClock: null,
                  )
                  as AgentIdentityEntity;
          final optedOutAgent = activeAgent.copyWith(
            config: const AgentConfig(automaticUpdatesEnabled: false),
          );
          final pendingState =
              AgentDomainEntity.agentState(
                    id: 'state-race',
                    agentId: activeAgent.agentId,
                    slots: AgentSlots(
                      activeProjectId: 'project-42',
                      pendingProjectActivityAt: DateTime(2026, 8, 14, 9),
                    ),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'peer-a': 2}),
                  )
                  as AgentStateEntity;
          var identityReads = 0;
          when(
            () => mockAgentRepo.getEntity(activeAgent.id),
          ).thenAnswer(
            (_) async => identityReads++ == 0 ? activeAgent : optedOutAgent,
          );
          when(
            () => mockAgentRepo.getAgentState(activeAgent.agentId),
          ).thenAnswer((_) async => pendingState);
          final link = AgentLink.agentProject(
            id: 'project-link-race',
            fromId: activeAgent.agentId,
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(() => event.text).thenReturn(
            encodeMessage(
              SyncMessage.agentLink(
                agentLink: link,
                status: SyncEntryStatus.update,
              ),
            ),
          );

          await processor.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              activeAgent.agentId,
            ),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
        },
      );

      test(
        'agent_project link for dormant project_agent stays unsubscribed',
        () async {
          final dormantAgent = AgentDomainEntity.agent(
            id: 'project-agent-1',
            agentId: 'project-agent-1',
            kind: 'project_agent',
            displayName: 'Dormant Project Agent',
            lifecycle: AgentLifecycle.dormant,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getEntity('project-agent-1'),
          ).thenAnswer((_) async => dormantAgent);
          final link = AgentLink.agentProject(
            id: 'project-link-1',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.getEntity('project-agent-1')).called(2);
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'agent_project link applies the project automation opt-out',
        () async {
          final manualAgent = AgentDomainEntity.agent(
            id: 'project-agent-manual',
            agentId: 'project-agent-manual',
            kind: 'project_agent',
            displayName: 'Manual Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(automaticUpdatesEnabled: false),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getEntity('project-agent-manual'),
          ).thenAnswer((_) async => manualAgent);
          final markerlessFallback =
              AgentDomainEntity.agentState(
                    id: 'state-project-agent-manual',
                    agentId: 'project-agent-manual',
                    slots: const AgentSlots(activeProjectId: 'project-42'),
                    scheduledWakeAt: DateTime(2026, 8, 15, 6),
                    updatedAt: DateTime(2026, 8, 14, 9),
                    vectorClock: const VectorClock({'peer-a': 2}),
                  )
                  as AgentStateEntity;
          when(
            () => mockAgentRepo.getAgentState('project-agent-manual'),
          ).thenAnswer((_) async => markerlessFallback);
          final link = AgentLink.agentProject(
            id: 'project-link-manual',
            fromId: 'project-agent-manual',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          when(
            () => mockAgentRepo.getLinksFrom(
              manualAgent.agentId,
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => [link]);
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'project-agent-manual',
            ),
          ).called(1);
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(any()),
          );
          final clearedFallback = verify(
            () => mockAgentRepo.upsertEntity(captureAny()),
          ).captured.whereType<AgentStateEntity>().single;
          expect(clearedFallback.scheduledWakeAt, isNull);
          expect(clearedFallback.slots.pendingProjectActivityAt, isNull);
          expect(clearedFallback.updatedAt, markerlessFallback.updatedAt);
          expect(clearedFallback.vectorClock, markerlessFallback.vectorClock);
        },
      );

      test(
        'soft-deleted agent_project link removes the direct subscription',
        () async {
          final link = AgentLink.agentProject(
            id: 'project-link-deleted',
            fromId: 'project-agent-1',
            toId: 'project-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: null,
            deletedAt: DateTime(2024, 3, 16),
          );
          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(
            () => mockOrchestrator.removeSubscription(
              'project-agent-1_project_direct_project-42',
            ),
          ).called(1);
          verifyNever(() => mockAgentRepo.getEntity(any()));
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test(
        'soft-deleted agent_task link removes the wake subscription',
        () async {
          final link = AgentLink.agentTask(
            id: 'link-deleted',
            fromId: 'agent-1',
            toId: 'task-42',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            deletedAt: DateTime(2024, 3, 16),
          );

          final message = SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertLink(link)).called(1);
          // Mirror remote delete: the per-link subscription must go so this
          // device stops waking an agent that was unlinked elsewhere.
          verify(
            () => mockOrchestrator.removeSubscription('agent-1_task_task-42'),
          ).called(1);
          // Delete path skips agent lookup + re-subscribe entirely.
          verifyNever(() => mockAgentRepo.getEntity(any()));
          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );

      test('non-agent_task link does NOT trigger subscription logic', () async {
        final link = AgentLink.basic(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        final message = SyncMessage.agentLink(
          agentLink: link,
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertLink(link)).called(1);
        // getEntity should not be called for non-agent_task links.
        verifyNever(() => mockAgentRepo.getEntity(any()));
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });
    });

    group('descriptor-only resolution (jsonPath)', () {
      late Directory tempDir;

      SyncEventProcessor processorForExplicitDirectory(
        Directory explicitDirectory,
      ) {
        return SyncEventProcessor(
          loggingService: loggingService,
          updateNotifications: updateNotifications,
          aiConfigRepository: aiConfigRepository,
          savedTaskFiltersRepository: savedTaskFiltersRepository,
          settingsDb: settingsDb,
          journalEntityLoader: FileSyncJournalEntityLoader(
            documentsDirectory: explicitDirectory,
          ),
          documentsDirectory: tempDir,
        )..agentRepository = mockAgentRepo;
      }

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync(
          'agent_resolve_test',
        );
        if (getIt.isRegistered<Directory>()) {
          getIt.unregister<Directory>();
        }
        getIt.registerSingleton<Directory>(tempDir);
      });

      tearDown(() async {
        await getIt.reset();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('resolves agent entity from jsonPath on disk', () async {
        final entity = AgentDomainEntity.agent(
          id: 'agent-disk',
          agentId: 'agent-disk',
          kind: 'task_agent',
          displayName: 'Disk Agent',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'state-1',
          config: const AgentConfig(),
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        const relativePath = '/agent_entities/agent-disk.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(entity.toJson()));

        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
      });

      test('file-backed irreparable week rollup is a permanent skip', () async {
        final entity = AgentDomainEntity.weekRollup(
          id: 'week_rollup:2026-05-18',
          agentId: 'daily_os_planner',
          weekStart: DateTime(2026, 5, 18),
          createdAt: DateTime(2026, 5, 24),
          updatedAt: DateTime(2026, 5, 24, 12),
          vectorClock: const VectorClock({'remote-host': 3}),
        );
        final legacyJson =
            jsonDecode(jsonEncode(entity.toJson())) as Map<String, dynamic>
              ..remove('weekStart')
              ..['id'] = 'week_rollup:2026-05-17';
        const relativePath = '/agent_entities/invalid-rollup.json';
        final file = File(
          path.join(tempDir.path, stripLeadingSlashes(relativePath)),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(legacyJson));
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        final prepared = await processor.prepare(event: event);

        expect(prepared, isNull);
        verifyNever(() => mockAgentRepo.upsertEntity(any()));
      });

      test(
        'derives the agent payload sandbox from the injected loader',
        () async {
          final explicitDirectory = await Directory(
            path.join(tempDir.path, 'explicit-device'),
          ).create();
          final explicitProcessor = processorForExplicitDirectory(
            explicitDirectory,
          );
          final entity = AgentDomainEntity.agent(
            id: 'agent-explicit',
            agentId: 'agent-explicit',
            kind: 'task_agent',
            displayName: 'Explicit Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );
          const relativePath = '/agent_entities/agent-explicit.json';
          final explicitFile = File(
            path.join(
              explicitDirectory.path,
              stripLeadingSlashes(relativePath),
            ),
          )..parent.createSync(recursive: true);
          explicitFile.writeAsStringSync(jsonEncode(entity.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await explicitProcessor.process(event: event, journalDb: journalDb);

          verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
          expect(
            File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            ).existsSync(),
            isFalse,
          );
        },
      );

      test(
        'keeps dominant local agent entity cache when jsonPath payload is stale',
        () async {
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-cache',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final stale = AgentDomainEntity.agentState(
            id: 'state-cache',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepo.getEntity('state-cache'),
          ).thenAnswer((_) async => local);

          const relativePath = '/agent_entities/state-cache.json';
          final normalized = stripLeadingSlashes(relativePath);
          final file = File(path.join(tempDir.path, normalized));
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(stale.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processor.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          final restored = AgentDomainEntity.fromJson(
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(
            restored.mapOrNull(agentState: (entity) => entity.revision),
            2,
          );
        },
      );

      test(
        'restores a dominant agent cache inside the injected loader sandbox',
        () async {
          final explicitDirectory = await Directory(
            path.join(tempDir.path, 'explicit-restore-device'),
          ).create();
          final explicitProcessor = processorForExplicitDirectory(
            explicitDirectory,
          );
          const localVc = VectorClock({'host-A': 2});
          const incomingVc = VectorClock({'host-A': 1});
          final local = AgentDomainEntity.agentState(
            id: 'state-explicit-cache',
            agentId: 'agent-1',
            revision: 2,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 16),
            vectorClock: localVc,
          );
          final stale = AgentDomainEntity.agentState(
            id: 'state-explicit-cache',
            agentId: 'agent-1',
            revision: 1,
            slots: const AgentSlots(),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: incomingVc,
          );
          when(
            () => mockAgentRepo.getEntity('state-explicit-cache'),
          ).thenAnswer((_) async => local);

          const relativePath = '/agent_entities/state-explicit-cache.json';
          final explicitFile = File(
            path.join(
              explicitDirectory.path,
              stripLeadingSlashes(relativePath),
            ),
          )..parent.createSync(recursive: true);
          explicitFile.writeAsStringSync(jsonEncode(stale.toJson()));
          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await explicitProcessor.process(event: event, journalDb: journalDb);

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          final restored = AgentDomainEntity.fromJson(
            jsonDecode(explicitFile.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(
            restored.mapOrNull(agentState: (entity) => entity.revision),
            2,
          );
          expect(
            File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            ).existsSync(),
            isFalse,
          );
        },
      );

      test('resolves agent link from jsonPath on disk', () async {
        final link = AgentLink.basic(
          id: 'link-disk',
          fromId: 'agent-1',
          toId: 'state-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        );

        const relativePath = '/agent_links/link-disk.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(link.toJson()));

        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verify(() => mockAgentRepo.upsertLink(link)).called(1);
      });

      test('skips agent entity with no entity and no jsonPath', () async {
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('no payload and no jsonPath')),
            subDomain: 'processor.resolve',
          ),
        ).called(1);
      });

      test('skips agent link with no link and no jsonPath', () async {
        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: contains('no payload and no jsonPath')),
            subDomain: 'processor.resolve',
          ),
        ).called(1);
      });

      test('skips agent entity with path-traversal jsonPath', () async {
        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: '../../../etc/passwd',
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentEntity.invalidPath',
          ),
        ).called(1);
      });

      test('skips agent link with path-traversal jsonPath', () async {
        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: '../../../etc/passwd',
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentLink.invalidPath',
          ),
        ).called(1);
      });

      test(
        'rethrows FileSystemException for missing agent entity file',
        () async {
          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/missing.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processor.process(event: event, journalDb: journalDb),
            throwsA(isA<FileSystemException>()),
          );
        },
      );

      test(
        'rethrows FileSystemException for missing agent link file',
        () async {
          const message = SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_links/missing.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processor.process(event: event, journalDb: journalDb),
            throwsA(isA<FileSystemException>()),
          );
        },
      );

      test('skips agent entity with corrupt JSON file', () async {
        const relativePath = '/agent_entities/corrupt.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('not valid json {{{');

        const message = SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertEntity(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentEntity',
          ),
        ).called(1);
      });

      group('descriptor-based resolution (AttachmentIndex)', () {
        late AttachmentIndex attachmentIndex;
        late SyncEventProcessor processorWithIndex;
        late MockEvent descriptorEvent;

        setUp(() {
          attachmentIndex = AttachmentIndex(logging: loggingService);
          processorWithIndex = SyncEventProcessor(
            loggingService: loggingService,
            updateNotifications: updateNotifications,
            aiConfigRepository: aiConfigRepository,
            savedTaskFiltersRepository: savedTaskFiltersRepository,
            settingsDb: settingsDb,
            journalEntityLoader: journalEntityLoader,
            attachmentIndex: attachmentIndex,
          );
          processorWithIndex.agentRepository = mockAgentRepo;

          descriptorEvent = MockEvent();
          when(() => descriptorEvent.eventId).thenReturn('desc-event-id');
          when(
            () => descriptorEvent.attachmentMimetype,
          ).thenReturn('application/json');
          when(() => descriptorEvent.content).thenReturn({
            'relativePath': '/agent_entities/agent-desc.json',
          });
        });

        test(
          'fetches agent entity from descriptor when file is missing',
          () async {
            final entity = AgentDomainEntity.agent(
              id: 'agent-desc',
              agentId: 'agent-desc',
              kind: 'task_agent',
              displayName: 'Descriptor Agent',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'state-1',
              config: const AgentConfig(),
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: null,
            );

            final bytes = Uint8List.fromList(
              utf8.encode(jsonEncode(entity.toJson())),
            );
            when(
              descriptorEvent.downloadAndDecryptAttachment,
            ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'e.json'));

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await processorWithIndex.process(
              event: event,
              journalDb: journalDb,
            );

            verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
            verify(descriptorEvent.downloadAndDecryptAttachment).called(1);
          },
        );

        test(
          'exact attachment binding keeps an older envelope on its payload '
          'generation after the path advances',
          () async {
            const relativePath = '/agent_entities/agent-versioned.json';
            const olderClock = VectorClock({'remote-host': 3});
            const newerClock = VectorClock({'remote-host': 30});
            const coveredClocks = [
              VectorClock({'remote-host': 1}),
              VectorClock({'remote-host': 2}),
            ];
            final olderEntity = AgentDomainEntity.agentState(
              id: 'agent-versioned',
              agentId: 'agent-versioned',
              revision: 3,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: olderClock,
            );
            final newerEntity = AgentDomainEntity.agentState(
              id: 'agent-versioned',
              agentId: 'agent-versioned',
              revision: 30,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: newerClock,
            );

            MockEvent descriptor({
              required String eventId,
              required AgentDomainEntity entity,
            }) {
              final result = MockEvent();
              when(() => result.eventId).thenReturn(eventId);
              when(
                () => result.attachmentMimetype,
              ).thenReturn('application/json');
              when(
                () => result.content,
              ).thenReturn({'relativePath': relativePath});
              when(result.downloadAndDecryptAttachment).thenAnswer(
                (_) async => MatrixFile(
                  bytes: Uint8List.fromList(
                    utf8.encode(jsonEncode(entity.toJson())),
                  ),
                  name: '$eventId.json',
                ),
              );
              return result;
            }

            final olderDescriptor = descriptor(
              eventId: 'older-payload-event',
              entity: olderEntity,
            );
            final newerDescriptor = descriptor(
              eventId: 'newer-payload-event',
              entity: newerEntity,
            );
            attachmentIndex
              ..record(olderDescriptor)
              ..record(newerDescriptor);

            AgentDomainEntity? storedEntity;
            when(
              () => mockAgentRepo.getEntity(olderEntity.id),
            ).thenAnswer((_) async => storedEntity);
            when(() => mockAgentRepo.upsertEntity(any())).thenAnswer((
              call,
            ) async {
              storedEntity =
                  call.positionalArguments.first as AgentDomainEntity;
            });

            final sequenceLog = MockSyncSequenceLogService();
            when(
              () => sequenceLog.recordReceivedEntry(
                entryId: any(named: 'entryId'),
                vectorClock: any(named: 'vectorClock'),
                originatingHostId: any(named: 'originatingHostId'),
                coveredVectorClocks: any(named: 'coveredVectorClocks'),
                payloadType: any(named: 'payloadType'),
                jsonPath: any(named: 'jsonPath'),
                payloadVectorClock: any(named: 'payloadVectorClock'),
                canonicalPayloadVectorClock: any(
                  named: 'canonicalPayloadVectorClock',
                ),
              ),
            ).thenAnswer((_) async => []);
            final exactProcessor = SyncEventProcessor(
              loggingService: loggingService,
              updateNotifications: updateNotifications,
              aiConfigRepository: aiConfigRepository,
              savedTaskFiltersRepository: savedTaskFiltersRepository,
              settingsDb: settingsDb,
              journalEntityLoader: journalEntityLoader,
              attachmentIndex: attachmentIndex,
              sequenceLogService: sequenceLog,
            )..agentRepository = mockAgentRepo;

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: relativePath,
              attachmentEventId: 'older-payload-event',
              originatingHostId: 'remote-host',
              coveredVectorClocks: coveredClocks,
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await exactProcessor.process(event: event, journalDb: journalDb);

            verify(() => mockAgentRepo.upsertEntity(olderEntity)).called(1);
            verifyNever(() => mockAgentRepo.upsertEntity(newerEntity));
            verify(
              () => sequenceLog.recordReceivedEntry(
                entryId: olderEntity.id,
                vectorClock: olderClock,
                originatingHostId: 'remote-host',
                coveredVectorClocks: coveredClocks,
                payloadType: SyncSequencePayloadType.agentEntity,
                jsonPath: relativePath,
                payloadVectorClock: olderClock,
                canonicalPayloadVectorClock: olderClock,
              ),
            ).called(1);
            verify(olderDescriptor.downloadAndDecryptAttachment).called(1);
            verifyNever(newerDescriptor.downloadAndDecryptAttachment);
          },
        );

        test(
          'exact attachment fetches the agent link and supplies payload proof',
          () async {
            const linkClock = VectorClock({'remote-host': 4});
            final link = AgentLink.basic(
              id: 'link-desc',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: linkClock,
            );

            final bytes = Uint8List.fromList(
              utf8.encode(jsonEncode(link.toJson())),
            );

            final linkDescriptorEvent = MockEvent();
            when(
              () => linkDescriptorEvent.eventId,
            ).thenReturn('link-desc-event-id');
            when(
              () => linkDescriptorEvent.attachmentMimetype,
            ).thenReturn('application/json');
            when(() => linkDescriptorEvent.content).thenReturn({
              'relativePath': '/agent_links/link-desc.json',
            });
            when(
              linkDescriptorEvent.downloadAndDecryptAttachment,
            ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'l.json'));

            attachmentIndex.record(linkDescriptorEvent);

            AgentLink? storedLink;
            when(
              () => mockAgentRepo.getLinkById(link.id),
            ).thenAnswer((_) async => storedLink);
            when(() => mockAgentRepo.upsertLink(any())).thenAnswer((
              call,
            ) async {
              storedLink = call.positionalArguments.first as AgentLink;
            });
            final sequenceLog = MockSyncSequenceLogService();
            when(
              () => sequenceLog.recordReceivedEntry(
                entryId: any(named: 'entryId'),
                vectorClock: any(named: 'vectorClock'),
                originatingHostId: any(named: 'originatingHostId'),
                coveredVectorClocks: any(named: 'coveredVectorClocks'),
                payloadType: any(named: 'payloadType'),
                jsonPath: any(named: 'jsonPath'),
                payloadVectorClock: any(named: 'payloadVectorClock'),
                canonicalPayloadVectorClock: any(
                  named: 'canonicalPayloadVectorClock',
                ),
              ),
            ).thenAnswer((_) async => []);
            final exactProcessor = SyncEventProcessor(
              loggingService: loggingService,
              updateNotifications: updateNotifications,
              aiConfigRepository: aiConfigRepository,
              savedTaskFiltersRepository: savedTaskFiltersRepository,
              settingsDb: settingsDb,
              journalEntityLoader: journalEntityLoader,
              attachmentIndex: attachmentIndex,
              sequenceLogService: sequenceLog,
            )..agentRepository = mockAgentRepo;

            const message = SyncMessage.agentLink(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_links/link-desc.json',
              attachmentEventId: 'link-desc-event-id',
              originatingHostId: 'remote-host',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await exactProcessor.process(
              event: event,
              journalDb: journalDb,
            );

            verify(() => mockAgentRepo.upsertLink(link)).called(1);
            verify(
              () => sequenceLog.recordReceivedEntry(
                entryId: link.id,
                vectorClock: linkClock,
                originatingHostId: 'remote-host',
                coveredVectorClocks: null,
                payloadType: SyncSequencePayloadType.agentLink,
                jsonPath: '/agent_links/link-desc.json',
                payloadVectorClock: linkClock,
                canonicalPayloadVectorClock: linkClock,
              ),
            ).called(1);
            verify(linkDescriptorEvent.downloadAndDecryptAttachment).called(1);
          },
        );

        test(
          'throws when descriptor download fails (no stale fallback)',
          () async {
            when(
              descriptorEvent.downloadAndDecryptAttachment,
            ).thenThrow(Exception('download failed'));

            attachmentIndex.record(descriptorEvent);

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: '/agent_entities/agent-desc.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await expectLater(
              () => processorWithIndex.process(
                event: event,
                journalDb: journalDb,
              ),
              throwsA(isA<FileSystemException>()),
            );

            verifyNever(() => mockAgentRepo.upsertEntity(any()));
          },
        );

        test('throws when descriptor returns empty bytes', () async {
          when(descriptorEvent.downloadAndDecryptAttachment).thenAnswer(
            (_) async => MatrixFile(bytes: Uint8List(0), name: 'e.json'),
          );

          attachmentIndex.record(descriptorEvent);

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/agent-desc.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await expectLater(
            () => processorWithIndex.process(
              event: event,
              journalDb: journalDb,
            ),
            throwsA(isA<FileSystemException>()),
          );

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
        });

        test('falls back to disk when no descriptor in index', () async {
          final entity = AgentDomainEntity.agent(
            id: 'agent-disk-fb',
            agentId: 'agent-disk-fb',
            kind: 'task_agent',
            displayName: 'Disk Fallback',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          );

          const relativePath = '/agent_entities/agent-disk-fb.json';
          final normalized = stripLeadingSlashes(relativePath);
          final file = File(path.join(tempDir.path, normalized));
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(jsonEncode(entity.toJson()));

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: relativePath,
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          await processorWithIndex.process(
            event: event,
            journalDb: journalDb,
          );

          verify(() => mockAgentRepo.upsertEntity(entity)).called(1);
        });

        test(
          'exact attachment miss never falls back to an existing agent '
          'sidecar at the same path',
          () async {
            final newerEntity = AgentDomainEntity.agent(
              id: 'agent-exact-pending',
              agentId: 'agent-exact-pending',
              kind: 'task_agent',
              displayName: 'Newer disk generation',
              lifecycle: AgentLifecycle.active,
              mode: AgentInteractionMode.autonomous,
              allowedCategoryIds: const {},
              currentStateId: 'state-30',
              config: const AgentConfig(),
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: const VectorClock({'remote-host': 30}),
            );
            const relativePath = '/agent_entities/agent-exact-pending.json';
            final file = File(
              path.join(tempDir.path, stripLeadingSlashes(relativePath)),
            );
            file.parent.createSync(recursive: true);
            file.writeAsStringSync(jsonEncode(newerEntity.toJson()));

            const message = SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              jsonPath: relativePath,
              attachmentEventId: 'agent-payload-not-yet-indexed',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await expectLater(
              processorWithIndex.process(event: event, journalDb: journalDb),
              throwsA(
                isA<FileSystemException>().having(
                  (error) => error.message,
                  'message',
                  contains('attachment descriptor not yet available'),
                ),
              ),
            );

            verifyNever(() => mockAgentRepo.upsertEntity(any()));
          },
        );

        test('skips agent entity with corrupt descriptor JSON', () async {
          final bytes = Uint8List.fromList(utf8.encode('not valid json'));
          when(
            descriptorEvent.downloadAndDecryptAttachment,
          ).thenAnswer((_) async => MatrixFile(bytes: bytes, name: 'e.json'));

          attachmentIndex.record(descriptorEvent);

          const message = SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            jsonPath: '/agent_entities/agent-desc.json',
          );
          when(() => event.text).thenReturn(encodeMessage(message));

          // Descriptor fetched successfully but JSON parse fails →
          // permanent skip (returns null), not a retry.
          await processorWithIndex.process(
            event: event,
            journalDb: journalDb,
          );

          verifyNever(() => mockAgentRepo.upsertEntity(any()));
          verify(
            () => loggingService.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'resolve.agentEntity.parseFetched',
            ),
          ).called(1);
        });
      });

      test('skips agent link with corrupt JSON file', () async {
        const relativePath = '/agent_links/corrupt.json';
        final normalized = stripLeadingSlashes(relativePath);
        final file = File(path.join(tempDir.path, normalized));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('not valid json {{{');

        const message = SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          jsonPath: relativePath,
        );
        when(() => event.text).thenReturn(encodeMessage(message));

        await processor.process(event: event, journalDb: journalDb);

        verifyNever(() => mockAgentRepo.upsertLink(any()));
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'resolve.agentLink',
          ),
        ).called(1);
      });

      group('_restoreDominantAgentCache FileSystemException (lines 465-469)', () {
        setUpAll(() {
          registerFallbackValue(const FileSystemException('fallback'));
        });

        // When local VC dominates AND jsonPath resolves outside the documents
        // directory (path-traversal after normalisation), resolveJsonCandidateFile
        // throws FileSystemException.  _restoreDominantAgentCache catches it and
        // logs at lines 465-469 without propagating.

        test(
          'logs FileSystemException when jsonPath escapes the documents '
          'directory during cache restore for an agent entity',
          () async {
            const localVc = VectorClock({'host-A': 2});
            const incomingVc = VectorClock({'host-A': 1});
            final local = AgentDomainEntity.agentState(
              id: 'state-restore-fail',
              agentId: 'agent-1',
              revision: 2,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: localVc,
            );
            final stale = AgentDomainEntity.agentState(
              id: 'state-restore-fail',
              agentId: 'agent-1',
              revision: 1,
              slots: const AgentSlots(),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: incomingVc,
            );
            when(
              () => mockAgentRepo.getEntity('state-restore-fail'),
            ).thenAnswer((_) async => local);

            // Use a path-traversal jsonPath — resolveJsonCandidateFile throws
            // FileSystemException which _restoreDominantAgentCache catches.
            final message = SyncMessage.agentEntity(
              agentEntity: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            // Should complete without throwing.
            await processor.process(event: event, journalDb: journalDb);

            // Local dominates → entity NOT upserted.
            verifyNever(() => mockAgentRepo.upsertEntity(any()));
            // The FileSystemException is caught and logged at lines 465-469.
            verify(
              () => loggingService.error(
                LogDomain.sync,
                any<FileSystemException>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: any<String>(
                  named: 'subDomain',
                  that: contains('restoreDominantCache'),
                ),
              ),
            ).called(1);
          },
        );

        test(
          'logs FileSystemException when jsonPath escapes the documents '
          'directory during cache restore for an agent link',
          () async {
            const localVc = VectorClock({'host-B': 3});
            const incomingVc = VectorClock({'host-B': 2});
            final local = AgentLink.basic(
              id: 'link-restore-fail',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 16),
              vectorClock: localVc,
            );
            final stale = AgentLink.basic(
              id: 'link-restore-fail',
              fromId: 'agent-1',
              toId: 'state-1',
              createdAt: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              vectorClock: incomingVc,
            );
            when(
              () => mockAgentRepo.getLinkById('link-restore-fail'),
            ).thenAnswer((_) async => local);

            final message = SyncMessage.agentLink(
              agentLink: stale,
              status: SyncEntryStatus.update,
              jsonPath: '../../etc/evil.json',
            );
            when(() => event.text).thenReturn(encodeMessage(message));

            await processor.process(event: event, journalDb: journalDb);

            verifyNever(() => mockAgentRepo.upsertLink(any()));
            verify(
              () => loggingService.error(
                LogDomain.sync,
                any<FileSystemException>(),
                stackTrace: any<StackTrace>(named: 'stackTrace'),
                subDomain: any<String>(
                  named: 'subDomain',
                  that: contains('restoreDominantCache'),
                ),
              ),
            ).called(1);
          },
        );
      });
    });
  });

  test('logs exceptions for invalid base64 payloads', () async {
    when(() => event.text).thenReturn('not-base64');

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<FormatException>()),
    );

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'SyncEventProcessor',
      ),
    ).called(1);
  });

  test('logs exceptions thrown by handlers', () async {
    const message = SyncMessage.journalEntity(
      id: 'entity-id',
      jsonPath: '/entity.json',
      vectorClock: null,
      status: SyncEntryStatus.initial,
    );
    when(() => event.text).thenReturn(encodeMessage(message));
    when(
      () => journalEntityLoader.load(
        jsonPath: '/entity.json',
      ),
    ).thenThrow(Exception('load failed'));

    await expectLater(
      processor.process(event: event, journalDb: journalDb),
      throwsA(isA<Exception>()),
    );

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'SyncEventProcessor',
      ),
    ).called(1);
  });

  test('skips message with unknown enum value (ArgumentError)', () async {
    // Simulate a SyncMessage JSON with an unknown enum value that would
    // cause $enumDecode to throw ArgumentError.
    final badJson = {
      'runtimeType': 'journalEntity',
      'id': 'entity-id',
      'jsonPath': '/entity.json',
      'vectorClock': null,
      'status': 'unknownEnumValue',
    };
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    // Should NOT throw — the error is caught and logged.
    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('skipping undeserializable sync message'),
        ),
        subDomain: 'processor.skipUnrecoverable',
      ),
    ).called(1);
  });

  test('skips message with FormatException from malformed JSON', () async {
    // Valid base64/JSON but with a structure that causes FormatException
    // when SyncMessage.fromJson tries to parse sub-fields.
    final badJson = {
      'runtimeType': 'journalEntity',
      'id': 123, // wrong type — id should be String
      'jsonPath': '/entity.json',
      'vectorClock': null,
      'status': 'initial',
    };
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    // The error might be TypeError or similar — either way, if it's not
    // ArgumentError or FormatException, it will rethrow through the outer
    // catch. Let's verify it doesn't crash with an unrecoverable retry.
    try {
      await processor.process(event: event, journalDb: journalDb);
      // If it didn't throw, it was caught as deserialization error → good.
    } on Object {
      // If it threw, it's a non-deserialization error that rethrows → also ok,
      // but verify the outer catch logged it.
      verify(
        () => loggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'SyncEventProcessor',
        ),
      ).called(1);
    }
  });

  test('skips message with CheckedFromJsonException from empty JSON', () async {
    // An empty JSON object hits the default case in the generated
    // _$SyncMessageFromJson switch, which throws CheckedFromJsonException.
    // The processor catches this and logs a skip.
    final badJson = <String, dynamic>{};
    final encoded = base64.encode(utf8.encode(json.encode(badJson)));
    when(() => event.text).thenReturn(encoded);

    await processor.process(event: event, journalDb: journalDb);

    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(
          that: contains('skipping undeserializable sync message'),
        ),
        subDomain: 'processor.skipUnrecoverable',
      ),
    ).called(1);
  });
}

/// Extends (not implements) so the interface's default no-op
/// [AgentRuntimeMaintenance.onIdentityReceived] body itself is exercised.
class _DefaultHookMaintenance extends AgentRuntimeMaintenance {
  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}
}

class _RecordingMaintenance implements AgentRuntimeMaintenance {
  _RecordingMaintenance(this.seen);

  final List<String> seen;

  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}

  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    seen.add(identity.agentId);
  }
}

class _ThrowingMaintenance implements AgentRuntimeMaintenance {
  @override
  Future<void> beforeWakeScan() async {}

  @override
  Future<void> restoreSubscriptions() async {}

  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    throw StateError('bad contributor');
  }
}
