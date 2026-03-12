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

    test('returns null when task has no agent', () async {
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
}
