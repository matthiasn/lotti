import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';

void main() {
  group('AgentDomainEntity.effectiveUpdatedAt', () {
    test('uses updatedAt for a mutable variant (state)', () {
      final entity = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024, 3, 16, 9, 30),
        vectorClock: null,
      );

      expect(
        entity.effectiveUpdatedAt.isAtSameMomentAs(
          DateTime(2024, 3, 16, 9, 30),
        ),
        isTrue,
      );
    });

    test('falls back to createdAt for an append-only variant (payload)', () {
      final entity = AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: 'agent-1',
        createdAt: DateTime(2024, 3, 15, 8),
        vectorClock: null,
        content: const {'k': 'v'},
      );

      expect(
        entity.effectiveUpdatedAt.isAtSameMomentAs(DateTime(2024, 3, 15, 8)),
        isTrue,
      );
    });

    test('prefers updatedAt over createdAt when a variant has both', () {
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
        updatedAt: DateTime(2024, 3, 20),
        vectorClock: null,
      );

      expect(
        entity.effectiveUpdatedAt.isAtSameMomentAs(DateTime(2024, 3, 20)),
        isTrue,
      );
    });
  });
}
