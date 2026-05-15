import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

enum _GeneratedAgentResolutionOutcome {
  noAgent,
  noTemplate,
  noActiveVersion,
  unresolvedProfile,
  resolvedProfile,
}

enum _GeneratedTaskProfileOutcome {
  noProfileId,
  unresolvedProfile,
  resolvedProfile,
}

class _GeneratedAutomationResolutionScenario {
  const _GeneratedAutomationResolutionScenario({
    required this.agentOutcome,
    required this.taskOutcome,
  });

  final _GeneratedAgentResolutionOutcome agentOutcome;
  final _GeneratedTaskProfileOutcome taskOutcome;

  bool get reachesTemplate =>
      agentOutcome != _GeneratedAgentResolutionOutcome.noAgent;

  bool get reachesVersion =>
      reachesTemplate &&
      agentOutcome != _GeneratedAgentResolutionOutcome.noTemplate;

  bool get reachesAgentProfileResolution =>
      reachesVersion &&
      agentOutcome != _GeneratedAgentResolutionOutcome.noActiveVersion;

  bool get resolvesViaAgent =>
      agentOutcome == _GeneratedAgentResolutionOutcome.resolvedProfile;

  bool get fallsBackToTask => !resolvesViaAgent;

  bool get hasTaskProfileId =>
      taskOutcome != _GeneratedTaskProfileOutcome.noProfileId;

  bool get resolvesViaTask =>
      fallsBackToTask &&
      taskOutcome == _GeneratedTaskProfileOutcome.resolvedProfile;

  @override
  String toString() {
    return '_GeneratedAutomationResolutionScenario('
        'agentOutcome: $agentOutcome, taskOutcome: $taskOutcome)';
  }
}

extension _AnyGeneratedAutomationResolutionScenario on glados.Any {
  glados.Generator<_GeneratedAgentResolutionOutcome>
  get agentResolutionOutcome =>
      glados.AnyUtils(this).choose(_GeneratedAgentResolutionOutcome.values);

  glados.Generator<_GeneratedTaskProfileOutcome> get taskProfileOutcome =>
      glados.AnyUtils(this).choose(_GeneratedTaskProfileOutcome.values);

  glados.Generator<_GeneratedAutomationResolutionScenario>
  get automationResolutionScenario => glados.CombinableAny(this).combine2(
    agentResolutionOutcome,
    taskProfileOutcome,
    (
      _GeneratedAgentResolutionOutcome agentOutcome,
      _GeneratedTaskProfileOutcome taskOutcome,
    ) => _GeneratedAutomationResolutionScenario(
      agentOutcome: agentOutcome,
      taskOutcome: taskOutcome,
    ),
  );
}

void main() {
  late MockTaskAgentService mockTaskAgentService;
  late MockAgentTemplateService mockTemplateService;
  late MockProfileResolver mockProfileResolver;
  late ProfileAutomationResolver resolver;

  setUpAll(() {
    registerFallbackValue(const AgentConfig());
    registerFallbackValue(makeTestTemplate());
    registerFallbackValue(makeTestTemplateVersion());
  });

  setUp(() {
    mockTaskAgentService = MockTaskAgentService();
    mockTemplateService = MockAgentTemplateService();
    mockProfileResolver = MockProfileResolver();
    resolver = ProfileAutomationResolver(
      taskAgentService: mockTaskAgentService,
      templateService: mockTemplateService,
      profileResolver: mockProfileResolver,
    );
  });

  ResolvedProfile makeResolvedProfile() {
    return ResolvedProfile(
      thinkingModelId: 'models/gemini-3-flash-preview',
      thinkingProvider: testInferenceProvider(),
    );
  }

  group('ProfileAutomationResolver', () {
    test('resolves profile through full chain', () async {
      final agent = makeTestIdentity(
        config: const AgentConfig(profileId: 'profile-001'),
      );
      final template = makeTestTemplate();
      final version = makeTestTemplateVersion();
      final resolvedProfile = makeResolvedProfile();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => template);
      when(
        () => mockTemplateService.getActiveVersion(template.id),
      ).thenAnswer((_) async => version);
      when(
        () => mockProfileResolver.resolve(
          agentConfig: agent.config,
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => resolvedProfile);

      final result = await resolver.resolveForTask('task-1');

      expect(result, equals(resolvedProfile));
      verify(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).called(1);
      verify(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).called(1);
      verify(
        () => mockTemplateService.getActiveVersion(template.id),
      ).called(1);
    });

    test('returns null when task has no agent and no profile lookup', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-orphan'),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveForTask('task-orphan');

      expect(result, isNull);
      verifyNever(
        () => mockTemplateService.getTemplateForAgent(any()),
      );
    });

    test('returns null when agent has no template', () async {
      final agent = makeTestIdentity();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveForTask('task-1');

      expect(result, isNull);
      verifyNever(
        () => mockTemplateService.getActiveVersion(any()),
      );
    });

    test('returns null when template has no active version', () async {
      final agent = makeTestIdentity();
      final template = makeTestTemplate();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => template);
      when(
        () => mockTemplateService.getActiveVersion(template.id),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveForTask('task-1');

      expect(result, isNull);
      verifyNever(
        () => mockProfileResolver.resolve(
          agentConfig: any(named: 'agentConfig'),
          template: any(named: 'template'),
          version: any(named: 'version'),
        ),
      );
    });

    test('returns null when profile resolver returns null', () async {
      final agent = makeTestIdentity();
      final template = makeTestTemplate();
      final version = makeTestTemplateVersion();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => template);
      when(
        () => mockTemplateService.getActiveVersion(template.id),
      ).thenAnswer((_) async => version);
      when(
        () => mockProfileResolver.resolve(
          agentConfig: agent.config,
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => null);

      final result = await resolver.resolveForTask('task-1');

      expect(result, isNull);
    });

    test('passes agent config to profile resolver', () async {
      const agentConfig = AgentConfig(profileId: 'custom-profile');
      final agent = makeTestIdentity(config: agentConfig);
      final template = makeTestTemplate(profileId: 'template-profile');
      final version = makeTestTemplateVersion(profileId: 'version-profile');
      final resolvedProfile = makeResolvedProfile();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => template);
      when(
        () => mockTemplateService.getActiveVersion(template.id),
      ).thenAnswer((_) async => version);
      when(
        () => mockProfileResolver.resolve(
          agentConfig: agentConfig,
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => resolvedProfile);

      final result = await resolver.resolveForTask('task-1');

      expect(result, isNotNull);
      // Verify the exact agentConfig was forwarded.
      verify(
        () => mockProfileResolver.resolve(
          agentConfig: agentConfig,
          template: template,
          version: version,
        ),
      ).called(1);
    });
  });

  group('task-profile fallback', () {
    late ProfileAutomationResolver resolverWithLookup;

    setUp(() {
      resolverWithLookup = ProfileAutomationResolver(
        taskAgentService: mockTaskAgentService,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        taskProfileLookup: (taskId) async {
          if (taskId == 'task-with-profile') return 'inherited-profile-1';
          return null;
        },
      );
    });

    test('falls back to task profileId when no agent exists', () async {
      final resolvedProfile = makeResolvedProfile();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-with-profile'),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileResolver.resolveByProfileId('inherited-profile-1'),
      ).thenAnswer((_) async => resolvedProfile);

      final result = await resolverWithLookup.resolveForTask(
        'task-with-profile',
      );

      expect(result, equals(resolvedProfile));
      verify(
        () => mockProfileResolver.resolveByProfileId('inherited-profile-1'),
      ).called(1);
    });

    test('prefers agent path over task-profile fallback', () async {
      final agent = makeTestIdentity(
        config: const AgentConfig(profileId: 'agent-profile'),
      );
      final template = makeTestTemplate();
      final version = makeTestTemplateVersion();
      final resolvedProfile = makeResolvedProfile();

      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-with-profile'),
      ).thenAnswer((_) async => agent);
      when(
        () => mockTemplateService.getTemplateForAgent(agent.agentId),
      ).thenAnswer((_) async => template);
      when(
        () => mockTemplateService.getActiveVersion(template.id),
      ).thenAnswer((_) async => version);
      when(
        () => mockProfileResolver.resolve(
          agentConfig: agent.config,
          template: template,
          version: version,
        ),
      ).thenAnswer((_) async => resolvedProfile);

      final result = await resolverWithLookup.resolveForTask(
        'task-with-profile',
      );

      expect(result, equals(resolvedProfile));
      // Agent path was used, not the task fallback.
      verifyNever(
        () => mockProfileResolver.resolveByProfileId(any()),
      );
    });

    test('returns null when no agent and task has no profileId', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-no-profile'),
      ).thenAnswer((_) async => null);

      final result = await resolverWithLookup.resolveForTask('task-no-profile');

      expect(result, isNull);
      verifyNever(
        () => mockProfileResolver.resolveByProfileId(any()),
      );
    });

    test('returns null when task profileId cannot be resolved', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-with-profile'),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileResolver.resolveByProfileId('inherited-profile-1'),
      ).thenAnswer((_) async => null);

      final result = await resolverWithLookup.resolveForTask(
        'task-with-profile',
      );

      expect(result, isNull);
    });

    glados.Glados(
      glados.any.automationResolutionScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'matches generated agent-chain and task-fallback semantics',
      (scenario) async {
        const taskId = 'generated-task';
        const taskProfileId = 'generated-task-profile';
        final generatedTaskAgentService = MockTaskAgentService();
        final generatedTemplateService = MockAgentTemplateService();
        final generatedProfileResolver = MockProfileResolver();
        final agent = makeTestIdentity(
          agentId: 'generated-agent',
          config: const AgentConfig(profileId: 'generated-agent-profile'),
        );
        final template = makeTestTemplate(id: 'generated-template');
        final version = makeTestTemplateVersion(id: 'generated-version');
        final agentProfile = ResolvedProfile(
          thinkingModelId: 'generated-agent-model',
          thinkingProvider: testInferenceProvider(id: 'generated-agent-p'),
        );
        final taskProfile = ResolvedProfile(
          thinkingModelId: 'generated-task-model',
          thinkingProvider: testInferenceProvider(id: 'generated-task-p'),
        );
        var taskProfileLookupCount = 0;

        when(
          () => generatedTaskAgentService.getTaskAgentForTask(taskId),
        ).thenAnswer(
          (_) async => scenario.reachesTemplate ? agent : null,
        );

        if (scenario.reachesTemplate) {
          when(
            () => generatedTemplateService.getTemplateForAgent(agent.agentId),
          ).thenAnswer(
            (_) async => scenario.reachesVersion ? template : null,
          );
        }

        if (scenario.reachesVersion) {
          when(
            () => generatedTemplateService.getActiveVersion(template.id),
          ).thenAnswer(
            (_) async =>
                scenario.reachesAgentProfileResolution ? version : null,
          );
        }

        if (scenario.reachesAgentProfileResolution) {
          when(
            () => generatedProfileResolver.resolve(
              agentConfig: agent.config,
              template: template,
              version: version,
            ),
          ).thenAnswer(
            (_) async => scenario.resolvesViaAgent ? agentProfile : null,
          );
        }

        if (scenario.fallsBackToTask && scenario.hasTaskProfileId) {
          when(
            () => generatedProfileResolver.resolveByProfileId(taskProfileId),
          ).thenAnswer(
            (_) async => scenario.resolvesViaTask ? taskProfile : null,
          );
        }

        final generatedResolver = ProfileAutomationResolver(
          taskAgentService: generatedTaskAgentService,
          templateService: generatedTemplateService,
          profileResolver: generatedProfileResolver,
          taskProfileLookup: (lookupTaskId) async {
            taskProfileLookupCount++;
            expect(lookupTaskId, taskId, reason: '$scenario');
            return scenario.hasTaskProfileId ? taskProfileId : null;
          },
        );

        final result = await generatedResolver.resolveForTask(taskId);

        if (scenario.resolvesViaAgent) {
          expect(result, same(agentProfile), reason: '$scenario');
        } else if (scenario.resolvesViaTask) {
          expect(result, same(taskProfile), reason: '$scenario');
        } else {
          expect(result, isNull, reason: '$scenario');
        }

        expect(
          taskProfileLookupCount,
          scenario.fallsBackToTask ? 1 : 0,
          reason: '$scenario',
        );
        verify(
          () => generatedTaskAgentService.getTaskAgentForTask(taskId),
        ).called(1);

        if (scenario.reachesTemplate) {
          verify(
            () => generatedTemplateService.getTemplateForAgent(agent.agentId),
          ).called(1);
        } else {
          verifyNever(
            () => generatedTemplateService.getTemplateForAgent(any()),
          );
        }

        if (scenario.reachesVersion) {
          verify(
            () => generatedTemplateService.getActiveVersion(template.id),
          ).called(1);
        } else {
          verifyNever(
            () => generatedTemplateService.getActiveVersion(any()),
          );
        }

        if (scenario.reachesAgentProfileResolution) {
          verify(
            () => generatedProfileResolver.resolve(
              agentConfig: agent.config,
              template: template,
              version: version,
            ),
          ).called(1);
        } else {
          verifyNever(
            () => generatedProfileResolver.resolve(
              agentConfig: any(named: 'agentConfig'),
              template: any(named: 'template'),
              version: any(named: 'version'),
            ),
          );
        }

        if (scenario.fallsBackToTask && scenario.hasTaskProfileId) {
          verify(
            () => generatedProfileResolver.resolveByProfileId(taskProfileId),
          ).called(1);
        } else {
          verifyNever(
            () => generatedProfileResolver.resolveByProfileId(any()),
          );
        }
      },
      tags: 'glados',
    );
  });

  group('resolveForCategory', () {
    test('resolves via category defaultProfileId when lookup wired', () async {
      final resolverWithCategory = ProfileAutomationResolver(
        taskAgentService: mockTaskAgentService,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        categoryProfileLookup: (categoryId) async {
          if (categoryId == 'cat-journal') return 'category-profile-1';
          return null;
        },
      );
      final resolvedProfile = makeResolvedProfile();
      when(
        () => mockProfileResolver.resolveByProfileId('category-profile-1'),
      ).thenAnswer((_) async => resolvedProfile);

      final result = await resolverWithCategory.resolveForCategory(
        'cat-journal',
      );

      expect(result, equals(resolvedProfile));
      verify(
        () => mockProfileResolver.resolveByProfileId('category-profile-1'),
      ).called(1);
      // Agent path must not be consulted for the category fallback.
      verifyNever(
        () => mockTaskAgentService.getTaskAgentForTask(any()),
      );
    });

    test('returns null when no category lookup is configured', () async {
      final result = await resolver.resolveForCategory('cat-journal');

      expect(result, isNull);
      verifyNever(
        () => mockProfileResolver.resolveByProfileId(any()),
      );
    });

    test('returns null when category has no defaultProfileId', () async {
      final resolverWithCategory = ProfileAutomationResolver(
        taskAgentService: mockTaskAgentService,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        categoryProfileLookup: (_) async => null,
      );

      final result = await resolverWithCategory.resolveForCategory(
        'cat-no-profile',
      );

      expect(result, isNull);
      verifyNever(
        () => mockProfileResolver.resolveByProfileId(any()),
      );
    });

    test('returns null when profile cannot be loaded', () async {
      final resolverWithCategory = ProfileAutomationResolver(
        taskAgentService: mockTaskAgentService,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        categoryProfileLookup: (_) async => 'broken-profile',
      );
      when(
        () => mockProfileResolver.resolveByProfileId('broken-profile'),
      ).thenAnswer((_) async => null);

      final result = await resolverWithCategory.resolveForCategory('cat');

      expect(result, isNull);
    });
  });
}
