import 'package:lotti/features/ai/state/consts.dart';

/// Simple value object describing which automatic prompt checkboxes
/// should be visible in the audio recording modal.
class AutomaticPromptVisibility {
  const AutomaticPromptVisibility({
    required this.speech,
    required this.checklist,
    required this.summary,
  });

  final bool speech;
  final bool checklist;
  final bool summary;

  bool get none => !speech && !checklist && !summary;
}

/// Derives visibility flags for automatic prompt checkboxes based on the
/// category configuration and current recording context.
///
/// - Speech checkbox is shown only if there is at least one
///   `AiResponseType.audioTranscription` automatic prompt.
/// - Checklist and Task Summary checkboxes require:
///   - A linked task is present
///   - Speech recognition is effectively enabled (user preference is not false)
///   - The category has at least one automatic prompt for the respective type
AutomaticPromptVisibility deriveAutomaticPromptVisibility({
  required Map<AiResponseType, List<String>>? automaticPrompts,
  required bool hasLinkedTask,
  bool? userSpeechPreference,
}) {
  final hasTranscription = automaticPrompts != null &&
      automaticPrompts.containsKey(AiResponseType.audioTranscription) &&
      (automaticPrompts[AiResponseType.audioTranscription]?.isNotEmpty ??
          false);

  final hasChecklist = automaticPrompts != null &&
      automaticPrompts.containsKey(AiResponseType.checklistUpdates) &&
      (automaticPrompts[AiResponseType.checklistUpdates]?.isNotEmpty ?? false);

  final hasSummary = automaticPrompts != null &&
      automaticPrompts.containsKey(AiResponseType.taskSummary) &&
      (automaticPrompts[AiResponseType.taskSummary]?.isNotEmpty ?? false);

  // Effective speech: user preference (default true) gated by availability
  final isSpeechEnabled = (userSpeechPreference ?? true) && hasTranscription;

  final showSpeech = hasTranscription;
  final showChecklist = hasLinkedTask && isSpeechEnabled && hasChecklist;
  final showSummary = hasLinkedTask && isSpeechEnabled && hasSummary;

  return AutomaticPromptVisibility(
    speech: showSpeech,
    checklist: showChecklist,
    summary: showSummary,
  );
}
