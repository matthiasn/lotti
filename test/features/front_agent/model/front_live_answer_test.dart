import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_live_answer.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';

void main() {
  final at = DateTime(2026, 11, 12, 9);
  AgentChatMessage message(String id, AgentChatRole role) =>
      AgentChatMessage(id: id, role: role, text: id, createdAt: at);

  FrontReplySurface surface(String id, String text) =>
      FrontReplySurface.compose(
        surfaceId: id,
        components: [
          {'component': FrontReplyComponents.text, 'text': text},
        ],
      );

  final live = FrontLiveAnswer(
    sourceMessageId: 'u2',
    replyId: 'a2',
    text: 'Two things are',
    surface: surface('a2', 'Two things are'),
    startedAt: at,
  );
  final earlier = surface('a1', 'Earlier.');
  final thread = FrontChatThread(
    messages: [
      message('u1', AgentChatRole.user),
      message('a1', AgentChatRole.agent),
      message('u2', AgentChatRole.user),
    ],
    surfacesByMessageId: {'a1': earlier},
    runKeys: const {'run-1'},
  );

  test('her answer in the writing is the last message of the thread whose '
      'turn it answers, under the id her stored reply will have', () {
    final shown = frontThreadWithLive(thread, live);

    expect([for (final m in shown.messages) m.id], ['u1', 'a1', 'u2', 'a2']);
    final hers = shown.messages.last;
    expect(hers.role, AgentChatRole.agent);
    expect(hers.text, 'Two things are');
    expect(hers.createdAt, at);
    expect(shown.surfacesByMessageId, {'a1': earlier, 'a2': live.surface});
    // The rest of the thread is as it was.
    expect(shown.runKeys, thread.runKeys);
    expect(shown.carrierOf('u2'), 'a2');
  });

  test('the thread itself comes back when there is nothing to add: no live '
      'answer, another conversation, or her stored reply already there', () {
    expect(identical(frontThreadWithLive(thread, null), thread), isTrue);

    // Its turn is not this thread's last message.
    final elsewhere = FrontChatThread(
      messages: [message('u9', AgentChatRole.user)],
    );
    expect(
      identical(frontThreadWithLive(elsewhere, live), elsewhere),
      isTrue,
    );
    expect(
      identical(
        frontThreadWithLive(FrontChatThread.empty, live),
        FrontChatThread.empty,
      ),
      isTrue,
    );

    // The stored reply landed: it is the one shown, once.
    final landed = FrontChatThread(
      messages: [...thread.messages, message('a2', AgentChatRole.agent)],
    );
    expect(identical(frontThreadWithLive(landed, live), landed), isTrue);
  });
}
