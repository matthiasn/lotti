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

  group('resolveProfileIdForTask', () {
    test(
      'returns agentConfig.profileId when set (agent path wins)',
      () async {
        final agent = makeTestIdentity(
          config: const AgentConfig(profileId: 'agent-profile-id'),
        );
        final template = makeTestTemplate(profileId: 'tpl-profile-id');
        final version = makeTestTemplateVersion(profileId: 'ver-profile-id');

        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-1'),
        ).thenAnswer((_) async => agent);
        when(
          () => mockTemplateService.getTemplateForAgent(agent.agentId),
        ).thenAnswer((_) async => template);
        when(
          () => mockTemplateService.getActiveVersion(template.id),
        ).thenAnswer((_) async => version);

        final result = await resolver.resolveProfileIdForTask('task-1');

        expect(result, 'agent-profile-id');
      },
    );

    test(
      'falls back to version.profileId when agentConfig has none',
      () async {
        final agent = makeTestIdentity();
        final template = makeTestTemplate(profileId: 'tpl-profile-id');
        final version = makeTestTemplateVersion(profileId: 'ver-profile-id');

        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-1'),
        ).thenAnswer((_) async => agent);
        when(
          () => mockTemplateService.getTemplateForAgent(agent.agentId),
        ).thenAnswer((_) async => template);
        when(
          () => mockTemplateService.getActiveVersion(template.id),
        ).thenAnswer((_) async => version);

        final result = await resolver.resolveProfileIdForTask('task-1');

        expect(result, 'ver-profile-id');
      },
    );

    test(
      'falls back to template.profileId when version has none',
      () async {
        final agent = makeTestIdentity();
        final template = makeTestTemplate(profileId: 'tpl-profile-id');
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

        final result = await resolver.resolveProfileIdForTask('task-1');

        expect(result, 'tpl-profile-id');
      },
    );

    test(
      'falls back to task-level profileId when no agent exists',
      () async {
        final resolverWithLookup = ProfileAutomationResolver(
          taskAgentService: mockTaskAgentService,
          templateService: mockTemplateService,
          profileResolver: mockProfileResolver,
          taskProfileLookup: (taskId) async =>
              taskId == 'task-orphan' ? 'task-inherited-profile' : null,
        );
        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-orphan'),
        ).thenAnswer((_) async => null);

        final result = await resolverWithLookup.resolveProfileIdForTask(
          'task-orphan',
        );

        expect(result, 'task-inherited-profile');
      },
    );

    test(
      'agent-level profile wins over task-level profile — proves we never '
      'silently demote to category default after task creation',
      () async {
        final agent = makeTestIdentity(
          config: const AgentConfig(profileId: 'agent-pin'),
        );
        final template = makeTestTemplate();
        final version = makeTestTemplateVersion();
        final resolverWithLookup = ProfileAutomationResolver(
          taskAgentService: mockTaskAgentService,
          templateService: mockTemplateService,
          profileResolver: mockProfileResolver,
          taskProfileLookup: (_) async => 'task-different-profile',
        );
        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-1'),
        ).thenAnswer((_) async => agent);
        when(
          () => mockTemplateService.getTemplateForAgent(agent.agentId),
        ).thenAnswer((_) async => template);
        when(
          () => mockTemplateService.getActiveVersion(template.id),
        ).thenAnswer((_) async => version);

        final result = await resolverWithLookup.resolveProfileIdForTask(
          'task-1',
        );

        expect(result, 'agent-pin');
      },
    );

    test(
      'returns null when no path yields a profile id',
      () async {
        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await resolver.resolveProfileIdForTask('task-1');

        expect(result, isNull);
      },
    );

    test(
      'never reads category.defaultProfileId — the dispatcher must rely on '
      'the agent/task chain, not the category default',
      () async {
        // Wire a categoryProfileLookup that would explode the test if called.
        final resolverWithCategory = ProfileAutomationResolver(
          taskAgentService: mockTaskAgentService,
          templateService: mockTemplateService,
          profileResolver: mockProfileResolver,
          taskProfileLookup: (_) async => null,
          categoryProfileLookup: (_) async {
            fail(
              'resolveProfileIdForTask must not consult '
              'categoryProfileLookup',
            );
          },
        );
        when(
          () => mockTaskAgentService.getTaskAgentForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await resolverWithCategory.resolveProfileIdForTask(
          'task-1',
        );

        expect(result, isNull);
      },
    );
  });
}
