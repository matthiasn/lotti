import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Her voice in the conversation: the route it speaks through and whether
/// it may speak at all — the companion and read-aloud switched on, and a
/// voice to speak with, her profile's cloud voice or the on-device one.
abstract final class FrontVoice {
  /// The cloud voice her profile names, in the app's language; null for the
  /// on-device voice.
  static TtsCloudRoute? routeOf(WidgetRef ref, BuildContext context) =>
      TtsCloudRoute.fromProfile(
        ref.read(agentResolvedSetupProvider(frontAgentId)).value?.profile,
        languageCode: Localizations.localeOf(context).languageCode,
      );

  /// Whether she may speak, with [route] as her voice.
  static bool canSpeak(WidgetRef ref, TtsCloudRoute? route) {
    bool on(String flag) => ref.read(configFlagProvider(flag)).value ?? false;
    return on(enableCompanionFlag) &&
        on(enableAiSummaryTtsFlag) &&
        _speaksReplies(ref) &&
        (route != null || ref.read(ttsEngineProvider).isSupported);
  }

  /// Whether she answers aloud: only once her saved customization is known
  /// — a mute must never be guessed at — and while it lets her.
  static bool _speaksReplies(WidgetRef ref) =>
      ref.read(companionCustomizationProvider.notifier).loaded &&
      ref.read(companionCustomizationProvider).speaksReplies;

  /// The pose she holds: listening while the user speaks, thinking while
  /// her answer is on its way; none at rest.
  static GestureName? holdingOf(WidgetRef ref) {
    final recording = ref.watch(
      chatRecorderControllerProvider.select(
        (s) => s.status == ChatRecorderStatus.recording,
      ),
    );
    if (recording) return GestureName.listen;
    final working =
        ref.watch(frontChatControllerProvider.select((s) => s.isSending)) ||
        ref.watch(frontSpokenTurnProvider) != null;
    return working ? GestureName.think : null;
  }

  /// Speaks her reply to a spoken turn as it lands in the conversation on
  /// screen — the first of hers after the turn — and surfaces a voice that
  /// fails. Called from the pane's build.
  static void listenForSpokenReply(WidgetRef ref, BuildContext context) {
    // Kept live, so whether she may speak, and with which voice, is known
    // the moment her reply lands — a provider first read then is still
    // loading.
    ref
      ..watch(configFlagProvider(enableCompanionFlag))
      ..watch(configFlagProvider(enableAiSummaryTtsFlag))
      ..watch(agentResolvedSetupProvider(frontAgentId))
      ..watch(frontInboxFilterProvider)
      ..watch(companionCustomizationProvider);
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    // Muted while she speaks — here or synced from another device — her own
    // voice stops; any other source speaks on.
    ref.listen(
      companionCustomizationProvider.select((c) => c.speaksReplies),
      (_, speaks) {
        // Whichever conversation she is speaking in — the user may have
        // opened another since — never another source.
        final playing = ref.read(ttsPlaybackControllerProvider).sourceId;
        if (!speaks && playing != null && isFrontVoiceSourceId(playing)) {
          ref
              .read(ttsPlaybackControllerProvider.notifier)
              .stop(sourceId: playing)
              .ignore();
        }
      },
    );
    if (conversationId != null) {
      listenForPlaybackFailure(
        ref,
        context,
        frontVoiceSourceId(conversationId),
      );
    }
    ref.listen(frontChatThreadProvider, (_, next) {
      final turn = ref.read(frontSpokenTurnProvider);
      final messages = next.value?.messages;
      if (turn == null || messages == null) return;
      // The inbox gathers every conversation, so a reply there may be
      // another's: hers is matched once its own conversation is back.
      if (ref.read(frontInboxFilterProvider)) return;
      if (ref.read(frontActiveConversationProvider).value !=
          turn.conversationId) {
        return;
      }
      final reply = messages
          .where(
            (m) =>
                m.role == AgentChatRole.agent &&
                !m.createdAt.isBefore(turn.spokenAt),
          )
          .firstOrNull;
      if (reply == null) return;
      ref.read(frontSpokenTurnProvider.notifier).settle();
      _speak(ref, context, turn.conversationId, reply.text).ignore();
    });
  }

  static Future<void> _speak(
    WidgetRef ref,
    BuildContext context,
    String conversationId,
    String text,
  ) async {
    final route = routeOf(ref, context);
    if (!canSpeak(ref, route)) return;
    final voice = ref.read(ttsPlaybackControllerProvider.notifier);
    // One utterance at a time: her answer takes the voice over.
    if (ref.read(ttsPlaybackControllerProvider).isBusy) await voice.stop();
    if (!context.mounted) return;
    await voice.speak(
      sourceId: frontVoiceSourceId(conversationId),
      text: text,
      cloudRoute: route,
      // Asked again as playback starts: a mute while she was preparing holds.
      canPlay: () async => _speaksReplies(ref),
      confirmModelDownload: (model) => confirmTtsModelDownload(context, model),
    );
  }
}
