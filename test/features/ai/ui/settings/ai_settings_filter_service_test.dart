import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_service.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

enum _GeneratedAiProviderSlot { anthropic, openAi, local }

enum _GeneratedAiTextSlot { claude, gpt, vision, audio, blank, unmatched }

enum _GeneratedAiModalitiesSlot {
  text,
  image,
  audio,
  textImage,
  textAudio,
  all,
}

enum _GeneratedAiProviderFilterSlot {
  none,
  anthropic,
  openAi,
  local,
  anthropicOpenAi,
  missing,
}

enum _GeneratedAiCapabilityFilterSlot {
  none,
  text,
  image,
  audio,
  textImage,
  imageAudio,
}

enum _GeneratedAiSearchSlot {
  empty,
  whitespace,
  claude,
  gpt,
  vision,
  missing,
}

String _generatedProviderId(_GeneratedAiProviderSlot slot) {
  return switch (slot) {
    _GeneratedAiProviderSlot.anthropic => 'anthropic-provider',
    _GeneratedAiProviderSlot.openAi => 'openai-provider',
    _GeneratedAiProviderSlot.local => 'local-provider',
  };
}

String? _generatedText(_GeneratedAiTextSlot slot, int seed) {
  return switch (slot) {
    _GeneratedAiTextSlot.claude => 'Claude model $seed',
    _GeneratedAiTextSlot.gpt => 'GPT model $seed',
    _GeneratedAiTextSlot.vision => 'Vision capable $seed',
    _GeneratedAiTextSlot.audio => 'Audio capable $seed',
    _GeneratedAiTextSlot.blank => null,
    _GeneratedAiTextSlot.unmatched => 'Unrelated $seed',
  };
}

List<Modality> _generatedModalities(_GeneratedAiModalitiesSlot slot) {
  return switch (slot) {
    _GeneratedAiModalitiesSlot.text => [Modality.text],
    _GeneratedAiModalitiesSlot.image => [Modality.image],
    _GeneratedAiModalitiesSlot.audio => [Modality.audio],
    _GeneratedAiModalitiesSlot.textImage => [Modality.text, Modality.image],
    _GeneratedAiModalitiesSlot.textAudio => [Modality.text, Modality.audio],
    _GeneratedAiModalitiesSlot.all => [
      Modality.text,
      Modality.image,
      Modality.audio,
    ],
  };
}

Set<String> _generatedProviderFilter(_GeneratedAiProviderFilterSlot slot) {
  return switch (slot) {
    _GeneratedAiProviderFilterSlot.none => const <String>{},
    _GeneratedAiProviderFilterSlot.anthropic => {'anthropic-provider'},
    _GeneratedAiProviderFilterSlot.openAi => {'openai-provider'},
    _GeneratedAiProviderFilterSlot.local => {'local-provider'},
    _GeneratedAiProviderFilterSlot.anthropicOpenAi => {
      'anthropic-provider',
      'openai-provider',
    },
    _GeneratedAiProviderFilterSlot.missing => {'missing-provider'},
  };
}

Set<Modality> _generatedCapabilityFilter(
  _GeneratedAiCapabilityFilterSlot slot,
) {
  return switch (slot) {
    _GeneratedAiCapabilityFilterSlot.none => const <Modality>{},
    _GeneratedAiCapabilityFilterSlot.text => {Modality.text},
    _GeneratedAiCapabilityFilterSlot.image => {Modality.image},
    _GeneratedAiCapabilityFilterSlot.audio => {Modality.audio},
    _GeneratedAiCapabilityFilterSlot.textImage => {
      Modality.text,
      Modality.image,
    },
    _GeneratedAiCapabilityFilterSlot.imageAudio => {
      Modality.image,
      Modality.audio,
    },
  };
}

String _generatedSearch(_GeneratedAiSearchSlot slot) {
  return switch (slot) {
    _GeneratedAiSearchSlot.empty => '',
    _GeneratedAiSearchSlot.whitespace => '   ',
    _GeneratedAiSearchSlot.claude => 'CLAUDE',
    _GeneratedAiSearchSlot.gpt => 'gpt',
    _GeneratedAiSearchSlot.vision => 'vision',
    _GeneratedAiSearchSlot.missing => 'not-present',
  };
}

class _GeneratedAiModelSpec {
  const _GeneratedAiModelSpec({
    required this.providerSlot,
    required this.nameSlot,
    required this.descriptionSlot,
    required this.modalitiesSlot,
    required this.reasoning,
    required this.seed,
  });

  final _GeneratedAiProviderSlot providerSlot;
  final _GeneratedAiTextSlot nameSlot;
  final _GeneratedAiTextSlot descriptionSlot;
  final _GeneratedAiModalitiesSlot modalitiesSlot;
  final bool reasoning;
  final int seed;

  AiConfigModel modelAt(int index) {
    return AiConfig.model(
          id: 'generated-model-$index-$seed',
          name: _generatedText(nameSlot, seed) ?? 'Generated model $seed',
          description: _generatedText(descriptionSlot, seed),
          providerModelId: 'provider-model-$index-$seed',
          inferenceProviderId: _generatedProviderId(providerSlot),
          createdAt: DateTime(2024, 3, 15),
          inputModalities: _generatedModalities(modalitiesSlot),
          outputModalities: const [Modality.text],
          isReasoningModel: reasoning,
        )
        as AiConfigModel;
  }

  @override
  String toString() {
    return '_GeneratedAiModelSpec('
        'providerSlot: $providerSlot, nameSlot: $nameSlot, '
        'descriptionSlot: $descriptionSlot, modalitiesSlot: $modalitiesSlot, '
        'reasoning: $reasoning, seed: $seed)';
  }
}

class _GeneratedAiFilterScenario {
  const _GeneratedAiFilterScenario({
    required this.modelSpecs,
    required this.providerFilter,
    required this.capabilityFilter,
    required this.search,
    required this.reasoning,
  });

  final List<_GeneratedAiModelSpec> modelSpecs;
  final _GeneratedAiProviderFilterSlot providerFilter;
  final _GeneratedAiCapabilityFilterSlot capabilityFilter;
  final _GeneratedAiSearchSlot search;
  final bool reasoning;

  List<AiConfigModel> get models {
    final out = <AiConfigModel>[];
    for (var i = 0; i < modelSpecs.length; i++) {
      out.add(modelSpecs[i].modelAt(i));
    }
    return out;
  }

  AiSettingsFilterState get filterState => AiSettingsFilterState(
    searchQuery: _generatedSearch(search),
    selectedProviders: _generatedProviderFilter(providerFilter),
    selectedCapabilities: _generatedCapabilityFilter(capabilityFilter),
    reasoningFilter: reasoning,
  );

  @override
  String toString() {
    return '_GeneratedAiFilterScenario('
        'modelSpecs: $modelSpecs, providerFilter: $providerFilter, '
        'capabilityFilter: $capabilityFilter, search: $search, '
        'reasoning: $reasoning)';
  }
}

extension _AnyGeneratedAiFilter on glados.Any {
  glados.Generator<_GeneratedAiProviderSlot> get aiProviderSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiProviderSlot.values);

  glados.Generator<_GeneratedAiTextSlot> get aiTextSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiTextSlot.values);

  glados.Generator<_GeneratedAiModalitiesSlot> get aiModalitiesSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiModalitiesSlot.values);

  glados.Generator<_GeneratedAiProviderFilterSlot> get aiProviderFilterSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiProviderFilterSlot.values);

  glados.Generator<_GeneratedAiCapabilityFilterSlot>
  get aiCapabilityFilterSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiCapabilityFilterSlot.values);

  glados.Generator<_GeneratedAiSearchSlot> get aiSearchSlot =>
      glados.AnyUtils(this).choose(_GeneratedAiSearchSlot.values);

  glados.Generator<_GeneratedAiModelSpec> get aiModelSpec =>
      glados.CombinableAny(this).combine6(
        aiProviderSlot,
        aiTextSlot,
        aiTextSlot,
        aiModalitiesSlot,
        glados.any.bool,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedAiProviderSlot providerSlot,
          _GeneratedAiTextSlot nameSlot,
          _GeneratedAiTextSlot descriptionSlot,
          _GeneratedAiModalitiesSlot modalitiesSlot,
          bool reasoning,
          int seed,
        ) => _GeneratedAiModelSpec(
          providerSlot: providerSlot,
          nameSlot: nameSlot,
          descriptionSlot: descriptionSlot,
          modalitiesSlot: modalitiesSlot,
          reasoning: reasoning,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedAiFilterScenario> get aiFilterScenario =>
      glados.CombinableAny(this).combine5(
        glados.ListAnys(this).listWithLengthInRange(0, 14, aiModelSpec),
        aiProviderFilterSlot,
        aiCapabilityFilterSlot,
        aiSearchSlot,
        glados.any.bool,
        (
          List<_GeneratedAiModelSpec> modelSpecs,
          _GeneratedAiProviderFilterSlot providerFilter,
          _GeneratedAiCapabilityFilterSlot capabilityFilter,
          _GeneratedAiSearchSlot search,
          bool reasoning,
        ) => _GeneratedAiFilterScenario(
          modelSpecs: modelSpecs,
          providerFilter: providerFilter,
          capabilityFilter: capabilityFilter,
          search: search,
          reasoning: reasoning,
        ),
      );
}

void main() {
  group('AiSettingsFilterService', () {
    late AiSettingsFilterService service;
    late List<AiConfigInferenceProvider> testProviders;
    late List<AiConfigModel> testModels;
    setUp(() {
      service = const AiSettingsFilterService();

      testProviders = [
        AiConfig.inferenceProvider(
              id: 'anthropic-provider',
              name: 'Anthropic Provider',
              description: 'Claude models provider',
              inferenceProviderType: InferenceProviderType.anthropic,
              apiKey: 'test-key',
              baseUrl: 'https://api.anthropic.com',
              createdAt: DateTime(2024, 3, 15),
            )
            as AiConfigInferenceProvider,
        AiConfig.inferenceProvider(
              id: 'openai-provider',
              name: 'OpenAI Provider',
              description: 'GPT models provider',
              inferenceProviderType: InferenceProviderType.openAi,
              apiKey: 'test-key',
              baseUrl: 'https://api.openai.com',
              createdAt: DateTime(2024, 3, 15),
            )
            as AiConfigInferenceProvider,
      ];

      testModels = [
        AiConfig.model(
              id: 'claude-model',
              name: 'Claude Sonnet 3.5',
              description: 'Fast and capable model',
              providerModelId: 'claude-3-5-sonnet-20241022',
              inferenceProviderId: 'anthropic-provider',
              createdAt: DateTime(2024, 3, 15),
              inputModalities: [Modality.text, Modality.image],
              outputModalities: [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel,
        AiConfig.model(
              id: 'gpt-model',
              name: 'GPT-4',
              description: 'Powerful reasoning model',
              providerModelId: 'gpt-4',
              inferenceProviderId: 'openai-provider',
              createdAt: DateTime(2024, 3, 15),
              inputModalities: [Modality.text],
              outputModalities: [Modality.text],
              isReasoningModel: true,
            )
            as AiConfigModel,
        AiConfig.model(
              id: 'multimodal-model',
              name: 'Multimodal Model',
              description: 'Vision and audio capable',
              providerModelId: 'multimodal-1',
              inferenceProviderId: 'anthropic-provider',
              createdAt: DateTime(2024, 3, 15),
              inputModalities: [Modality.text, Modality.image, Modality.audio],
              outputModalities: [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel,
      ];
    });

    group('filterProviders', () {
      test('returns all providers when no search query', () {
        final filterState = AiSettingsFilterState.initial();
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(2));
        expect(result, containsAll(testProviders));
      });

      test('filters providers by name (case insensitive)', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'anthropic',
        );
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Anthropic Provider');
      });

      test('filters providers by description', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'claude',
        );
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.description, contains('Claude'));
      });

      test('returns empty list when no matches', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'nonexistent',
        );
        final result = service.filterProviders(testProviders, filterState);

        expect(result, isEmpty);
      });

      test('handles providers without description', () {
        final providerWithoutDescription =
            AiConfig.inferenceProvider(
                  id: 'test-provider',
                  name: 'Test Provider',
                  inferenceProviderType: InferenceProviderType.genericOpenAi,
                  apiKey: 'test-key',
                  baseUrl: 'https://api.test.com',
                  createdAt: DateTime(2024, 3, 15),
                )
                as AiConfigInferenceProvider;

        final providers = [...testProviders, providerWithoutDescription];
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'test',
        );
        final result = service.filterProviders(providers, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Test Provider');
      });
    });

    group('filterModels', () {
      test('returns all models when no filters', () {
        final filterState = AiSettingsFilterState.initial();
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(3));
        expect(result, containsAll(testModels));
      });

      test('filters models by search query', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'claude',
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Claude Sonnet 3.5');
      });

      test('filters models by provider', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedProviders: {'anthropic-provider'},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(2));
        expect(
          result.every((m) => m.inferenceProviderId == 'anthropic-provider'),
          isTrue,
        );
      });

      test('filters models by single capability', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedCapabilities: {Modality.image},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(2));
        expect(
          result.every((m) => m.inputModalities.contains(Modality.image)),
          isTrue,
        );
      });

      test('filters models by multiple capabilities (AND logic)', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedCapabilities: {Modality.image, Modality.audio},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Multimodal Model');
      });

      test('filters models by reasoning capability', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          reasoningFilter: true,
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.isReasoningModel, isTrue);
      });

      test('combines multiple filters (AND logic)', () {
        const filterState = AiSettingsFilterState(
          searchQuery: 'claude',
          selectedProviders: {'anthropic-provider'},
          selectedCapabilities: {Modality.image},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(1));
        expect(result.first.name, 'Claude Sonnet 3.5');
      });

      test('returns empty list when filters exclude all models', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedProviders: {'nonexistent-provider'},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, isEmpty);
      });

      test('ignores empty provider filter', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          selectedProviders: <String>{},
        );
        final result = service.filterModels(testModels, filterState);

        expect(result, hasLength(3));
      });

      glados.Glados(
        glados.any.aiFilterScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test('matches generated model filter invariants', (scenario) {
        final models = scenario.models;
        final result = service.filterModels(models, scenario.filterState);
        final expected = models
            .where(
              (model) => _expectedModelMatches(model, scenario.filterState),
            )
            .toList();

        expect(result.map((model) => model.id), [
          for (final model in expected) model.id,
        ], reason: '$scenario');
        expect(
          result.every(
            (model) => _expectedModelMatches(model, scenario.filterState),
          ),
          isTrue,
          reason: '$scenario',
        );
      }, tags: 'glados');
    });

    group('edge cases', () {
      test('handles empty lists gracefully', () {
        final filterState = AiSettingsFilterState.initial();

        expect(service.filterProviders([], filterState), isEmpty);
        expect(service.filterModels([], filterState), isEmpty);
      });

      test('handles case sensitivity correctly', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: 'CLAUDE',
        );
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
        expect(result.first.description, contains('Claude'));
      });

      test('trims whitespace in search query', () {
        final filterState = AiSettingsFilterState.initial().copyWith(
          searchQuery: '  anthropic  ',
        );
        final result = service.filterProviders(testProviders, filterState);

        expect(result, hasLength(1));
      });
    });
  });
}

bool _expectedModelMatches(
  AiConfigModel model,
  AiSettingsFilterState filterState,
) {
  if (!_expectedTextMatches(filterState.searchQuery, [
    model.name,
    model.description ?? '',
  ])) {
    return false;
  }
  if (filterState.selectedProviders.isNotEmpty &&
      !filterState.selectedProviders.contains(model.inferenceProviderId)) {
    return false;
  }
  if (filterState.selectedCapabilities.isNotEmpty &&
      !filterState.selectedCapabilities.every(model.inputModalities.contains)) {
    return false;
  }
  if (filterState.reasoningFilter && !model.isReasoningModel) {
    return false;
  }
  return true;
}

bool _expectedTextMatches(String query, List<String> fields) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return true;
  final lower = trimmed.toLowerCase();
  return fields.any((field) => field.toLowerCase().contains(lower));
}
