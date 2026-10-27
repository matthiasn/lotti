import 'package:flutter/foundation.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';

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
  });

  /// The route [profile]'s read-aloud slot names, or `null` — the on-device
  /// voice — when it names none, names one that did not resolve, or names a
  /// provider without a speech client here. Mistral is the one today;
  /// another provider joins by adding its case.
  ///
  /// [languageCode] is the text's language (`de`, `en-GB`, …), reduced to
  /// its primary subtag.
  static TtsCloudRoute? fromProfile(
    ResolvedProfile? profile, {
    required String languageCode,
  }) {
    final provider = profile?.speechProvider;
    final model = profile?.speechModel;
    if (provider == null || model == null) return null;
    return switch (provider.inferenceProviderType) {
      InferenceProviderType.mistral => TtsCloudRoute(
        provider: provider,
        model: model,
        languageCode: primaryLanguageSubtag(languageCode),
      ),
      _ => null,
    };
  }

  /// Whether [profile] speaks with a cloud voice at all, whatever the
  /// language: true exactly when [fromProfile] would return a route.
  static bool namesCloudVoice(ResolvedProfile? profile) =>
      fromProfile(profile, languageCode: '') != null;

  final AiConfigInferenceProvider provider;
  final AiConfigModel model;
  final String languageCode;

  /// Identity for prepared audio and playback keys; carries no credentials.
  String get cacheKey => '${provider.id}/${model.id}/$languageCode';

  @override
  bool operator ==(Object other) =>
      other is TtsCloudRoute &&
      other.provider == provider &&
      other.model == model &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(provider, model, languageCode);
}
