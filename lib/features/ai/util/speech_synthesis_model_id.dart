/// Whether a provider model id names a text-to-speech model.
///
/// Voxtral ships in two kinds that share the `voxtral-` prefix: transcription
/// (`voxtral-mini-latest`, audio in) and speech synthesis
/// (`voxtral-mini-tts-3-0`, audio out). Mistral's model list carries no
/// capability flag for speech output, so the id is all there is to go on: a
/// `tts` segment — separated by `-`, `_`, `.`, `/` or `:` — marks a speech
/// model. Matching the segment,
/// not a substring, keeps an unrelated id that merely contains the letters
/// on the transcription side.
bool isSpeechSynthesisModelId(String modelId) =>
    modelId.toLowerCase().split(RegExp('[-_./:]')).contains('tts');
