import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

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
  });
}
