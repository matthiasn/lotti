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
import 'package:lotti/features/front_agent/ui/front_stage_controls.dart';
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

/// Opens her full screen, head to toe on her stage — on a desktop window as
/// on a phone — still speaking in [conversationId], with a way to answer
/// her and her voice's control at her feet ([FrontStageControls]), and the
/// conversation ([FrontStageTranscript]): beside her on a desktop window,
/// pointing at it while she says the tasks it lists
/// ([frontStagePointsProvider]); in a sheet from her top bar on a phone.
Future<void> openFrontStage(BuildContext context, String conversationId) =>
    openCompanionStage(
      context,
      sourceId: frontVoiceSourceId(conversationId),
      dressedFor: frontCompanionDressedFor,
      controls: FrontStageControls(conversationId: conversationId),
      sidePanel: const FrontStageTranscript(),
      sidePanelLabel: context.messages.frontChatStageConversation,
      pointsAtSidePanel: frontStagePointsProvider(conversationId),
    );

/// The conversation beside her on her stage: its thread, read only, on the
/// conversation's own ground. Whatever leaves her for a
/// page — a source, a project — closes the stage and her surface
/// both, so the page opens on top rather than behind them; a task she names
/// opens on top of the stage, and back returns to it.
class FrontStageTranscript extends StatelessWidget {
  const FrontStageTranscript({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      key: FrontVoiceControlKeys.transcript,
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          left: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: SafeArea(
        left: false,
        // Read only: the disc at her feet is the way to answer her here,
        // and the pane under the stage sends what is said.
        child: FrontChatThreadView(
          composerEnabled: false,
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
      onPlay: (_) =>
          FrontVoice.speak(ref, context, conversationId, answer).ignore(),
    );
  }
}
