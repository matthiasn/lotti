import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../test_utils.dart';

/// One generated candidate row for the lookup: which provider owns the
/// model, whether the id matches, and the owner's type/usability/liveness.
class _CandidateSpec {
  _CandidateSpec(int seed)
    : idMatches = seed.isEven,
      sameProvider = seed % 3 == 0,
      sameType = seed % 5 != 0,
      usable = seed % 7 != 0,
      providerExists = seed % 11 != 0;

  final bool idMatches;
  final bool sameProvider;
  final bool sameType;
  final bool usable;
  final bool providerExists;
}

extension _AnyCandidates on glados.Any {
  glados.Generator<List<_CandidateSpec>> get candidateSpecs =>
      list(glados.IntAnys(this).intInRange(0, 1 << 16).map(_CandidateSpec.new));
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('findConfiguredKnownModel', () {
    const knownId = 'gemini-2.5-flash';

    AiConfigModel modelFor(String providerId, {String id = 'model-1'}) =>
        AiTestDataFactory.createTestModel(
          id: id,
          providerModelId: knownId,
          inferenceProviderId: providerId,
        );

    AiConfigInferenceProvider provider(
      String id, {
      InferenceProviderType type = InferenceProviderType.gemini,
      String apiKey = 'key',
    }) => AiTestDataFactory.createTestProvider(
      id: id,
      type: type,
      apiKey: apiKey,
    );

    test('returns the model bound directly to the target provider', () {
      final mine = modelFor('target-provider');
      final result = findConfiguredKnownModel(
        knownId,
        providerId: 'target-provider',
        providerType: InferenceProviderType.gemini,
        existingModels: [mine],
        providersById: const {},
      );

      expect(result, same(mine));
    });

    test(
      'with multiple same-type providers only the usable one verifies',
      () {
        // Two foreign gemini providers own the model id; only the second is
        // usable (non-empty API key), so its model must be the one returned.
        final unusableModel = modelFor('dead-provider', id: 'model-dead');
        final usableModel = modelFor('live-provider', id: 'model-live');

        final result = findConfiguredKnownModel(
          knownId,
          providerId: 'target-provider',
          providerType: InferenceProviderType.gemini,
          existingModels: [unusableModel, usableModel],
          providersById: {
            'dead-provider': provider('dead-provider', apiKey: '   '),
            'live-provider': provider('live-provider'),
          },
        );

        expect(result, same(usableModel));
      },
    );

    test('ignores a matching providerModelId owned by a different type', () {
      // The id exists, but under an OpenAI provider: a Gemini FTUE setup
      // must not treat it as already configured.
      final foreign = modelFor('openai-provider');

      final result = findConfiguredKnownModel(
        knownId,
        providerId: 'target-provider',
        providerType: InferenceProviderType.gemini,
        existingModels: [foreign],
        providersById: {
          'openai-provider': provider(
            'openai-provider',
            type: InferenceProviderType.openAi,
          ),
        },
      );

      expect(result, isNull);
    });

    test('ignores a model whose provider is missing from the map', () {
      final orphan = modelFor('deleted-provider');

      final result = findConfiguredKnownModel(
        knownId,
        providerId: 'target-provider',
        providerType: InferenceProviderType.gemini,
        existingModels: [orphan],
        providersById: const {},
      );

      expect(result, isNull);
    });

    test('returns null when no model has the providerModelId', () {
      final other = AiTestDataFactory.createTestModel(
        id: 'model-other',
        providerModelId: 'some-other-model',
        inferenceProviderId: 'target-provider',
      );

      final result = findConfiguredKnownModel(
        knownId,
        providerId: 'target-provider',
        providerType: InferenceProviderType.gemini,
        existingModels: [other],
        providersById: const {},
      );

      expect(result, isNull);
    });

    // Property: the three-clause predicate, run over arbitrary candidate
    // mixes — direct binding always wins; foreign candidates only verify
    // when their provider exists, has the same type, and is usable.
    glados.Glados(
      glados.any.candidateSpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test('matches the eligibility predicate for any candidate list', (
      specs,
    ) {
      const targetProvider = 'target-provider';
      final models = <AiConfigModel>[];
      final providersById = <String, AiConfigInferenceProvider>{};

      for (final (i, spec) in specs.indexed) {
        final ownerId = spec.sameProvider ? targetProvider : 'foreign-$i';
        models.add(
          AiTestDataFactory.createTestModel(
            id: 'model-$i',
            providerModelId: spec.idMatches ? knownId : 'other-id-$i',
            inferenceProviderId: ownerId,
          ),
        );
        if (!spec.sameProvider && spec.providerExists) {
          providersById[ownerId] = provider(
            ownerId,
            type: spec.sameType
                ? InferenceProviderType.gemini
                : InferenceProviderType.openAi,
            apiKey: spec.usable ? 'key' : '   ',
          );
        }
      }

      final result = findConfiguredKnownModel(
        knownId,
        providerId: targetProvider,
        providerType: InferenceProviderType.gemini,
        existingModels: models,
        providersById: providersById,
      );

      // Oracle: first model that matches the documented predicate.
      AiConfigModel? expected;
      for (final (i, spec) in specs.indexed) {
        if (!spec.idMatches) continue;
        if (spec.sameProvider ||
            (spec.providerExists && spec.sameType && spec.usable)) {
          expected = models[i];
          break;
        }
      }

      expect(
        result,
        expected == null ? isNull : same(expected),
        reason: 'specs: ${specs.length} candidates',
      );
    }, tags: 'glados');
  });
}
