import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/relationships/model/relationship_agent_identity.dart';

void main() {
  final agentId = relationshipAgentIdFor('person-1');

  AgentIdentityEntity identity({
    String kind = AgentKinds.relationshipAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: kind,
            displayName: 'Anna',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  group('usableRelationshipAgent', () {
    test('returns the identity only for an active relationship agent', () {
      final active = identity();
      expect(usableRelationshipAgent(active), same(active));
    });

    test('is null for every other lifecycle — destroy keeps the row', () {
      for (final lifecycle in AgentLifecycle.values) {
        if (lifecycle == AgentLifecycle.active) continue;
        expect(
          usableRelationshipAgent(identity(lifecycle: lifecycle)),
          isNull,
          reason: '$lifecycle is not a chat the pane will open',
        );
      }
    });

    test('is null for another kind, a non-identity row, or nothing', () {
      expect(usableRelationshipAgent(identity(kind: 'task_agent')), isNull);
      expect(usableRelationshipAgent(null), isNull);
      expect(
        usableRelationshipAgent(
          AgentDomainEntity.agentReport(
            id: 'report',
            agentId: agentId,
            scope: 'current',
            createdAt: DateTime(2026),
            vectorClock: null,
            content: 'x',
          ),
        ),
        isNull,
      );
    });
  });
}
