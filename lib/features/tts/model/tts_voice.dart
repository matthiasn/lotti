import 'package:flutter/foundation.dart';

/// Gender grouping for a Supertonic pre-baked voice. Used purely to label
/// and group voices in the picker — the synthesis itself is driven by the
/// voice-style JSON keyed on [TtsVoice.id].
enum TtsVoiceGender { female, male }

/// One of Supertonic's pre-baked voice styles.
///
/// Supertonic ships ten fixed voices — five female (`F1`–`F5`) and five male
/// (`M1`–`M5`). Each maps to a voice-style JSON bundled under
/// `assets/tts/voice_styles/<id>.json`; the engine loads that file via
/// `loadVoiceStyle` before synthesis. We deliberately keep the upstream IDs
/// rather than inventing persona names so the catalog stays faithful to the
/// assets actually shipped.
@immutable
class TtsVoice {
  const TtsVoice({required this.id, required this.gender});

  /// Upstream Supertonic style id, e.g. `F1`. Also the basename of the
  /// voice-style asset (`assets/tts/voice_styles/F1.json`).
  final String id;

  /// Female/male grouping used only to label and tab the picker; it does not
  /// affect synthesis, which is driven entirely by the voice-style JSON.
  final TtsVoiceGender gender;

  /// Asset file name for this voice's style JSON.
  String get assetFileName => '$id.json';

  @override
  bool operator ==(Object other) =>
      other is TtsVoice && other.id == id && other.gender == gender;

  @override
  int get hashCode => Object.hash(id, gender);

  @override
  String toString() => 'TtsVoice($id, $gender)';
}

/// The ten pre-baked Supertonic voices, female first so the default and the
/// female options the user asked for lead the picker.
const List<TtsVoice> kSupertonicVoices = <TtsVoice>[
  TtsVoice(id: 'F1', gender: TtsVoiceGender.female),
  TtsVoice(id: 'F2', gender: TtsVoiceGender.female),
  TtsVoice(id: 'F3', gender: TtsVoiceGender.female),
  TtsVoice(id: 'F4', gender: TtsVoiceGender.female),
  TtsVoice(id: 'F5', gender: TtsVoiceGender.female),
  TtsVoice(id: 'M1', gender: TtsVoiceGender.male),
  TtsVoice(id: 'M2', gender: TtsVoiceGender.male),
  TtsVoice(id: 'M3', gender: TtsVoiceGender.male),
  TtsVoice(id: 'M4', gender: TtsVoiceGender.male),
  TtsVoice(id: 'M5', gender: TtsVoiceGender.male),
];

/// Default voice — a female voice, per the product requirement to lead with a
/// smooth female option.
const String kDefaultTtsVoiceId = 'F1';

/// Resolves [voiceId] to a catalog voice, falling back to the default voice
/// when the id is unknown or `null` (e.g. a stale persisted value after the
/// catalog changes). Never returns `null` so callers always have a usable
/// voice to synthesize with.
TtsVoice ttsVoiceByIdOrDefault(String? voiceId) {
  for (final voice in kSupertonicVoices) {
    if (voice.id == voiceId) return voice;
  }
  return kSupertonicVoices.firstWhere((v) => v.id == kDefaultTtsVoiceId);
}
