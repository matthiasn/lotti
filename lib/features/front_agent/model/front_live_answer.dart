import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';

/// Her answer while she is still writing it: what a running turn has
/// streamed so far. Held in memory only — the stored reply is what lasts.
@immutable
class FrontLiveAnswer {
  const FrontLiveAnswer({
    required this.sourceMessageId,
    required this.replyId,
    required this.text,
    required this.surface,
    required this.startedAt,
  });

  /// The user turn she is answering, which says whose conversation it is.
  final String sourceMessageId;

  /// The id her stored reply will have, so the stored reply takes this
  /// one's place on screen instead of being added beside it.
  final String replyId;

  /// Her prose so far.
  final String text;

  /// What she has drawn so far, with her prose.
  final FrontReplySurface surface;

  final DateTime startedAt;
}

/// [thread] with [live] as its last message, when [live] answers a turn of
/// this thread and her stored reply has not landed in it yet; otherwise
/// [thread] itself, so a caller can tell by identity whether it was added.
FrontChatThread frontThreadWithLive(
  FrontChatThread thread,
  FrontLiveAnswer? live,
) {
  if (live == null ||
      thread.messages.lastOrNull?.id != live.sourceMessageId ||
      thread.messages.any((message) => message.id == live.replyId)) {
    return thread;
  }
  return FrontChatThread(
    messages: [
      ...thread.messages,
      AgentChatMessage(
        id: live.replyId,
        role: AgentChatRole.agent,
        text: live.text,
        createdAt: live.startedAt,
      ),
    ],
    optionsByMessageId: thread.optionsByMessageId,
    doorsByMessageId: thread.doorsByMessageId,
    specialistAgentIds: thread.specialistAgentIds,
    entityPreviewsByMessageId: thread.entityPreviewsByMessageId,
    surfacesByMessageId: {
      ...thread.surfacesByMessageId,
      live.replyId: live.surface,
    },
    runKeys: thread.runKeys,
  );
}
