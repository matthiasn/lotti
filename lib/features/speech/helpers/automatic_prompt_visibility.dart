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
/// current recording context.
///
/// - Speech checkbox is shown when a profile-driven transcription skill is
///   available ([hasProfileTranscription]).
AutomaticPromptVisibility deriveAutomaticPromptVisibility({
  bool hasProfileTranscription = false,
}) {
  return AutomaticPromptVisibility(
    speech: hasProfileTranscription,
  );
}
