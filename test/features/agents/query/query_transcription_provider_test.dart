import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/agents/query/query_transcription_provider.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_data/ai_config_factories.dart';
import 'query_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late QueryTestBench bench;
  late MockAiConfigRepository configs;
  late MockSherpaModelRepository embeddedModels;
  late ProviderContainer container;
  late AiConfigInferenceProvider provider;
  late AiConfigModel model;
  late AiConfigInferenceProfile profile;

  setUp(() {
    bench = QueryTestBench()..add('home', category: categoryMindfulness.id);
    bench.categories[0] = bench.categories[0].copyWith(
      defaultProfileId: 'category-profile',
    );
    configs = MockAiConfigRepository();
    embeddedModels = MockSherpaModelRepository();
    when(() => embeddedModels.isAvailable(any())).thenAnswer((_) async => true);
    provider = testInferenceProvider(
      inferenceProviderType: InferenceProviderType.melious,
    );
    model = testAiModel(providerModelId: 'whisper-large-v3').copyWith(
      inputModalities: [Modality.audio],
    );
    profile = testInferenceProfile(
      id: 'category-profile',
      transcriptionModelId: model.id,
      thinkingModelId: 'unconfigured-thinking-model',
    );
    when(() => configs.getConfigById('category-profile')).thenAnswer(
      (_) async => profile,
    );
    when(() => configs.getConfigById(provider.id)).thenAnswer(
      (_) async => provider,
    );
    when(() => configs.getConfigsByType(AiConfigType.model)).thenAnswer(
      (_) async => [
        testAiModel(
          id: 'first-unrelated-model',
          providerModelId: 'base',
          inferenceProviderId: 'local-provider',
        ).copyWith(inputModalities: [Modality.audio]),
        model,
      ],
    );
    container = ProviderContainer(
      overrides: [
        querySourceAccessProvider.overrideWithValue(bench.crawler.access),
        aiConfigRepositoryProvider.overrideWithValue(configs),
        sherpaModelRepositoryProvider.overrideWithValue(embeddedModels),
      ],
    );
    addTearDown(container.dispose);
  });

  for (final kind in QueryScopeKind.values) {
    test(
      '$kind dictation resolves the category transcription slot only',
      () async {
        final scope = QueryScope(
          kind: kind,
          id: kind == QueryScopeKind.category ? categoryMindfulness.id : 'home',
        );
        final resolver = container.read(
          queryTranscriptionTargetResolverProvider(scope),
        );
        final result = await resolver();
        expect(result.model, same(model));
        expect(result.provider, same(provider));
        verifyNever(() => configs.getConfigById('unconfigured-thinking-model'));
      },
    );
  }

  test('a later recording resolves an edited category default', () async {
    const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
    final resolver = container.read(
      queryTranscriptionTargetResolverProvider(scope),
    );
    expect((await resolver()).model, same(model));
    bench.categories[0] = bench.categories[0].copyWith(
      defaultProfileId: 'next-profile',
    );
    final next = model.copyWith(id: 'next-model', providerModelId: 'next-asr');
    when(() => configs.getConfigById('next-profile')).thenAnswer(
      (_) async => profile.copyWith(transcriptionModelId: next.id),
    );
    when(() => configs.getConfigsByType(AiConfigType.model)).thenAnswer(
      (_) async => [model, next],
    );
    expect((await resolver()).model, same(next));
  });

  test(
    'legacy provider-native slot IDs still select the named model',
    () async {
      profile = profile.copyWith(transcriptionModelId: model.providerModelId);
      final result = await container.read(
        queryTranscriptionTargetResolverProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        ),
      )();
      expect(result.model, same(model));
    },
  );

  for (final missing in [
    'category',
    'profile',
    'slot',
    'model',
    'provider',
    'audio',
    'text',
    'realtime',
  ]) {
    test(
      'unavailable $missing fails without selecting an unrelated model',
      () async {
        switch (missing) {
          case 'category':
            bench.entries['home'] = bench.entries['home']!.copyWith(
              meta: bench.entries['home']!.meta.copyWith(categoryId: null),
            );
          case 'profile':
            bench.categories[0] = bench.categories[0].copyWith(
              defaultProfileId: null,
            );
          case 'slot':
            profile = profile.copyWith(transcriptionModelId: null);
          case 'model':
            profile = profile.copyWith(transcriptionModelId: 'missing');
          case 'provider':
            when(
              () => configs.getConfigById(provider.id),
            ).thenAnswer((_) async => null);
          case 'audio':
            model = model.copyWith(inputModalities: [Modality.text]);
          case 'text':
            model = model.copyWith(outputModalities: [Modality.audio]);
          case 'realtime':
            provider = provider.copyWith(
              inferenceProviderType: InferenceProviderType.mistral,
            );
            model = model.copyWith(
              providerModelId: 'voxtral-mini-transcribe-realtime-2602',
            );
        }
        await expectLater(
          container.read(
            queryTranscriptionTargetResolverProvider(
              const QueryScope(kind: QueryScopeKind.task, id: 'home'),
            ),
          )(),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'configuration error',
              contains('No audio-capable models'),
            ),
          ),
        );
      },
    );
  }

  test(
    'an explicit local category model is selected by ID, not name',
    () async {
      provider = provider.copyWith(
        inferenceProviderType: InferenceProviderType.sherpa,
      );
      model = model.copyWith(
        providerModelId: 'small',
        name: 'Z selected model',
      );
      final result = await container.read(
        queryTranscriptionTargetResolverProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        ),
      )();
      expect(result.model, same(model));
      expect(
        result.provider.inferenceProviderType,
        InferenceProviderType.sherpa,
      );
    },
  );

  test('an undownloaded category Sherpa model reports missing setup', () async {
    provider = provider.copyWith(
      inferenceProviderType: InferenceProviderType.sherpa,
    );
    model = model.copyWith(providerModelId: 'small');
    when(
      () => embeddedModels.isAvailable('small'),
    ).thenAnswer((_) async => false);
    await expectLater(
      container.read(
        queryTranscriptionTargetResolverProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        ),
      )(),
      throwsA(
        isA<TranscriptionException>().having(
          (error) => error.message,
          'missing setup guidance',
          contains('No audio-capable models'),
        ),
      ),
    );
    verify(() => embeddedModels.isAvailable('small')).called(1);
  });

  test('a missing profile config fails closed', () async {
    when(
      () => configs.getConfigById('category-profile'),
    ).thenAnswer((_) async => null);
    await expectLater(
      container.read(
        queryTranscriptionTargetResolverProvider(
          const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        ),
      )(),
      throwsA(isA<TranscriptionException>()),
    );
    verifyNever(() => configs.getConfigsByType(AiConfigType.model));
  });

  for (final hidden in ['home', 'category', 'unknown-category']) {
    test('hidden $hidden is rejected before resolving a model', () async {
      final scope = hidden == 'unknown-category'
          ? const QueryScope(kind: QueryScopeKind.category, id: 'unknown')
          : const QueryScope(kind: QueryScopeKind.task, id: 'home');
      if (hidden == 'home') {
        final entry = bench.entries['home']!;
        bench.entries['home'] = entry.copyWith(
          meta: entry.meta.copyWith(private: true),
        );
      } else if (hidden == 'category') {
        bench.categories[0] = bench.categories[0].copyWith(private: true);
      }
      await expectLater(
        container.read(queryTranscriptionTargetResolverProvider(scope))(),
        throwsA(isA<QueryScopeUnavailable>()),
      );
      verifyNever(() => configs.getConfigById('category-profile'));
    });
  }

  for (final change in [
    'private',
    'deleted',
    'moved',
    'category-private',
    'profile',
    'slot',
    'visibility',
  ]) {
    test('rechecks $change changes before submitting audio', () async {
      if (change == 'visibility') bench.showPrivate = true;
      when(() => configs.getConfigById(provider.id)).thenAnswer((_) async {
        final entry = bench.entries['home']!;
        switch (change) {
          case 'private':
            bench.entries['home'] = entry.copyWith(
              meta: entry.meta.copyWith(private: true),
            );
          case 'deleted':
            bench.entries['home'] = entry.copyWith(
              meta: entry.meta.copyWith(deletedAt: DateTime(2026, 9, 12)),
            );
          case 'moved':
            bench.entries['home'] = entry.copyWith(
              meta: entry.meta.copyWith(categoryId: null),
            );
          case 'category-private':
            bench.categories[0] = bench.categories[0].copyWith(private: true);
          case 'profile':
            bench.categories[0] = bench.categories[0].copyWith(
              defaultProfileId: 'changed',
            );
          case 'slot':
            profile = profile.copyWith(transcriptionModelId: 'changed-model');
          case 'visibility':
            bench.showPrivate = false;
        }
        return provider;
      });
      await expectLater(
        container.read(
          queryTranscriptionTargetResolverProvider(
            const QueryScope(kind: QueryScopeKind.task, id: 'home'),
          ),
        )(),
        throwsA(isA<QueryScopeUnavailable>()),
      );
    });
  }
}
