import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_stage_pointing.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';

import '../../tts/test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 7, 9);

  AgentChatMessage message(
    String id,
    AgentChatRole role,
    String text, {
    int second = 0,
  }) => AgentChatMessage(
    id: id,
    role: role,
    text: text,
    createdAt: at.add(Duration(seconds: second)),
  );

  const list = '''
Two are due today:

- [Count the hatchlings](lotti://task/t1)
- [Check the nest cameras](lotti://task/t2)''';
  const oneLink = 'Only [Count the hatchlings](lotti://task/t1) is due.';

  FrontChatThread thread(List<AgentChatMessage> messages) =>
      FrontChatThread(messages: messages);

  group('frontLatestReplyListsTasks', () {
    test('her reply to the latest turn lists tasks', () {
      expect(
        frontLatestReplyListsTasks(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, list, second: 1),
          ]),
        ),
        isTrue,
      );
    });

    test('a single task link is not a list', () {
      expect(
        frontLatestReplyListsTasks(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, oneLink, second: 1),
          ]),
        ),
        isFalse,
      );
    });

    test('a list in an earlier reply is not the one she is saying', () {
      expect(
        frontLatestReplyListsTasks(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, list, second: 1),
            message('u2', AgentChatRole.user, 'Thanks', second: 2),
            message('a2', AgentChatRole.agent, 'Any time.', second: 3),
          ]),
        ),
        isFalse,
      );
    });

    test('no turn, or no reply yet, lists nothing', () {
      expect(frontLatestReplyListsTasks(FrontChatThread.empty), isFalse);
      expect(
        frontLatestReplyListsTasks(
          thread([
            message('a0', AgentChatRole.agent, list),
            message('u1', AgentChatRole.user, 'What is due?', second: 1),
          ]),
        ),
        isFalse,
      );
    });
  });

  group('frontStagePointsProvider', () {
    /// Whether she points in conversation c-1 once its thread has loaded,
    /// with the voice at [status] for [sourceId] and [reply] her answer.
    Future<bool> points({
      required TtsPlaybackStatus status,
      String sourceId = 'front-chat:c-1',
      String reply = list,
    }) async {
      final container = ProviderContainer(
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => FixedTtsPlayback(
              TtsPlaybackState(status: status, sourceId: sourceId),
            ),
          ),
          frontChatThreadProvider.overrideWith(
            (ref) async => thread([
              message('u1', AgentChatRole.user, 'What is due?'),
              message('a1', AgentChatRole.agent, reply, second: 1),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(frontStagePointsProvider('c-1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(frontChatThreadProvider.future);
      return sub.read();
    }

    test('points while her voice says a reply that lists tasks', () async {
      expect(frontVoiceSourceId('c-1'), 'front-chat:c-1');
      expect(await points(status: TtsPlaybackStatus.playing), isTrue);
    });

    test('not while she says a reply without a list', () async {
      expect(
        await points(status: TtsPlaybackStatus.playing, reply: oneLink),
        isFalse,
      );
    });

    test('never while she prepares, is silent, or speaks elsewhere', () async {
      expect(await points(status: TtsPlaybackStatus.synthesizing), isFalse);
      expect(await points(status: TtsPlaybackStatus.idle), isFalse);
      expect(
        await points(
          status: TtsPlaybackStatus.playing,
          sourceId: 'front-chat:c-2',
        ),
        isFalse,
      );
    });
  });
}
