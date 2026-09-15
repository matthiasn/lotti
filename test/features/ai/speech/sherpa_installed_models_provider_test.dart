import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test('saved rows become available only with verified device files', () {
    final date = DateTime(2026, 3, 15);
    final providers = [
      AiConfigInferenceProvider(
        id: 'embedded',
        name: 'On device',
        baseUrl: '',
        apiKey: '',
        createdAt: date,
        inferenceProviderType: InferenceProviderType.sherpa,
      ),
      AiConfigInferenceProvider(
        id: 'http',
        name: 'Cloud',
        baseUrl: 'https://example.com',
        apiKey: '',
        createdAt: date,
        inferenceProviderType: InferenceProviderType.openAi,
      ),
    ];
    final models = [
      for (final (id, providerId, nativeId) in [
        ('local-tiny', 'embedded', 'tiny'),
        ('local-medium', 'embedded', 'medium'),
        ('cloud', 'http', 'tiny'),
        ('orphan', 'missing', 'tiny'),
      ])
        AiConfigModel(
          id: id,
          name: id,
          providerModelId: nativeId,
          inferenceProviderId: providerId,
          createdAt: date,
          inputModalities: [Modality.audio],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
    ];
    List<String> available(Set<String> installed) => modelsAvailableOnDevice(
      models: models,
      providers: providers,
      installedSherpaModelIds: installed,
    ).map((model) => model.id).toList();
    expect(available({}), ['cloud']);
    expect(available({'tiny'}), ['local-tiny', 'cloud']);
    expect(available({'medium'}), ['local-medium', 'cloud']);
    expect(available({}), ['cloud']);
    expect(
      models.map((model) => model.id),
      containsAll(['local-tiny', 'local-medium']),
    );
  });

  group('needsSherpaAvailability', () {
    final date = DateTime(2026, 3, 15);
    AiConfigInferenceProvider provider(String id, InferenceProviderType type) =>
        AiConfigInferenceProvider(
          id: id,
          name: id,
          baseUrl: '',
          apiKey: '',
          createdAt: date,
          inferenceProviderType: type,
        );
    AiConfigModel model(String id, String providerId) => AiConfigModel(
      id: id,
      name: id,
      providerModelId: id,
      inferenceProviderId: providerId,
      createdAt: date,
      inputModalities: const [Modality.audio],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
    );
    final embedded = provider('embedded', InferenceProviderType.sherpa);
    final cloud = provider('cloud', InferenceProviderType.openAi);

    final cases =
        <
          ({
            String label,
            List<AiConfigInferenceProvider> providers,
            List<AiConfigModel> models,
            bool expected,
          })
        >[
          (
            label: 'no sherpa provider configured',
            providers: [cloud],
            models: [model('a', 'cloud')],
            expected: false,
          ),
          (
            label:
                'a sherpa provider exists but no candidate routes through it',
            providers: [embedded, cloud],
            models: [model('a', 'cloud'), model('b', 'cloud')],
            expected: false,
          ),
          (
            label: 'a candidate routes through a sherpa provider',
            providers: [embedded, cloud],
            models: [model('a', 'cloud'), model('local', 'embedded')],
            expected: true,
          ),
          (
            label: 'a candidate references a provider that no longer exists',
            providers: [embedded],
            models: [model('orphan', 'missing')],
            expected: false,
          ),
          (
            label: 'no candidates at all',
            providers: [embedded],
            models: const [],
            expected: false,
          ),
        ];

    for (final c in cases) {
      test(c.label, () {
        expect(
          needsSherpaAvailability(models: c.models, providers: c.providers),
          c.expected,
        );
      });
    }
  });

  test(
    'readiness follows verified device files and refreshes after removal',
    () async {
      final models = MockSherpaModelRepository();
      when(() => models.models).thenReturn(sherpaModels);
      var installed = {'tiny'};
      when(() => models.isAvailable(any())).thenAnswer(
        (call) async => installed.contains(call.positionalArguments.single),
      );
      final container = ProviderContainer(
        overrides: [
          sherpaModelRepositoryProvider.overrideWithValue(models),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(sherpaInstalledModelIdsProvider.future), {
        'tiny',
      });
      installed = {};
      container.invalidate(sherpaInstalledModelIdsProvider);
      expect(
        await container.read(sherpaInstalledModelIdsProvider.future),
        isEmpty,
      );
      verify(() => models.isAvailable('tiny')).called(2);
      verify(() => models.isAvailable('base')).called(2);
    },
  );
}
