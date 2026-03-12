import 'package:lotti/features/ai/state/consts.dart';

/// Simple value object describing which automatic prompt checkboxes
/// should be visible in the audio recording modal.
class AutomaticPromptVisibility {
  const AutomaticPromptVisibility({
    required this.speech,
  });

  final bool speech;

  bool get none => !speech;
}

/// Derives visibility flags for automatic prompt checkboxes based on the
/// category configuration and current recording context.
///
/// - Speech checkbox is shown when at least one
///   `AiResponseType.audioTranscription` automatic prompt exists, or when
///   a profile-driven transcription skill is available
///   ([hasProfileTranscription]).
AutomaticPromptVisibility deriveAutomaticPromptVisibility({
  required Map<AiResponseType, List<String>>? automaticPrompts,
  bool hasProfileTranscription = false,
}) {
  final hasTranscription =
      automaticPrompts?[AiResponseType.audioTranscription]?.isNotEmpty ?? false;

  return AutomaticPromptVisibility(
    speech: hasTranscription || hasProfileTranscription,
  );
}
