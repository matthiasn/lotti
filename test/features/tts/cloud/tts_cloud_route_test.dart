import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';

import '../../agents/test_data/ai_config_factories.dart';

void main() {
  final mistral = testInferenceProvider(
    id: 'mistral',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final voice = testAiModel(
    id: 'voice-row',
    providerModelId: 'voxtral-mini-tts-3-0',
    inferenceProviderId: 'mistral',
  );

  ResolvedProfile profile({
    AiConfigInferenceProvider? speechProvider,
    AiConfigModel? speechModel,
  }) => ResolvedProfile(
    thinkingModelId: 'thinking',
    thinkingProvider: mistral,
    speechModelId: speechModel?.providerModelId,
    speechProvider: speechProvider,
    speechModel: speechModel,
  );

  test('a Mistral read-aloud slot routes to the cloud in the primary '
      'language subtag', () {
    final route = TtsCloudRoute.fromProfile(
      profile(speechProvider: mistral, speechModel: voice),
      languageCode: 'de-AT',
    );
    expect(route?.provider, mistral);
    expect(route?.model, voice);
    expect(route?.languageCode, 'de');
    expect(route?.cacheKey, 'mistral/voice-row/de');
  });

  test('no profile, an empty slot, or a provider without a speech client '
      'stays on the on-device voice', () {
    expect(TtsCloudRoute.fromProfile(null, languageCode: 'de'), isNull);
    expect(TtsCloudRoute.fromProfile(profile(), languageCode: 'de'), isNull);
    // Resolved model but no provider — an inconsistent half route.
    expect(
      TtsCloudRoute.fromProfile(
        profile(speechModel: voice),
        languageCode: 'de',
      ),
      isNull,
    );
    expect(
      TtsCloudRoute.fromProfile(
        profile(
          speechProvider: testInferenceProvider(
            inferenceProviderType: InferenceProviderType.openAi,
          ),
          speechModel: voice,
        ),
        languageCode: 'de',
      ),
      isNull,
    );
  });

  test('namesCloudVoice agrees with fromProfile', () {
    expect(
      TtsCloudRoute.namesCloudVoice(
        profile(speechProvider: mistral, speechModel: voice),
      ),
      isTrue,
    );
    expect(TtsCloudRoute.namesCloudVoice(profile()), isFalse);
    expect(TtsCloudRoute.namesCloudVoice(null), isFalse);
  });

  test('routes compare by provider, model and language', () {
    TtsCloudRoute route(String language) => TtsCloudRoute(
      provider: mistral,
      model: voice,
      languageCode: language,
    );
    expect(route('de'), route('de'));
    expect(route('de').hashCode, route('de').hashCode);
    expect(route('de'), isNot(route('en')));
  });

  test("a preview's own voice is part of the route and its cache key", () {
    TtsCloudRoute route({String? voiceId}) => TtsCloudRoute(
      provider: mistral,
      model: voice,
      languageCode: 'de',
      voiceId: voiceId,
    );
    expect(route(voiceId: 'v1'), route(voiceId: 'v1'));
    expect(route(voiceId: 'v1').hashCode, route(voiceId: 'v1').hashCode);
    expect(route(voiceId: 'v1'), isNot(route(voiceId: 'v2')));
    expect(route(voiceId: 'v1'), isNot(route()));
    // Prepared audio of one voice must never be played for another.
    expect(route().cacheKey, '${mistral.id}/${voice.id}/de');
    expect(route(voiceId: 'v1').cacheKey, '${mistral.id}/${voice.id}/de/v1');
  });
}
