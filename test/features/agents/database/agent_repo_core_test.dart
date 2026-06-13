import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';
import '../test_data/soul_factories.dart';

/// Mirror tests for [AgentRepoCore]. They construct the collaborator directly
/// against a real in-memory [AgentDatabase] (wired to a real
/// [AgentAttentionProjection], exactly as the facade does) and assert on the
/// entity-CRUD and shared batched-read behaviour it owns.
void main() {
  late AgentDatabase db;
  late AgentRepoCore core;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    core = AgentRepoCore(db);
    // Wire the Core ↔ projection cycle the same way [AgentRepository] does so
    // upsertEntity has a live projection collaborator.
    core.projection = AgentAttentionProjection(db, core);
  });

  tearDown(() async {
    await db.close();
  });

  group('upsertEntity / getEntity', () {
    test('inserts then updates a non-projection entity in place', () async {
      final identity = makeTestIdentity(
        id: 'agent-entity-1',
        agentId: 'agent-1',
        displayName: 'Original',
        createdAt: testDate,
        updatedAt: testDate,
      );
      await core.upsertEntity(identity);

      final fetched = await core.getEntity('agent-entity-1');
      expect(fetched, isA<AgentIdentityEntity>());
      expect((fetched! as AgentIdentityEntity).displayName, 'Original');

      await core.upsertEntity(
        makeTestIdentity(
          id: 'agent-entity-1',
          agentId: 'agent-1',
          displayName: 'Renamed',
          createdAt: testDate,
          updatedAt: testDate,
        ),
      );

      final updated =
          await core.getEntity('agent-entity-1') as AgentIdentityEntity?;
      expect(updated!.displayName, 'Renamed');
    });

    test('getEntity returns null for an unknown id', () async {
      expect(await core.getEntity('missing'), isNull);
    });

    test(
      'upsertEntity of an attention request populates the claim projection',
      () async {
        final claim =
            AgentDomainEntity.attentionRequest(
                  id: 'claim-1',
                  agentId: 'agent-1',
                  kind: AttentionRequestKind.task,
                  title: 'Focus block',
                  categoryId: 'work',
                  requestedMinutes: 30,
                  impact: 3,
                  urgency: 3,
                  energyFit: AttentionEnergyFit.neutral,
                  evidenceRefs: const [],
                  scopeKind: AttentionClaimScopeKind.dateRange,
                  rangeStart: DateTime(2026, 3, 15, 9),
                  rangeEnd: DateTime(2026, 3, 15, 12),
                  targetId: 'task-1',
                  targetKind: 'task',
                  createdAt: testDate,
                  vectorClock: const VectorClock({'node-1': 1}),
                )
                as AttentionRequestEntity;

        await core.upsertEntity(claim);

        // The projection row is the read path; if upsertEntity wired it,
        // the window query (which reads only the index) returns the claim.
        final claims = await core.projection.getAttentionClaimsForWindow(
          start: DateTime(2026, 3, 15, 8),
          end: DateTime(2026, 3, 15, 13),
        );
        expect(claims.map((c) => c.id), ['claim-1']);
      },
    );
  });

  group('getEntitiesByIds', () {
    test('returns matched entities keyed by id and omits the rest', () async {
      await core.upsertEntity(
        makeTestIdentity(id: 'e1', agentId: 'a1', createdAt: testDate),
      );
      await core.upsertEntity(
        makeTestIdentity(id: 'e2', agentId: 'a2', createdAt: testDate),
      );

      final result = await core.getEntitiesByIds(['e1', 'e2', 'missing']);
      expect(result.keys, containsAll(['e1', 'e2']));
      expect(result.containsKey('missing'), isFalse);
      expect(result['e1'], isA<AgentIdentityEntity>());
    });

    test('empty input returns an empty map without a query', () async {
      expect(await core.getEntitiesByIds(const []), isEmpty);
    });
  });

  group('latestEntitiesByAgentIds', () {
    test('keeps only the newest row per agent', () async {
      // AgentStateEntity has no `createdAt`; the row's `created_at` column is
      // written from `updatedAt`, which is what the ROW_NUMBER ordering uses.
      await core.upsertEntity(
        makeTestState(
          id: 'state-old',
          agentId: 'agent-1',
          updatedAt: DateTime(2026, 3, 14),
        ),
      );
      await core.upsertEntity(
        makeTestState(
          id: 'state-new',
          agentId: 'agent-1',
          revision: 2,
          updatedAt: DateTime(2026, 3, 16),
        ),
      );

      final latest = await core.latestEntitiesByAgentIds(
        agentIds: ['agent-1'],
        type: AgentEntityTypes.agentState,
      );
      expect(latest.map((e) => e.id), ['state-new']);
    });
  });

  group('getAgentStatesByAgentIds', () {
    test('maps each agent to its latest state, omitting stateless', () async {
      await core.upsertEntity(
        makeTestState(id: 's1', agentId: 'agent-1', updatedAt: testDate),
      );

      final states = await core.getAgentStatesByAgentIds([
        'agent-1',
        'agent-2',
      ]);
      expect(states.keys, ['agent-1']);
      expect(states['agent-1']!.id, 's1');
    });
  });

  group('getActiveSoulDocumentVersionsBySoulIds', () {
    test('resolves the active version via the head pointer', () async {
      await core.upsertEntity(
        makeTestSoulDocumentVersion(
          id: 'soul-ver-1',
          agentId: 'soul-1',
          createdAt: testDate,
        ),
      );
      await core.upsertEntity(
        makeTestSoulDocumentHead(
          id: 'soul-head-1',
          agentId: 'soul-1',
          versionId: 'soul-ver-1',
          updatedAt: testDate,
        ),
      );

      final versions = await core.getActiveSoulDocumentVersionsBySoulIds([
        'soul-1',
      ]);
      expect(versions['soul-1']!.id, 'soul-ver-1');
    });

    test('returns empty for souls without a head', () async {
      expect(
        await core.getActiveSoulDocumentVersionsBySoulIds(['none']),
        isEmpty,
      );
    });
  });

  group('getCaptureEventMetaByAgentId', () {
    test('returns id + timestamps without materializing content', () async {
      await core.upsertEntity(
        makeTestCapture(
          id: 'cap-1',
          agentId: 'agent-1',
          createdAt: testDate,
          capturedAt: DateTime(2026, 3, 15, 10),
        ),
      );

      final metas = await core.getCaptureEventMetaByAgentId('agent-1');
      expect(metas, hasLength(1));
      expect(metas.single.id, 'cap-1');
      expect(metas.single.capturedAt, DateTime(2026, 3, 15, 10));
    });
  });
}
