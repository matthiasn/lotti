import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The words on the AI-running band: what is in flight, in a small capsule
/// over the animated bars, with a chevron saying the band opens its progress.
///
/// The bars alone said nothing a sighted reader could act on — frozen in a
/// screenshot they read as a rendering glitch. A null [type] means a run
/// whose kind is not known yet, and says only that AI is working.
class AiRunningLabel extends StatelessWidget {
  const AiRunningLabel({required this.type, super.key});

  final AiResponseType? type;

  /// The job [type] names, as the band says it.
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
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background.level01,
        borderRadius: BorderRadius.circular(tokens.radii.xl),
        border: Border.all(color: colors.aiCard.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Agent violet: the agent is the one speaking here.
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
                style: tokens.typography.styles.others.caption.copyWith(
                  color: colors.text.highEmphasis,
                ),
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
    );
  }
}
