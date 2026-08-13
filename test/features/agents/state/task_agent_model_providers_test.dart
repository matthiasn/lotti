import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';
import '../test_data/template_factories.dart';

void main() {
  AiConfigModel model({
    bool tools = true,
    List<Modality> input = const [Modality.text],
    List<Modality> output = const [Modality.text],
  }) {
    return AiConfigModel(
      id: 'model',
      name: 'Model',
      providerModelId: 'wire-model',
      inferenceProviderId: 'provider',
      createdAt: DateTime(2024),
      inputModalities: input,
      outputModalities: output,
      isReasoningModel: true,
      supportsFunctionCalling: tools,
    );
  }

  test('task-agent model capability requires text in/out and tool calling', () {
    expect(isAgenticThinkingModel(model()), isTrue);
    expect(isAgenticThinkingModel(model(tools: false)), isFalse);
    expect(
      isAgenticThinkingModel(model(input: const [Modality.image])),
      isFalse,
    );
    expect(
      isAgenticThinkingModel(model(output: const [Modality.image])),
      isFalse,
    );
  });

  test(
    'resolved setup returns null when identity, template, or version is absent',
    () async {
      final identityMissing = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(identityMissing.dispose);
      expect(
        await identityMissing.read(
          taskAgentResolvedSetupProvider('agent').future,
        ),
        isNull,
      );

      final identity = makeTestIdentity();
      final templateMissing = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith((ref, id) async => identity),
          templateForAgentProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(templateMissing.dispose);
      expect(
        await templateMissing.read(
          taskAgentResolvedSetupProvider('agent').future,
        ),
        isNull,
      );

      final template = makeTestTemplate();
      final versionMissing = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith((ref, id) async => identity),
          templateForAgentProvider.overrideWith((ref, id) async => template),
          activeTemplateVersionProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(versionMissing.dispose);
      expect(
        await versionMissing.read(
          taskAgentResolvedSetupProvider('agent').future,
        ),
        isNull,
      );
    },
  );

  test(
    'setup options filters model capabilities without excluding providers',
    () async {
      final repository = MockAiConfigRepository();
      final capable = model();
      final incapable = model(tools: false);
      final google = AiConfigInferenceProvider(
        id: 'google',
        baseUrl: 'https://generativelanguage.googleapis.com',
        apiKey: 'key',
        name: 'Google Gemini',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      when(
        () => repository.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer((_) async => const []);
      when(
        () => repository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [capable, incapable]);
      when(
        () => repository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [google]);
      final container = ProviderContainer(
        overrides: [aiConfigRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final options = await container.read(
        taskAgentSetupOptionsProvider.future,
      );
      expect(options.models, [capable]);
      expect(options.profiles, isEmpty);
      expect(options.providers, [google]);

      await Future<void>.value();
      final cached = await container.read(taskAgentSetupOptionsProvider.future);
      expect(cached, same(options));
      verify(
        () => repository.getConfigsByType(AiConfigType.inferenceProfile),
      ).called(1);
      verify(
        () => repository.getConfigsByType(AiConfigType.model),
      ).called(1);
      verify(
        () => repository.getConfigsByType(AiConfigType.inferenceProvider),
      ).called(1);
    },
  );

  test('resolved setup delegates complete agent context to resolver', () async {
    final identity = makeTestIdentity();
    final template = makeTestTemplate();
    final version = makeTestTemplateVersion(agentId: template.id);
    final resolver = MockProfileResolver();
    const expected = ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.disabled,
    );
    when(
      () => resolver.resolveDetailed(
        agentConfig: identity.config,
        template: template,
        version: version,
      ),
    ).thenAnswer((_) async => expected);
    final container = ProviderContainer(
      overrides: [
        agentIdentityProvider.overrideWith((ref, id) async => identity),
        templateForAgentProvider.overrideWith((ref, id) async => template),
        activeTemplateVersionProvider.overrideWith((ref, id) async => version),
        profileResolverProvider.overrideWithValue(resolver),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(taskAgentResolvedSetupProvider('agent').future),
      expected,
    );
    verify(
      () => resolver.resolveDetailed(
        agentConfig: identity.config,
        template: template,
        version: version,
      ),
    ).called(1);
  });

  test('goal-agent profile resolves without a template assignment', () async {
    final identity = makeTestIdentity(
      kind: AgentKinds.goalAgent,
      config: const AgentConfig(
        profileId: 'goal-profile',
        inferenceSetup: AgentInferenceSetup(
          mode: AgentInferenceSetupMode.configured,
          origin: AgentInferenceSetupOrigin.user,
          baseProfileId: 'goal-profile',
        ),
      ),
    );
    final resolver = MockProfileResolver();
    final resolved = ResolvedProfile(
      thinkingModelId: 'wire-model',
      thinkingProvider: AiConfigInferenceProvider(
        id: 'provider',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        name: 'Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
      thinkingModel: model(),
    );
    when(
      () => resolver.resolveByProfileId('goal-profile'),
    ).thenAnswer((_) async => resolved);
    final container = ProviderContainer(
      overrides: [
        agentIdentityProvider.overrideWith((ref, id) async => identity),
        templateForAgentProvider.overrideWith((ref, id) async => null),
        profileResolverProvider.overrideWithValue(resolver),
      ],
    );
    addTearDown(container.dispose);

    final setup = await container.read(
      goalAgentResolvedSetupProvider('agent').future,
    );

    expect(setup?.status, AgentSetupResolutionStatus.resolved);
    expect(setup?.profile, resolved);
    expect(setup?.source, AgentSetupResolutionSource.baseProfile);
    expect(setup?.setupOrigin, AgentInferenceSetupOrigin.user);
    verify(() => resolver.resolveByProfileId('goal-profile')).called(1);
  });

  test(
    'goal-agent profile resolver supports legacy profile selection',
    () async {
      final identity = makeTestIdentity(
        kind: AgentKinds.goalAgent,
        config: const AgentConfig(profileId: 'goal-profile'),
      );
      final resolver = MockProfileResolver();
      final resolved = ResolvedProfile(
        thinkingModelId: 'wire-model',
        thinkingProvider: AiConfigInferenceProvider(
          id: 'provider',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Provider',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        ),
        thinkingModel: model(),
      );
      when(
        () => resolver.resolveByProfileId('goal-profile'),
      ).thenAnswer((_) async => resolved);
      final container = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith((ref, id) async => identity),
          profileResolverProvider.overrideWithValue(resolver),
        ],
      );
      addTearDown(container.dispose);

      final setup = await container.read(
        goalAgentResolvedSetupProvider('agent').future,
      );

      expect(setup?.status, AgentSetupResolutionStatus.resolved);
      expect(setup?.profile, resolved);
      expect(setup?.source, AgentSetupResolutionSource.legacyAgentProfile);
      expect(setup?.setupOrigin, isNull);
    },
  );

  test(
    'goal-agent resolver reports its built-in route and broken setups',
    () async {
      final repository = MockAiConfigRepository();
      final provider = AiConfigInferenceProvider(
        id: 'provider',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        name: 'Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.melious,
      );
      final builtInModel = model().copyWith(
        providerModelId: meliousGlm52ModelId,
      );
      when(
        () => repository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [builtInModel]);
      when(
        () => repository.getConfigById('provider'),
      ).thenAnswer((_) async => provider);
      final builtInContainer = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, id) async => makeTestIdentity(kind: AgentKinds.goalAgent),
          ),
          aiConfigRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(builtInContainer.dispose);
      final builtIn = await builtInContainer.read(
        goalAgentResolvedSetupProvider('agent').future,
      );
      expect(builtIn?.status, AgentSetupResolutionStatus.resolved);
      expect(builtIn?.source, AgentSetupResolutionSource.directModel);
      expect(builtIn?.profile?.thinkingModelId, meliousGlm52ModelId);
      expect(builtIn?.profile?.thinkingProvider, provider);
      expect(builtIn?.profile?.thinkingModel, builtInModel);

      final unavailableRepository = MockAiConfigRepository();
      when(
        () => unavailableRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => const []);
      final unavailableContainer = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, id) async => makeTestIdentity(kind: AgentKinds.goalAgent),
          ),
          aiConfigRepositoryProvider.overrideWithValue(unavailableRepository),
        ],
      );
      addTearDown(unavailableContainer.dispose);
      expect(
        (await unavailableContainer.read(
          goalAgentResolvedSetupProvider('agent').future,
        ))?.status,
        AgentSetupResolutionStatus.broken,
      );

      final resolver = MockProfileResolver();
      when(
        () => resolver.resolveByProfileId('missing-profile'),
      ).thenAnswer((_) async => null);
      final brokenContainer = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, id) async => makeTestIdentity(
              kind: AgentKinds.goalAgent,
              config: const AgentConfig(profileId: 'missing-profile'),
            ),
          ),
          profileResolverProvider.overrideWithValue(resolver),
        ],
      );
      addTearDown(brokenContainer.dispose);
      expect(
        (await brokenContainer.read(
          goalAgentResolvedSetupProvider('agent').future,
        ))?.status,
        AgentSetupResolutionStatus.broken,
      );

      final taskContainer = ProviderContainer(
        overrides: [
          agentIdentityProvider.overrideWith(
            (ref, id) async => makeTestIdentity(),
          ),
        ],
      );
      addTearDown(taskContainer.dispose);
      expect(
        await taskContainer.read(
          goalAgentResolvedSetupProvider('agent').future,
        ),
        isNull,
      );
    },
  );
}
