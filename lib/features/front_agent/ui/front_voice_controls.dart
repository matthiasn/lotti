import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/front_agent/ui/front_stage_controls.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her voice's controls.
@visibleForTesting
abstract final class FrontVoiceControlKeys {
  static const Key replay = Key('front-chat-voice-replay');
  static const Key stage = Key('front-chat-open-stage');
}

/// Opens her full screen, head to toe on her stage — on a desktop window as
/// on a phone — still speaking in [conversationId], with a way to answer
/// her and her voice's control at her feet ([FrontStageControls]).
Future<void> openFrontStage(BuildContext context, String conversationId) =>
    openCompanionStage(
      context,
      sourceId: frontVoiceSourceId(conversationId),
      dressedFor: frontCompanionDressedFor,
      controls: FrontStageControls(conversationId: conversationId),
    );

/// Her voice's control in [conversationId]: while she speaks it stops her;
/// once she has stopped it says her latest answer again, from the start.
///
/// Shown while she speaks — a stop is always within reach — and otherwise
/// only while she may speak and there is a settled answer to say: never in
/// the inbox, which gathers every conversation; never for a conversation
/// other than the one on screen, whose thread is the one read; never while
/// a send is in flight, a spoken reply is still owed (her own voice is about
/// to say it), or the thread or its journal answers' visibility is being
/// read again — the answer then may be partial, or rest on what is hidden.
class FrontVoiceButton extends ConsumerWidget {
  const FrontVoiceButton({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = frontVoiceSourceId(conversationId);
    final speaking = ref.watch(
      ttsPlaybackControllerProvider.select((s) => s.isActiveFor(sourceId)),
    );
    final maySpeak = FrontVoice.watchCanSpeak(ref, context);
    final inbox = ref.watch(frontInboxFilterProvider);
    final onScreen =
        ref.watch(frontActiveConversationProvider).value == conversationId;
    final settled =
        !ref.watch(frontChatControllerProvider.select((s) => s.isSending)) &&
        ref.watch(frontSpokenTurnProvider) == null;
    final thread = ref.watch(frontChatThreadProvider);
    final access = ref.watch(frontJournalAccessProvider);
    final answer = onScreen && !thread.isLoading && !access.isLoading
        ? frontLatestAnswer(
            thread.value ?? FrontChatThread.empty,
            journalAccess: access.value,
          )
        : '';
    if (!speaking && (inbox || !maySpeak || !settled || answer.isEmpty)) {
      return const SizedBox.shrink();
    }
    return TtsSourcePlayButton(
      key: FrontVoiceControlKeys.replay,
      sourceId: sourceId,
      playLabel: context.messages.frontChatReplayAnswer,
      onPlay: (_) =>
          FrontVoice.speak(ref, context, conversationId, answer).ignore(),
    );
  }
}

/// The way to her full-screen stage from the conversation.
class FrontStageButton extends StatelessWidget {
  const FrontStageButton({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context) => DsAiDiscButton(
    key: FrontVoiceControlKeys.stage,
    icon: LottiIcons.expandFull,
    label: context.messages.aiCardCompanionOpenFullScreen,
    onPressed: () => openFrontStage(context, conversationId).ignore(),
  );
}
