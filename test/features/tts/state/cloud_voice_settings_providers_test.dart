import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/voxtral_voice_catalog.dart';
import 'package:lotti/features/tts/state/cloud_voice_settings_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

import '../../agents/test_data/ai_config_factories.dart';

class _ConfigsByType extends AiConfigByTypeController {
  _ConfigsByType(this.configs);

  final List<AiConfig> configs;

  @override
  Stream<List<AiConfig>> build() => Stream.value(configs);
}

void main() {
  final mistral = testInferenceProvider(
    id: 'mistral',
    inferenceProviderType: InferenceProviderType.mistral,
  );
  final openAi = testInferenceProvider(
    id: 'openai',
    inferenceProviderType: InferenceProviderType.openAi,
  );
  final voice = testAiModel(
    id: 'voice-row',
    providerModelId: 'voxtral-mini-tts-3-0',
    inferenceProviderId: 'mistral',
  );
  final secondVoice = testAiModel(
    id: 'voice-row-2',
    providerModelId: 'voxtral-mini-tts-2603',
    inferenceProviderId: 'mistral',
  );
  final openAiVoice = testAiModel(
    id: 'openai-voice',
    providerModelId: 'gpt-4o-mini-tts',
    inferenceProviderId: 'openai',
  );

  AiConfigInferenceProfile profile(String id, String? speech) =>
      testInferenceProfile(id: id).copyWith(speechModelId: speech);

  Future<List<CloudVoiceService>> services({
    required List<AiConfigInferenceProfile> profiles,
  }) {
    final byType = <AiConfigType, List<AiConfig>>{
      AiConfigType.inferenceProfile: profiles,
      AiConfigType.inferenceProvider: [mistral, openAi],
      AiConfigType.model: [voice, secondVoice, openAiVoice],
    };
    final container = ProviderContainer(
      overrides: [
        for (final MapEntry(key: type, value: configs) in byType.entries)
          aiConfigByTypeControllerProvider(
            type,
          ).overrideWith(() => _ConfigsByType(configs)),
      ],
    );
    addTearDown(container.dispose);
    // Auto-disposed inputs must stay alive while the services resolve.
    container.listen(cloudVoiceServicesProvider, (_, _) {});
    return container.read(cloudVoiceServicesProvider.future);
  }

  test('no read-aloud slot anywhere: no cloud voice service', () async {
    expect(await services(profiles: [profile('a', null)]), isEmpty);
  });

  test('a slot by row id or by legacy provider-native id names its Mistral '
      'provider once', () async {
    final found = await services(
      profiles: [
        profile('a', 'voice-row'),
        profile('b', 'voxtral-mini-tts-2603'),
      ],
    );
    expect(found, hasLength(1));
    expect(found.single.provider, mistral);
    expect(found.single.model, anyOf(voice, secondVoice));
  });

  test('a provider without a speech client is left out', () async {
    expect(await services(profiles: [profile('a', 'openai-voice')]), isEmpty);
  });

  test('the catalog provider reads through the device cache', () async {
    final catalogs = MockVoxtralVoiceCatalogRepository();
    final catalog = VoxtralVoiceCatalog(
      voices: const [],
      fetchedAt: DateTime.utc(2026, 10, 27),
    );
    when(() => catalogs.catalogFor(mistral)).thenAnswer((_) async => catalog);
    final container = ProviderContainer(
      overrides: [
        voxtralVoiceCatalogRepositoryProvider.overrideWithValue(catalogs),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(voxtralVoiceCatalogProvider(mistral).future),
      catalog,
    );
  });
}
