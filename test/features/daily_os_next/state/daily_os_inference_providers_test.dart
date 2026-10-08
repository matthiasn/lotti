import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_inference_providers.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
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
        overrides: withServiceOverrides([
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => true,
          ),
          agentTemplateProvider.overrideWith((ref, id) async => template),
          dailyOsPreferencesControllerProvider.overrideWith(
            _PreferencesController.new,
          ),
        ]),
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
        overrides: withServiceOverrides([
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => true,
          ),
          agentTemplateProvider.overrideWith((ref, id) async => legacyTemplate),
          dailyOsPreferencesControllerProvider.overrideWith(
            _PreferencesController.new,
          ),
        ]),
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
        overrides: withServiceOverrides([
          agentTemplateProvider.overrideWith((ref, id) async => template),
          profileResolverProvider.overrideWithValue(resolver),
        ]),
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
          overrides: withServiceOverrides([
            agentTemplateProvider.overrideWith((ref, id) async => template),
            profileResolverProvider.overrideWithValue(resolver),
          ]),
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

  group('dailyOsTranscriptCorrectionTargetProvider', () {
    AiConfigInferenceProvider provider(String id) =>
        AiConfig.inferenceProvider(
              id: id,
              baseUrl: 'http://localhost',
              apiKey: 'k',
              name: 'Provider $id',
              createdAt: DateTime(2026, 7, 21),
              inferenceProviderType: InferenceProviderType.genericOpenAi,
            )
            as AiConfigInferenceProvider;

    AiConfigModel model(String id, {required bool tools}) =>
        AiConfig.model(
              id: id,
              name: 'Model $id',
              providerModelId: id,
              inferenceProviderId: 'p-$id',
              createdAt: DateTime(2026, 7, 21),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
              supportsFunctionCalling: tools,
            )
            as AiConfigModel;

    Future<DailyOsTranscriptionTarget?> targetFor(
      ResolvedProfile? profile,
    ) async {
      final resolver = MockProfileResolver();
      when(
        () => resolver.resolveByProfileId('profile-1'),
      ).thenAnswer((_) async => profile);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          agentTemplateProvider.overrideWith(
            (ref, id) async => makeTestTemplate(
              id: dayAgentTemplateId,
              agentId: dayAgentTemplateId,
              kind: AgentTemplateKind.dayAgent,
              profileId: 'profile-1',
            ),
          ),
          profileResolverProvider.overrideWithValue(resolver),
        ]),
      );
      addTearDown(container.dispose);
      return container.read(dailyOsTranscriptCorrectionTargetProvider.future);
    }

    test(
      "is the planner profile's post-processing model, else its thinking "
      'model, when it can call the correction tool',
      () async {
        final editor = model('editor', tools: true);
        final viaSlot = await targetFor(
          ResolvedProfile(
            thinkingModelId: 'thinking',
            thinkingProvider: provider('p-thinking'),
            thinkingModel: model('thinking', tools: true),
            audioPostProcessingModelId: 'editor',
            audioPostProcessingProvider: provider('p-editor'),
            audioPostProcessingModel: editor,
          ),
        );
        expect(viaSlot?.model, editor);
        expect(viaSlot?.provider.id, 'p-editor');

        final viaThinking = await targetFor(
          ResolvedProfile(
            thinkingModelId: 'thinking',
            thinkingProvider: provider('p-thinking'),
            thinkingModel: model('thinking', tools: true),
          ),
        );
        expect(viaThinking?.model.id, 'thinking');
      },
    );

    test(
      'is null without a profile, with a model that cannot call tools, or '
      'with a post-processing model this device cannot resolve',
      () async {
        expect(await targetFor(null), isNull);
        expect(
          await targetFor(
            ResolvedProfile(
              thinkingModelId: 'thinking',
              thinkingProvider: provider('p-thinking'),
              thinkingModel: model('thinking', tools: false),
            ),
          ),
          isNull,
        );
        expect(
          await targetFor(
            ResolvedProfile(
              thinkingModelId: 'thinking',
              thinkingProvider: provider('p-thinking'),
              thinkingModel: model('thinking', tools: true),
              audioPostProcessingModelUnavailable: true,
            ),
          ),
          isNull,
        );
      },
    );
  });

  group('correctHeardTranscript', () {
    AiConfigInferenceProvider provider(InferenceProviderType type) =>
        AiConfig.inferenceProvider(
              id: 'p-${type.name}',
              baseUrl: 'http://localhost',
              apiKey: 'k',
              name: type.name,
              createdAt: DateTime(2026, 7, 21),
              inferenceProviderType: type,
            )
            as AiConfigInferenceProvider;

    AiConfigModel model(String providerModelId) =>
        AiConfig.model(
              id: 'm-$providerModelId',
              name: providerModelId,
              providerModelId: providerModelId,
              inferenceProviderId: 'p',
              createdAt: DateTime(2026, 7, 21),
              inputModalities: const [Modality.audio],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            )
            as AiConfigModel;

    final whisper = (
      provider: provider(InferenceProviderType.whisper),
      model: model('whisper-large-v3'),
    );
    final gemini = (
      provider: provider(InferenceProviderType.gemini),
      model: model('gemini-2.5-flash'),
    );
    final editor = (
      provider: provider(InferenceProviderType.genericOpenAi),
      model: model('editor'),
    );

    test(
      "corrects a speech-to-text engine's words on the correction model",
      () async {
        final transcriber = MockAudioTranscriptionService();
        when(
          () => transcriber.correctTranscript('heard', target: editor),
        ).thenAnswer((_) async => 'corrected');

        expect(
          await correctHeardTranscript(
            transcriber: transcriber,
            transcript: 'heard',
            heardBy: whisper,
            correctionTarget: () async => editor,
          ),
          'corrected',
        );
      },
    );

    test(
      'reads the route discovery chose when the capture ran without a '
      'target, and corrects only a speech-to-text one',
      () async {
        final transcriber = MockAudioTranscriptionService();
        when(
          () => transcriber.correctTranscript('heard', target: editor),
        ).thenAnswer((_) async => 'corrected');
        when(transcriber.discoverTarget).thenAnswer((_) async => whisper);
        expect(
          await correctHeardTranscript(
            transcriber: transcriber,
            transcript: 'heard',
            heardBy: null,
            correctionTarget: () async => editor,
          ),
          'corrected',
        );

        when(transcriber.discoverTarget).thenAnswer((_) async => gemini);
        expect(
          await correctHeardTranscript(
            transcriber: transcriber,
            transcript: 'heard',
            heardBy: null,
            correctionTarget: () async => editor,
          ),
          'heard',
        );

        when(transcriber.discoverTarget).thenThrow(Exception('no models'));
        expect(
          await correctHeardTranscript(
            transcriber: transcriber,
            transcript: 'heard',
            heardBy: null,
            correctionTarget: () async => editor,
          ),
          'heard',
        );
        verify(
          () => transcriber.correctTranscript('heard', target: editor),
        ).called(1);
      },
    );

    test(
      'keeps the words when a multimodal model heard them, no model can '
      'correct them, or finding one fails — and never asks discovery then',
      () async {
        final transcriber = MockAudioTranscriptionService();
        for (final (heardBy, correctionTarget) in [
          (gemini, () async => editor),
          (null, () async => null),
          (whisper, () async => null),
          (whisper, () => Future<DailyOsTranscriptionTarget?>.error('down')),
        ]) {
          expect(
            await correctHeardTranscript(
              transcriber: transcriber,
              transcript: 'heard',
              heardBy: heardBy,
              correctionTarget: correctionTarget,
            ),
            'heard',
          );
        }
        verifyZeroInteractions(transcriber);
      },
    );
  });
}
