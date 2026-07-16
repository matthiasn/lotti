import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository;
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/test_data/template_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAiConfigRepository aiConfigRepository;
  late MockAgentRepository agentRepository;
  late MockAgentTemplateService templateService;
  late MockProfileResolver profileResolver;
  late AgentTemplateEntity template;
  late AgentTemplateVersionEntity version;

  /// The pre-first-capture baseline: no planner exists yet, so the seeded
  /// day-agent template and its active version are what the route resolves
  /// through. Tests override only the arm they exercise.
  setUp(() async {
    aiConfigRepository = MockAiConfigRepository();
    agentRepository = MockAgentRepository();
    templateService = MockAgentTemplateService();
    profileResolver = MockProfileResolver();
    template = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      kind: AgentTemplateKind.dayAgent,
    );
    version = makeTestTemplateVersion(agentId: dayAgentTemplateId);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<AiConfigRepository>(aiConfigRepository);
      },
    );

    when(
      () => agentRepository.getEntity(dailyOsPlannerAgentId),
    ).thenAnswer((_) async => null);
    when(
      () => templateService.getTemplate(dayAgentTemplateId),
    ).thenAnswer((_) async => template);
    when(
      () => templateService.getActiveVersion(dayAgentTemplateId),
    ).thenAnswer((_) async => version);
  });

  tearDown(tearDownTestGetIt);

  ResolvedProfile resolvedProfile() => ResolvedProfile(
    thinkingModelId: 'models/gemini-3-flash-preview',
    thinkingProvider: testInferenceProvider(),
  );

  Future<bool> callRoute() => hasResolvableDailyOsPlannerThinkingRoute(
    agentRepository: agentRepository,
    templateService: templateService,
    profileResolver: profileResolver,
  );

  void verifyResolverNeverCalled() => verifyNever(
    () => profileResolver.resolve(
      agentConfig: any(named: 'agentConfig'),
      template: any(named: 'template'),
      version: any(named: 'version'),
    ),
  );

  group('hasResolvableDailyOsPlannerThinkingRoute', () {
    test(
      'true when the seeded template resolves with the config planner '
      'creation would copy',
      () async {
        when(
          () => profileResolver.resolve(
            agentConfig: any(named: 'agentConfig'),
            template: template,
            version: version,
          ),
        ).thenAnswer((_) async => resolvedProfile());

        expect(await callRoute(), isTrue);
        // The transient config mirrors DayAgentService.getOrCreatePlannerAgent:
        // the seeded template's model/profile, not an arbitrary default.
        verify(
          () => profileResolver.resolve(
            agentConfig: AgentConfig(modelId: template.modelId),
            template: template,
            version: version,
          ),
        ).called(1);
      },
    );

    test('false when a configured provider cannot serve the planner', () async {
      when(
        () => profileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => null);

      expect(await callRoute(), isFalse);
    });

    test(
      'existing planner resolves its assigned template and config',
      () async {
        const plannerConfig = AgentConfig(profileId: 'planner-profile');
        final planner = makeTestIdentity(
          id: dailyOsPlannerAgentId,
          agentId: dailyOsPlannerAgentId,
          kind: 'day_agent',
          config: plannerConfig,
        );
        final assignedTemplate = makeTestTemplate(
          id: 'assigned-day-template',
          agentId: 'assigned-day-template',
          kind: AgentTemplateKind.dayAgent,
        );
        final assignedVersion = makeTestTemplateVersion(
          agentId: assignedTemplate.id,
        );
        when(
          () => agentRepository.getEntity(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => planner);
        when(
          () => templateService.getTemplateForAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => assignedTemplate);
        when(
          () => templateService.getActiveVersion(assignedTemplate.id),
        ).thenAnswer((_) async => assignedVersion);
        when(
          () => profileResolver.resolve(
            agentConfig: plannerConfig,
            template: assignedTemplate,
            version: assignedVersion,
          ),
        ).thenAnswer((_) async => resolvedProfile());

        expect(await callRoute(), isTrue);
        // Not the seeded template: an existing planner must resolve through
        // its own assignment, never the day-agent default.
        verify(
          () => profileResolver.resolve(
            agentConfig: plannerConfig,
            template: assignedTemplate,
            version: assignedVersion,
          ),
        ).called(1);
        verifyNever(() => templateService.getTemplate(dayAgentTemplateId));
      },
    );

    test(
      'non-identity entity at the planner id falls back to the seeded template',
      () async {
        // `getEntity` is typed to the entity union; anything that is not an
        // AgentIdentityEntity must be treated as "no planner yet" rather than
        // read for a config it does not carry.
        when(() => agentRepository.getEntity(dailyOsPlannerAgentId)).thenAnswer(
          (_) async => makeTestTemplate(
            id: dailyOsPlannerAgentId,
            agentId: dailyOsPlannerAgentId,
            kind: AgentTemplateKind.dayAgent,
          ),
        );
        when(
          () => profileResolver.resolve(
            agentConfig: any(named: 'agentConfig'),
            template: template,
            version: version,
          ),
        ).thenAnswer((_) async => resolvedProfile());

        expect(await callRoute(), isTrue);
        verify(() => templateService.getTemplate(dayAgentTemplateId)).called(1);
      },
    );

    test('false when the seeded day-agent template is unavailable', () async {
      when(
        () => templateService.getTemplate(dayAgentTemplateId),
      ).thenAnswer((_) async => null);

      expect(await callRoute(), isFalse);
      verifyResolverNeverCalled();
    });

    test('false when the template has no active version', () async {
      when(
        () => templateService.getActiveVersion(dayAgentTemplateId),
      ).thenAnswer((_) async => null);

      expect(await callRoute(), isFalse);
      verifyResolverNeverCalled();
    });
  });

  group('dailyOsOnboardingProviderReadyProvider', () {
    Future<bool> readReady({required ResolvedProfile? profile}) {
      for (final type in const [
        AiConfigType.inferenceProvider,
        AiConfigType.model,
        AiConfigType.inferenceProfile,
      ]) {
        when(() => aiConfigRepository.watchConfigsByType(type)).thenAnswer(
          (_) => Stream.value(
            type == AiConfigType.inferenceProvider
                ? [testLocalInferenceProvider()]
                : const [],
          ),
        );
      }
      when(
        () => profileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => profile);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(agentRepository),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          profileResolverProvider.overrideWithValue(profileResolver),
        ],
      );
      addTearDown(container.dispose);
      container.listen(dailyOsOnboardingProviderReadyProvider, (_, _) {});
      return container.read(dailyOsOnboardingProviderReadyProvider.future);
    }

    test('true when the exact planner thinking route resolves', () async {
      expect(await readReady(profile: resolvedProfile()), isTrue);
    });

    test('false when the route does not resolve', () async {
      expect(await readReady(profile: null), isFalse);
    });

    test('awaits the AI config streams before resolving the route', () async {
      // The provider watches provider/model/profile config streams purely to
      // stay reactive to setup changes; resolution must happen after they
      // deliver, not race them.
      await readReady(profile: resolvedProfile());

      verify(
        () => aiConfigRepository.watchConfigsByType(
          AiConfigType.inferenceProvider,
        ),
      ).called(1);
      verify(
        () => aiConfigRepository.watchConfigsByType(AiConfigType.model),
      ).called(1);
      verify(
        () => aiConfigRepository.watchConfigsByType(
          AiConfigType.inferenceProfile,
        ),
      ).called(1);
      verify(() => agentRepository.getEntity(dailyOsPlannerAgentId)).called(1);
    });
  });
}
