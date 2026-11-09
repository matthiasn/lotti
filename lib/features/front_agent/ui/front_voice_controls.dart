import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_stage_pointing.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for her voice's controls.
@visibleForTesting
abstract final class FrontVoiceControlKeys {
  static const Key replay = Key('front-chat-voice-replay');
  static const Key transcript = Key('front-chat-stage-transcript');
}

/// Opens her conversation full screen, her in a glass card floating over
/// it ([CompanionStagePage]) — on a desktop window as on a phone — still
/// speaking in [conversationId], her voice's control in the top row
/// ([FrontVoiceButton]), and the conversation as it is outside, its field
/// included ([FrontStageTranscript]), pointed at while she says the tasks it
/// lists ([frontStagePointsProvider]).
Future<void> openFrontStage(BuildContext context, String conversationId) =>
    openCompanionStage(
      context,
      sourceId: frontVoiceSourceId(conversationId),
      dressedFor: frontCompanionDressedFor,
      controls: FrontVoiceButton(conversationId: conversationId),
      conversation: ({required card, required bottomInset}) =>
          FrontStageTranscript(card: card, bottomInset: bottomInset),
      pointsAtConversation: frontStagePointsProvider(conversationId),
    );

/// The conversation on her stage: its thread and the field under it, on the
/// conversation's own ground — the same chat as outside the stage, so
/// whatever is typed or said is sent from here. Whatever leaves her for a
/// page — a source, a project — closes the stage and her surface
/// both, so the page opens on top rather than behind them; a task she names
/// opens on top of the stage, and back returns to it. Her [card] floats over
/// the thread, which keeps [bottomInset] of room after its last message.
class FrontStageTranscript extends StatelessWidget {
  const FrontStageTranscript({
    required this.card,
    required this.bottomInset,
    super.key,
  });

  final Widget card;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      key: FrontVoiceControlKeys.transcript,
      color: tokens.colors.background.level01,
      child: SafeArea(
        left: false,
        child: FrontChatThreadView(
          threadOverlay: card,
          threadBottomInset: bottomInset,
          onClose: () => Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }
}

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
      // "Again", not a speaker: the mute beside it is the speaker.
      idleIcon: LottiIcons.replay,
      onPlay: (_) =>
          FrontVoice.speak(ref, context, conversationId, answer).ignore(),
    );
  }
}
