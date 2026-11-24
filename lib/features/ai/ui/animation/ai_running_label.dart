import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The words for the AI-running band: what is in flight for [entryId], as
/// one quiet line with a chevron saying it opens the run's progress.
///
/// It sits *under* an action bar's controls, never over the animated bars —
/// the bars are the motion, this is the caption, and a capsule laid across
/// the animation hid the very thing it named. Nothing is drawn, and no
/// height is taken, while none of [responseTypes] is running.
class AiRunningLabel extends ConsumerWidget {
  const AiRunningLabel({
    required this.entryId,
    required this.responseTypes,
    super.key,
  });

  final String entryId;
  final Set<AiResponseType> responseTypes;

  /// The job [type] names, as the line says it. A null [type] is a run
  /// whose kind is not known yet, and says only that AI is working.
  static String labelFor(BuildContext context, AiResponseType? type) {
    final messages = context.messages;
    return switch (type) {
      AiResponseType.imageAnalysis => messages.aiRunningAnalyzingImage,
      AiResponseType.audioTranscription => messages.aiRunningTranscribingAudio,
      AiResponseType.audioSummary => messages.aiRunningSummarizingRecording,
      AiResponseType.promptGeneration ||
      AiResponseType.imagePromptGeneration => messages.aiRunningWritingPrompt,
      AiResponseType.imageGeneration => messages.aiRunningGeneratingImage,
      _ => messages.aiRunningWorking,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final isRunning = ref.watch(
      inferenceRunningControllerProvider((
        id: entryId,
        responseTypes: responseTypes,
      )),
    );
    // Which job is in flight — read from the same per-type status that makes
    // the band run at all. Every type is watched on every build, so the
    // subscriptions never depend on order.
    final running = [
      for (final type in responseTypes)
        if (ref.watch(
              inferenceStatusControllerProvider((
                id: entryId,
                aiResponseType: type,
              )),
            ) ==
            InferenceStatus.running)
          type,
    ];
    final type = running.firstOrNull;

    return AnimatedSize(
      duration: AiRunningDecoderBars.transitionDuration,
      alignment: Alignment.topCenter,
      child: !isRunning
          ? const SizedBox(width: double.infinity)
          : Semantics(
              button: true,
              liveRegion: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openAiRunningProgress(
                  context: context,
                  ref: ref,
                  entryId: entryId,
                  responseTypes: responseTypes,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Agent violet: the agent is the one working here.
                      Icon(
                        type?.icon ?? LottiIcons.aiSpark,
                        size: IconSizes.xs,
                        color: colors.aiCard.accent,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Flexible(
                        child: Text(
                          labelFor(context, type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(color: colors.text.mediumEmphasis),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step1),
                      Icon(
                        LottiIcons.chevronRight,
                        size: IconSizes.xs,
                        color: colors.text.mediumEmphasis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
