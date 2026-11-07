import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_reply_parts.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';

/// Whether her reply to the latest turn in [thread] names tasks as a list
/// ([FrontReplyTasks]) — the card of task rows the conversation draws. Her
/// reply is her first after the turn, as her voice says it
/// ([frontSpokenAnswer]).
bool frontLatestReplyListsTasks(FrontChatThread thread) {
  final asked = thread.messages
      .where((m) => m.role == AgentChatRole.user)
      .lastOrNull;
  if (asked == null) return false;
  final reply = thread.messages
      .where(
        (m) =>
            m.role == AgentChatRole.agent &&
            !m.createdAt.isBefore(asked.createdAt),
      )
      .firstOrNull;
  return reply != null &&
      frontReplyParts(reply.text).any((part) => part is FrontReplyTasks);
}

/// Whether she points at the conversation beside her on her stage, for a
/// conversation id: while her voice plays there and her latest reply lists
/// tasks, so she points at their rows as she says them, and lets her arm
/// down once she has.
final ProviderFamily<bool, String> frontStagePointsProvider =
    Provider.family<bool, String>((
      ref,
      conversationId,
    ) {
      final sourceId = frontVoiceSourceId(conversationId);
      final speaking = ref.watch(
        ttsPlaybackControllerProvider.select(
          (s) =>
              s.status == TtsPlaybackStatus.playing && s.sourceId == sourceId,
        ),
      );
      if (!speaking) return false;
      final thread = ref.watch(frontChatThreadProvider).value;
      return thread != null && frontLatestReplyListsTasks(thread);
    }, name: 'frontStagePointsProvider');
