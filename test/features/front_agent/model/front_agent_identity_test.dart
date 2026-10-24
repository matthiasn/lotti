import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';

import '../../agents/test_data/entity_factories.dart';

void main() {
  test('the front agent has one fixed id', () {
    expect(frontAgentId, 'front_agent');
  });

  group('usableFrontAgent', () {
    test('accepts only an active front_agent identity', () {
      final active = makeTestIdentity(
        id: frontAgentId,
        agentId: frontAgentId,
        kind: AgentKinds.frontAgent,
      );
      expect(usableFrontAgent(active), same(active));
    });

    test('refuses a dormant front agent, another kind, and a non-identity', () {
      expect(
        usableFrontAgent(
          makeTestIdentity(
            kind: AgentKinds.frontAgent,
            lifecycle: AgentLifecycle.dormant,
          ),
        ),
        isNull,
      );
      expect(
        usableFrontAgent(makeTestIdentity(kind: AgentKinds.goalAgent)),
        isNull,
      );
      expect(usableFrontAgent(makeTestMessage()), isNull);
      expect(usableFrontAgent(null), isNull);
    });
  });
}
