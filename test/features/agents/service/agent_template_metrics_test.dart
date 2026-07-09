// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_metrics.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/evolution_factories.dart';
import '../test_data/link_factories.dart';
import '../test_data/template_factories.dart';

/// Mirror test for the [AgentTemplateMetrics] collaborator. Confirms that the
/// metrics class composes its own SQL-aggregation reads with the shared
/// [AgentTemplateCrud] reads (linked agents, version history).
void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late AgentTemplateMetrics metrics;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});

    final crud = AgentTemplateCrud(
      repository: mockRepo,
      syncService: mockSync,
    );
    metrics = AgentTemplateMetrics(
      repository: mockRepo,
      syncService: mockSync,
      crud: crud,
    );
  });

  void stubAgentsForTemplate(List<AgentIdentityEntity> agents) {
    final links = agents
        .map(
          (a) => makeTestTemplateAssignmentLink(id: 'link-${a.id}', toId: a.id),
        )
        .toList();
    when(
      () => mockRepo.getLinksFrom(kTestTemplateId, type: 'template_assignment'),
    ).thenAnswer((_) async => links);
    when(() => mockRepo.getEntitiesByIds(any<Iterable<String>>())).thenAnswer(
      (invocation) async {
        final ids = invocation.positionalArguments.single as Iterable<String>;
        final agentsById = {for (final agent in agents) agent.id: agent};
        return <String, AgentDomainEntity>{
          for (final id in ids)
            if (agentsById[id] case final AgentIdentityEntity agent) id: agent,
        };
      },
    );
  }

  group('computeMetrics', () {
    test('derives success rate, average duration, and active count from the '
        'aggregate plus linked agents (via crud)', () async {
      when(
        () => mockRepo.aggregateWakeRunMetrics(kTestTemplateId),
      ).thenAnswer(
        (_) async => AggregateWakeRunMetricsByTemplateIdResult(
          successCount: 3,
          failureCount: 1,
          durationSumMs: 800,
          durationCount: 4,
          firstWakeAt: null,
          lastWakeAt: null,
        ),
      );
      when(
        () => mockRepo.countWakeRunsForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => 6);
      stubAgentsForTemplate([
        makeTestIdentity(id: 'a-active', agentId: 'a-active'),
        makeTestIdentity(
          id: 'a-dormant',
          agentId: 'a-dormant',
          lifecycle: AgentLifecycle.dormant,
        ),
      ]);

      final result = await metrics.computeMetrics(kTestTemplateId);

      expect(result.totalWakes, 6);
      expect(result.successCount, 3);
      expect(result.failureCount, 1);
      expect(result.successRate, 0.75); // 3 / (3 + 1)
      expect(result.averageDuration, const Duration(milliseconds: 200));
      expect(result.activeInstanceCount, 1); // only the active agent counts
    });

    test(
      'reports a zero success rate and null duration with no runs',
      () async {
        when(
          () => mockRepo.aggregateWakeRunMetrics(kTestTemplateId),
        ).thenAnswer(
          (_) async => AggregateWakeRunMetricsByTemplateIdResult(
            successCount: 0,
            failureCount: 0,
            durationSumMs: null,
            durationCount: 0,
            firstWakeAt: null,
            lastWakeAt: null,
          ),
        );
        when(
          () => mockRepo.countWakeRunsForTemplate(kTestTemplateId),
        ).thenAnswer((_) async => 0);
        stubAgentsForTemplate([]);

        final result = await metrics.computeMetrics(kTestTemplateId);

        expect(result.successRate, 0.0);
        expect(result.averageDuration, isNull);
        expect(result.activeInstanceCount, 0);
      },
    );
  });

  group('gatherEvolutionData', () {
    test('batch-fetches observation payloads by id', () async {
      final observationA = makeTestMessage(
        id: 'obs-a',
        kind: AgentMessageKind.observation,
        contentEntryId: 'payload-a',
      );
      final observationB = makeTestMessage(
        id: 'obs-b',
        kind: AgentMessageKind.observation,
        contentEntryId: 'payload-b',
      );
      final payloadA = makeTestMessagePayload(id: 'payload-a');
      final payloadB = makeTestMessagePayload(id: 'payload-b');

      when(
        () => mockRepo.aggregateWakeRunMetrics(kTestTemplateId),
      ).thenAnswer(
        (_) async => AggregateWakeRunMetricsByTemplateIdResult(
          successCount: 0,
          failureCount: 0,
          durationSumMs: null,
          durationCount: 0,
          firstWakeAt: null,
          lastWakeAt: null,
        ),
      );
      when(
        () => mockRepo.countWakeRunsForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => 0);
      when(
        () =>
            mockRepo.getLinksFrom(kTestTemplateId, type: 'template_assignment'),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[]);
      when(
        () => mockRepo.getRecentReportsByTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentReportEntity>[]);
      when(
        () => mockRepo.getRecentObservationsByTemplate(
          kTestTemplateId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [observationA, observationB]);
      when(
        () => mockRepo.getEvolutionNotes(kTestTemplateId, limit: 30),
      ).thenAnswer((_) async => [makeTestEvolutionNote()]);
      when(
        () => mockRepo.getEvolutionSessions(kTestTemplateId),
      ).thenAnswer((_) async => [makeTestEvolutionSession()]);
      when(
        () => mockRepo.getEntitiesByIds(any()),
      ).thenAnswer(
        (_) async => {
          payloadA.id: payloadA,
          payloadB.id: payloadB,
        },
      );
      when(
        () => mockRepo.countChangedSinceForTemplate(
          kTestTemplateId,
          any(),
        ),
      ).thenAnswer((_) async => 7);

      final result = await metrics.gatherEvolutionData(kTestTemplateId);

      expect(result.observationPayloads.keys, {'payload-a', 'payload-b'});
      expect(result.changesSinceLastSession, 7);
      final capturedIds =
          verify(
                () => mockRepo.getEntitiesByIds(captureAny()),
              ).captured.single
              as Iterable<String>;
      expect(capturedIds.toSet(), {'payload-a', 'payload-b'});
      verifyNever(() => mockRepo.getEntity('payload-a'));
      verifyNever(() => mockRepo.getEntity('payload-b'));
    });
  });

  group('profileInUse', () {
    test(
      'returns true when a template directly references the profile',
      () async {
        when(() => mockRepo.getAllTemplates()).thenAnswer(
          (_) async => [makeTestTemplate(profileId: 'target-profile')],
        );

        expect(await metrics.profileInUse('target-profile'), isTrue);
        // Short-circuits before checking versions/agents.
        verifyNever(() => mockRepo.getAllAgentIdentities());
      },
    );

    test(
      'returns true when a template version references the profile',
      () async {
        when(() => mockRepo.getAllTemplates()).thenAnswer(
          (_) async => [makeTestTemplate()],
        );
        when(
          () => mockRepo.getEntitiesByAgentId(
            kTestTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => <AgentDomainEntity>[
            makeTestTemplateVersion(profileId: 'target-profile'),
          ],
        );

        expect(await metrics.profileInUse('target-profile'), isTrue);
        verifyNever(() => mockRepo.getAllAgentIdentities());
      },
    );

    test(
      'returns false when no template, version, or agent references it',
      () async {
        when(() => mockRepo.getAllTemplates()).thenAnswer(
          (_) async => [makeTestTemplate()],
        );
        when(
          () => mockRepo.getEntitiesByAgentId(
            kTestTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => <AgentDomainEntity>[makeTestTemplateVersion()],
        );
        when(() => mockRepo.getAllAgentIdentities()).thenAnswer(
          (_) async => [
            makeTestIdentity(
              id: 'a1',
              agentId: 'a1',
              config: const AgentConfig(profileId: 'other-profile'),
            ),
          ],
        );

        expect(await metrics.profileInUse('target-profile'), isFalse);
      },
    );
  });
}
