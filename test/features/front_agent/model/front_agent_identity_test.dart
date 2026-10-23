import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';

import '../../agents/test_data/entity_factories.dart';

void main() {
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

  group('front chat trigger tokens', () {
    test('round-trips the message id through the token', () {
      final token = frontChatMessageTriggerToken('msg-42');
      expect(token, 'front-chat-message:msg-42');
      expect(frontChatMessageIdFromTriggerTokens({token}), 'msg-42');
    });

    test('ignores other tokens and an empty id', () {
      expect(
        frontChatMessageIdFromTriggerTokens({
          'goal-chat-message:x',
          'front-chat-message:',
        }),
        isNull,
      );
      expect(frontChatMessageIdFromTriggerTokens(const {}), isNull);
    });

    test('picks the chat token out of a mixed set', () {
      expect(
        frontChatMessageIdFromTriggerTokens({
          'processing_job:1',
          frontChatMessageTriggerToken('m'),
        }),
        'm',
      );
    });
  });
}
