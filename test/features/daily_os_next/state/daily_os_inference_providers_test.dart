import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

class _PreferencesController extends DailyOsPreferencesController {
  @override
  DailyOsPreferences build() => DailyOsPreferences(userName: 'Alex');
}

AiConfigInferenceProvider _provider({
  required String baseUrl,
  InferenceProviderType type = InferenceProviderType.genericOpenAi,
}) {
  return AiConfigInferenceProvider(
    id: 'provider',
    baseUrl: baseUrl,
    apiKey: '',
    name: 'Provider',
    createdAt: DateTime(2024, 3, 15),
    inferenceProviderType: type,
  );
}

void main() {
  group('dailyOsInferenceEndpointKind', () {
    for (final baseUrl in [
      'http://localhost:11434',
      'localhost:11434',
      'http://127.0.0.1:11434',
      '127.0.0.1:11434',
      'http://127.12.4.8:8080',
      'http://[::1]:8080',
    ]) {
      test('classifies $baseUrl as on-device', () {
        expect(
          dailyOsInferenceEndpointKind(_provider(baseUrl: baseUrl)),
          DailyOsInferenceEndpointKind.onDevice,
        );
      });
    }

    test('classifies a remote Ollama endpoint as remote', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(
            baseUrl: 'https://ollama.example.com',
            type: InferenceProviderType.ollama,
          ),
        ),
        DailyOsInferenceEndpointKind.remote,
      );
    });

    test('extracts the host from a scheme-less remote endpoint', () {
      expect(
        dailyOsInferenceEndpointHost(
          _provider(baseUrl: 'inference.example.com:11434/v1'),
        ),
        'inference.example.com',
      );
    });

    test('classifies the embedded MLX Audio provider as on-device', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(baseUrl: '', type: InferenceProviderType.mlxAudio),
        ),
        DailyOsInferenceEndpointKind.onDevice,
      );
    });

    test('does not filter or special-case Google endpoints', () {
      expect(
        dailyOsInferenceEndpointKind(
          _provider(
            baseUrl: 'https://generativelanguage.googleapis.com',
            type: InferenceProviderType.gemini,
          ),
        ),
        DailyOsInferenceEndpointKind.remote,
      );
    });
  });

  test('setup status distinguishes required inference from optional name', () {
    const status = DailyOsSetupStatus(
      hasInferenceRoute: true,
      hasPreferredName: false,
    );

    expect(status.needsAttention, isTrue);
    expect(status.hasInferenceRoute, isTrue);
    expect(status.hasPreferredName, isFalse);
  });

  test(
    'setup provider combines the template route and preferred name',
    () async {
      final template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        profileId: 'profile',
      );
      final container = ProviderContainer(
        overrides: [
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => true,
          ),
          agentTemplateProvider.overrideWith((ref, id) async => template),
          dailyOsPreferencesControllerProvider.overrideWith(
            _PreferencesController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(dailyOsSetupStatusProvider.future);

      expect(status.hasInferenceRoute, isTrue);
      expect(status.hasPreferredName, isTrue);
      expect(status.needsAttention, isFalse);
    },
  );

  test(
    'a resolvable legacy route without an explicit profile still needs setup',
    () async {
      // The seeded Shepherd template resolves through its legacy Gemini
      // modelId (routeReady true) but has no explicit profileId. Daily OS
      // deliberately treats this as unconfigured and blocks check-in until the
      // user makes an explicit provider choice, rather than silently routing
      // their planning context to the default provider.
      final legacyTemplate = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
      );
      final container = ProviderContainer(
        overrides: [
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => true,
          ),
          agentTemplateProvider.overrideWith((ref, id) async => legacyTemplate),
          dailyOsPreferencesControllerProvider.overrideWith(
            _PreferencesController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(dailyOsSetupStatusProvider.future);

      expect(status.hasInferenceRoute, isFalse);
      expect(status.needsAttention, isTrue);
    },
  );

  group('dailyOsTranscriptionTargetProvider', () {
    AiConfigInferenceProvider profileProvider() =>
        AiConfig.inferenceProvider(
              id: 'p-profile',
              baseUrl: 'http://localhost',
              apiKey: 'k',
              name: 'Profile Provider',
              createdAt: DateTime(2026, 7, 21),
              inferenceProviderType: InferenceProviderType.genericOpenAi,
            )
            as AiConfigInferenceProvider;

    AiConfigModel profileModel() =>
        AiConfig.model(
              id: 'm-profile',
              name: 'Profile Model',
              providerModelId: 'profile-model',
              inferenceProviderId: 'p-profile',
              createdAt: DateTime(2026, 7, 21),
              inputModalities: const [Modality.audio],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel;

    test('resolves the planner profile transcription slot', () async {
      final resolver = MockProfileResolver();
      when(() => resolver.resolveByProfileId('profile-1')).thenAnswer(
        (_) async => ResolvedProfile(
          thinkingModelId: 'thinking-model',
          thinkingProvider: profileProvider(),
          transcriptionModelId: 'profile-model',
          transcriptionProvider: profileProvider(),
          transcriptionModel: profileModel(),
        ),
      );
      final template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        profileId: 'profile-1',
      );
      final container = ProviderContainer(
        overrides: [
          agentTemplateProvider.overrideWith((ref, id) async => template),
          profileResolverProvider.overrideWithValue(resolver),
        ],
      );
      addTearDown(container.dispose);

      final target = await container.read(
        dailyOsTranscriptionTargetProvider.future,
      );

      expect(target?.model.providerModelId, 'profile-model');
      expect(target?.provider.id, 'p-profile');
    });

    test('is null without a profile or without a transcription slot', () async {
      final resolver = MockProfileResolver();
      when(() => resolver.resolveByProfileId('profile-1')).thenAnswer(
        (_) async => ResolvedProfile(
          thinkingModelId: 'thinking-model',
          thinkingProvider: profileProvider(),
        ),
      );
      for (final profileId in [null, 'profile-1']) {
        final template = makeTestTemplate(
          id: dayAgentTemplateId,
          agentId: dayAgentTemplateId,
          kind: AgentTemplateKind.dayAgent,
          profileId: profileId,
        );
        final container = ProviderContainer(
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => template),
            profileResolverProvider.overrideWithValue(resolver),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(dailyOsTranscriptionTargetProvider.future),
          isNull,
          reason: 'profileId=$profileId',
        );
      }
    });
  });
}
