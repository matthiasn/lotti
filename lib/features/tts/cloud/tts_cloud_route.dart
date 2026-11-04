import 'package:flutter/foundation.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';

/// The provider types with a speech client here: Mistral (Voxtral TTS) and
/// ElevenLabs. Another provider joins by adding its type here and its
/// client to `cloudTtsClientsProvider`.
const Set<InferenceProviderType> cloudSpeechProviderTypes = {
  InferenceProviderType.elevenLabs,
  InferenceProviderType.mistral,
};

/// A cloud voice one utterance is spoken with: the read-aloud model of the
/// profile that resolved for the speaking surface, on that model's provider,
/// in the language of the text.
///
/// Its absence is the on-device voice. Nothing picks a cloud voice except a
/// profile's read-aloud slot.
@immutable
class TtsCloudRoute {
  const TtsCloudRoute({
    required this.provider,
    required this.model,
    required this.languageCode,
    this.voiceId,
  });

  /// The route [profile]'s read-aloud slot names, or `null` — the on-device
  /// voice — when it names none, names one that did not resolve, or names a
  /// provider without a speech client here ([cloudSpeechProviderTypes]).
  ///
  /// [languageCode] is the text's language (`de`, `en-GB`, …), reduced to
  /// its primary subtag.
  static TtsCloudRoute? fromProfile(
    ResolvedProfile? profile, {
    required String languageCode,
  }) {
    final provider = profile?.speechProvider;
    final model = profile?.speechModel;
    if (provider == null ||
        model == null ||
        !cloudSpeechProviderTypes.contains(provider.inferenceProviderType)) {
      return null;
    }
    return TtsCloudRoute(
      provider: provider,
      model: model,
      languageCode: primaryLanguageSubtag(languageCode),
    );
  }

  /// Whether [profile] speaks with a cloud voice at all, whatever the
  /// language: true exactly when [fromProfile] would return a route.
  static bool namesCloudVoice(ResolvedProfile? profile) =>
      fromProfile(profile, languageCode: '') != null;

  final AiConfigInferenceProvider provider;
  final AiConfigModel model;
  final String languageCode;

  /// One voice to speak with, whatever the user chose for [languageCode]:
  /// the picker's preview of a voice not yet chosen. `null` everywhere else.
  final String? voiceId;

  /// Identity for prepared audio and playback keys; carries no credentials.
  String get cacheKey =>
      '${provider.id}/${model.id}/$languageCode'
      '${voiceId == null ? '' : '/$voiceId'}';

  @override
  bool operator ==(Object other) =>
      other is TtsCloudRoute &&
      other.provider == provider &&
      other.model == model &&
      other.languageCode == languageCode &&
      other.voiceId == voiceId;

  @override
  int get hashCode => Object.hash(provider, model, languageCode, voiceId);
}
