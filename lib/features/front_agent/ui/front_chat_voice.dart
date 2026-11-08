import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/device_datetime.dart';
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

  /// [canSpeak] with her voice, watched: a build calling it follows the
  /// switches, her mute and her profile's voice as they change — a provider
  /// first read when it is needed is still loading.
  static bool watchCanSpeak(WidgetRef ref, BuildContext context) {
    ref
      ..watch(configFlagProvider(enableCompanionFlag))
      ..watch(configFlagProvider(enableAiSummaryTtsFlag))
      ..watch(agentResolvedSetupProvider(frontAgentId))
      ..watch(companionCustomizationProvider);
    return canSpeak(ref, routeOf(ref, context));
  }

  /// Whether she answers aloud: only once her saved customization is known
  /// — a mute must never be guessed at — and while it lets her.
  static bool _speaksReplies(WidgetRef ref) => _speaks(
    ref.read(companionCustomizationProvider.notifier),
    ref.read(companionCustomizationProvider),
  );

  static bool _speaks(
    CompanionCustomizationController controller,
    CompanionCustomization customization,
  ) => controller.loaded && customization.speaksReplies;

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

  /// Speaks her answer to a spoken turn once it has landed in the
  /// conversation on screen — her reply and her doors' answers
  /// ([frontSpokenAnswer]) — and surfaces a voice that fails. Called from the
  /// pane's build.
  static void listenForSpokenReply(WidgetRef ref, BuildContext context) {
    // Kept live, so whether she may speak, and with which voice, is known
    // the moment her reply lands.
    watchCanSpeak(ref, context);
    ref.watch(frontInboxFilterProvider);
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
    void speakWhenLanded() {
      final turn = ref.read(frontSpokenTurnProvider);
      final next = ref.read(frontChatThreadProvider);
      // A thread reloading still holds its previous value, which may be the
      // reply without the answers its doors brought: wait for the new one.
      // So is what its journal answers may show: until that is read, a
      // journal answer is neither shown nor said.
      if (next.isLoading || ref.read(frontJournalAccessProvider).isLoading) {
        return;
      }
      final thread = next.value;
      if (turn == null || thread == null) return;
      // The inbox gathers every conversation, so a reply there may be
      // another's: hers is matched once its own conversation is back.
      if (ref.read(frontInboxFilterProvider)) return;
      if (ref.read(frontActiveConversationProvider).value !=
          turn.conversationId) {
        return;
      }
      // Her doors are walked inside the wake the send waits on: while it
      // runs, a reply may have landed without the answers in its doors. The
      // thread is projected again when the send settles.
      if (ref.read(frontChatControllerProvider).isSending) return;
      final answer = frontSpokenAnswer(
        thread,
        turn,
        journalAccess: ref.read(frontJournalAccessProvider).value,
      );
      if (!answer.landed) return;
      ref.read(frontSpokenTurnProvider.notifier).settle();
      if (answer.text.isEmpty) return;
      speak(ref, context, turn.conversationId, answer.text).ignore();
    }

    ref
      ..listen(frontChatThreadProvider, (_, _) => speakWhenLanded())
      ..listen(frontJournalAccessProvider, (_, _) => speakWhenLanded());
  }

  /// Makes a task of the inbox item [doorId] — the user's tap, the approval
  /// — and once it is made says so aloud in [conversationId]
  /// (`frontTaskCreatedSpoken`) through [speak], so her mute, her voice and
  /// the take-over hold as for any answer. A task not made says nothing; the
  /// door shows the failure.
  static Future<void> makeTask(
    WidgetRef ref,
    BuildContext context,
    String? conversationId,
    String doorId,
  ) async {
    final made = await ref
        .read(frontChatControllerProvider.notifier)
        .makeTask(doorId);
    if (!made || conversationId == null || !context.mounted) return;
    await speak(
      ref,
      context,
      conversationId,
      context.messages.frontTaskCreatedSpoken,
    );
  }

  /// Speaks [text] as her voice in [conversationId], from the start: once
  /// she may speak, taking the voice over from whatever else holds it, and
  /// held back if she is muted while it prepares.
  ///
  /// An answer said again is said in the voice it was first said in
  /// ([frontSaidProvider]), never in whichever her profile resolves to at
  /// the tap — a profile still resolving there would hand it to the
  /// on-device voice, and any other voice would make it again rather than
  /// play the clip kept from the first time.
  static Future<void> speak(
    WidgetRef ref,
    BuildContext context,
    String conversationId,
    String text,
  ) async {
    final route = ref
        .read(frontSaidProvider.notifier)
        .routeFor(conversationId, text, current: routeOf(ref, context));
    if (!canSpeak(ref, route)) return;
    ref.read(frontSaidProvider.notifier).said(conversationId, text, route);
    // The app's container, not the caller's ref: the control that started
    // her may be gone — her stage closed — by the time playback starts.
    final container = ProviderScope.containerOf(context, listen: false);
    final voice = ref.read(ttsPlaybackControllerProvider.notifier);
    // One utterance at a time: her answer takes the voice over.
    if (ref.read(ttsPlaybackControllerProvider).isBusy) await voice.stop();
    if (!context.mounted) return;
    // A date she wrote as her tools give it is said as a date, in the app's
    // language: "March 17, 2026", never "2026-03-17".
    final dateFormat = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    );
    await voice.speak(
      sourceId: frontVoiceSourceId(conversationId),
      text: replaceIsoDays(text, dateFormat.format),
      cloudRoute: route,
      // Asked again as playback starts: a mute while she was preparing holds.
      canPlay: () async => _speaks(
        container.read(companionCustomizationProvider.notifier),
        container.read(companionCustomizationProvider),
      ),
      confirmModelDownload: (model) => confirmTtsModelDownload(context, model),
    );
  }
}
