import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/playback_failure_toast.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/features/tts/ui/widgets/tts_source_play_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// The control that reads a summary aloud — with the host's [cloudRoute]
/// when its profile names a cloud voice, else the on-device voice — its mode
/// and progress derived from the app-wide [TtsPlaybackController].
///
/// [text] is whatever the summary currently shows (the TL;DR alone when
/// collapsed, the TL;DR and the full report when expanded). It reflects an
/// active state only while [sourceId] is the playing source, so several
/// controls for other tasks never animate for one utterance — and two for
/// the same task (the card's header and the companion's full-screen view)
/// show the same one.
class SummaryReadAloudButton extends StatelessWidget {
  const SummaryReadAloudButton({
    required this.sourceId,
    required this.text,
    this.cloudRoute,
    this.playLabel,
    super.key,
  });

  final String sourceId;
  final String text;

  /// The cloud voice to speak with, or `null` for the on-device voice.
  final TtsCloudRoute? cloudRoute;

  /// What the idle control says it plays; a summary when null.
  final String? playLabel;

  /// The voice task [taskId]'s read-aloud speaks with: the read-aloud model
  /// of agent [agentId]'s profile, in the task's language, or `null` — the
  /// on-device voice — when the profile names none or there is no agent.
  static TtsCloudRoute? taskVoice(
    WidgetRef ref,
    BuildContext context, {
    required String? agentId,
    required String? taskId,
  }) {
    final task = taskId == null ? null : ref.watch(skillEntityProvider(taskId));
    return TtsCloudRoute.fromProfile(
      agentId == null
          ? null
          : ref.watch(agentResolvedSetupProvider(agentId)).value?.profile,
      languageCode:
          (task is Task ? task.data.languageCode : null) ??
          Localizations.localeOf(context).languageCode,
    );
  }

  /// Whether read-aloud may show with [voice]: switched on, and a voice to
  /// speak with — [voice] itself, or the on-device one where it runs.
  static bool canSpeak(WidgetRef ref, TtsCloudRoute? voice) =>
      (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false) &&
      (voice != null || ref.watch(ttsEngineProvider).isSupported);

  @override
  Widget build(BuildContext context) {
    return TtsSourcePlayButton(
      sourceId: sourceId,
      playLabel: playLabel,
      onPlay: (controller) => controller.speak(
        sourceId: sourceId,
        text: text,
        cloudRoute: cloudRoute,
        confirmModelDownload: (model) =>
            confirmTtsModelDownload(context, model),
      ),
    );
  }
}

/// A [SummaryReadAloudButton] for a generated prompt (a coding prompt) that
/// belongs to task [taskId], speaking with the voice that task's report
/// speaks with ([SummaryReadAloudButton.taskVoice]), under the prompt's own
/// [sourceId] so the report's control does not animate for it.
///
/// Renders nothing where the report's control would not show either: read
/// aloud switched off, or no voice to speak with. Without a task it speaks
/// with the on-device voice.
class TaskPromptReadAloudButton extends ConsumerWidget {
  const TaskPromptReadAloudButton({
    required this.taskId,
    required this.sourceId,
    required this.text,
    super.key,
  });

  final String? taskId;
  final String sourceId;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = this.taskId;
    final agent = taskId == null
        ? null
        : ref.watch(taskAgentProvider(taskId)).value;
    final agentId = agent is AgentIdentityEntity ? agent.agentId : null;
    final voice = SummaryReadAloudButton.taskVoice(
      ref,
      context,
      agentId: agentId,
      taskId: taskId,
    );
    listenForPlaybackFailure(ref, context, sourceId);
    if (text.isEmpty || !SummaryReadAloudButton.canSpeak(ref, voice)) {
      return const SizedBox.shrink();
    }
    return SummaryReadAloudButton(
      sourceId: sourceId,
      text: text,
      cloudRoute: voice,
      playLabel: context.messages.promptGenerationPlayTooltip,
    );
  }
}
