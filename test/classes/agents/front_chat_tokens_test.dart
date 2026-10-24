import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';

void main() {
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

  group('front chat recovery workspace', () {
    test('is keyed per message under the front-chat prefix', () {
      expect(frontChatRecoveryWorkspaceKey('m-1'), 'front-chat:m-1');
      expect(
        frontChatRecoveryRecordId('front_agent', 'm-1'),
        'scheduled_wake:front_agent:front-chat:m-1',
      );
    });

    test('the lease predicate recognises it and nothing else', () {
      expect(isFrontChatRecoveryWorkspace('front-chat:m-1'), isTrue);
      expect(isFrontChatRecoveryWorkspace('goal-chat:m-1'), isFalse);
      expect(isFrontChatRecoveryWorkspace('front-chat'), isFalse);
      expect(isFrontChatRecoveryWorkspace(null), isFalse);
    });

    test("the grace is the goal chat's three run caps", () {
      expect(frontChatRecoveryGrace, const Duration(minutes: 30));
    });
  });
}
