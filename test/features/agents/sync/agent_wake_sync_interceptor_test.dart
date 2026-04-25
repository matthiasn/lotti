import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_wake_sync_interceptor.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  final createdAt = DateTime(2024, 3, 15);

  AgentDomainEntity identity({
    required String id,
    required VectorClock vectorClock,
    String currentStateId = 'state-1',
  }) {
    return AgentDomainEntity.agent(
      id: id,
      agentId: id,
      kind: 'task_agent',
      displayName: 'Agent $id',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: currentStateId,
      config: const AgentConfig(),
      createdAt: createdAt,
      updatedAt: createdAt,
      vectorClock: vectorClock,
    );
  }

  AgentLink basicLink({
    required String id,
    required VectorClock vectorClock,
  }) {
    return AgentLink.basic(
      id: id,
      fromId: 'agent-1',
      toId: 'state-1',
      createdAt: createdAt,
      updatedAt: createdAt,
      vectorClock: vectorClock,
    );
  }

  test('builds one wake bundle from intercepted entity and link messages', () {
    final interceptor = AgentWakeSyncInterceptor(
      agentId: 'agent-1',
      wakeRunKey: 'run-1',
    );

    final entity = identity(
      id: 'agent-1',
      vectorClock: const VectorClock({'host': 1}),
    );
    final link = basicLink(
      id: 'link-1',
      vectorClock: const VectorClock({'host': 2}),
    );

    expect(
      interceptor.add(
        SyncMessage.agentEntity(
          status: SyncEntryStatus.update,
          agentEntity: entity,
        ),
      ),
      isTrue,
    );
    expect(
      interceptor.add(
        SyncMessage.agentLink(
          status: SyncEntryStatus.update,
          agentLink: link,
        ),
      ),
      isTrue,
    );

    final bundle = interceptor.buildBundle();

    expect(bundle, isNotNull);
    expect(bundle!.agentId, 'agent-1');
    expect(bundle.wakeRunKey, 'run-1');
    expect(bundle.entities.single.agentEntity, entity);
    expect(bundle.links.single.agentLink, link);
  });

  test('keeps latest payload and covers superseded vector clocks', () {
    final interceptor =
        AgentWakeSyncInterceptor(
            agentId: 'agent-1',
            wakeRunKey: 'run-1',
          )
          ..add(
            SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              agentEntity: identity(
                id: 'agent-1',
                vectorClock: const VectorClock({'host': 1}),
              ),
            ),
          )
          ..add(
            SyncMessage.agentEntity(
              status: SyncEntryStatus.update,
              agentEntity: identity(
                id: 'agent-1',
                currentStateId: 'state-2',
                vectorClock: const VectorClock({'host': 3}),
              ),
            ),
          );

    final bundledEntity = interceptor.buildBundle()!.entities.single;
    final coveredCounters = bundledEntity.coveredVectorClocks!
        .map((clock) => clock.vclock['host'])
        .whereType<int>()
        .toSet();

    expect(bundledEntity.agentEntity, isA<AgentIdentityEntity>());
    expect(
      (bundledEntity.agentEntity! as AgentIdentityEntity).currentStateId,
      'state-2',
    );
    // Only the SUPERSEDED clock (counter 1) is covered. The current clock
    // (counter 3) is added downstream by OutboxService._prepareAgentEntity.
    expect(coveredCounters, {1});
    expect(interceptor.entityCount, 1);
  });

  test('clear releases buffered messages', () {
    final interceptor =
        AgentWakeSyncInterceptor(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
        )..add(
          SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            agentLink: basicLink(
              id: 'link-1',
              vectorClock: const VectorClock({'host': 1}),
            ),
          ),
        );

    expect(interceptor.bufferedMessageCount, 1);

    interceptor.clear();

    expect(interceptor.bufferedMessageCount, 0);
    expect(interceptor.buildBundle(), isNull);
  });
}
