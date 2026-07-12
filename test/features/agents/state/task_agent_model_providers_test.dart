import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/template_query_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
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
    expect(isTaskAgentThinkingModel(model()), isTrue);
    expect(isTaskAgentThinkingModel(model(tools: false)), isFalse);
    expect(
      isTaskAgentThinkingModel(model(input: const [Modality.image])),
      isFalse,
    );
    expect(
      isTaskAgentThinkingModel(model(output: const [Modality.image])),
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
    'setup options filters models to task-agent thinking capabilities',
    () async {
      final repository = MockAiConfigRepository();
      final capable = model();
      final incapable = model(tools: false);
      when(
        () => repository.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer((_) async => const []);
      when(
        () => repository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [capable, incapable]);
      when(
        () => repository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => const []);
      final container = ProviderContainer(
        overrides: [aiConfigRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final options = await container.read(
        taskAgentSetupOptionsProvider.future,
      );
      expect(options.models, [capable]);
      expect(options.profiles, isEmpty);
      expect(options.providers, isEmpty);
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
}
