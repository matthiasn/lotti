import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';
import 'profile_automation_resolver_test_helpers.dart';

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
      subjectAgentLookup: mockTaskAgentService.getTaskAgentForTask,
      templateService: mockTemplateService,
      profileResolver: mockProfileResolver,
      domainLogger: MockDomainLogger(),
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

      final result = await resolver.resolveForSubject('task-1');

      // The profile comes back stamped with the agent that chose it, which is
      // how an AI output later names who ran it.
      expect(
        result,
        equals(
          resolvedProfile.forAgent(
            agentId: agent.agentId,
            agentName: agent.displayName,
          ),
        ),
      );
      expect(result?.agentId, agent.agentId);
      expect(result?.agentName, agent.displayName);
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

      final result = await resolver.resolveForSubject('task-orphan');

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

      final result = await resolver.resolveForSubject('task-1');

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

      final result = await resolver.resolveForSubject('task-1');

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

      final result = await resolver.resolveForSubject('task-1');

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

      final result = await resolver.resolveForSubject('task-1');

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

  test("the Settings default profile is the profile resolver's", () async {
    final profile = ResolvedProfile(
      thinkingModelId: 'thinking-native',
      thinkingProvider: testInferenceProvider(),
    );
    when(
      () => mockProfileResolver.resolveDefaultProfile(),
    ).thenAnswer((_) async => profile);

    expect(await resolver.resolveDefaultProfile(), same(profile));
  });

  group('task-profile fallback', () {
    late ProfileAutomationResolver resolverWithLookup;

    setUp(() {
      resolverWithLookup = ProfileAutomationResolver(
        subjectAgentLookup: mockTaskAgentService.getTaskAgentForTask,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        domainLogger: MockDomainLogger(),
        subjectProfileLookup: (taskId) async {
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

      final result = await resolverWithLookup.resolveForSubject(
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

      final result = await resolverWithLookup.resolveForSubject(
        'task-with-profile',
      );

      expect(result?.agentId, agent.agentId);
      // Agent path was used, not the task fallback.
      verifyNever(
        () => mockProfileResolver.resolveByProfileId(any()),
      );
    });

    test('returns null when no agent and task has no profileId', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-no-profile'),
      ).thenAnswer((_) async => null);

      final result = await resolverWithLookup.resolveForSubject(
        'task-no-profile',
      );

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

      final result = await resolverWithLookup.resolveForSubject(
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
          subjectAgentLookup: generatedTaskAgentService.getTaskAgentForTask,
          templateService: generatedTemplateService,
          profileResolver: generatedProfileResolver,
          domainLogger: MockDomainLogger(),
          subjectProfileLookup: (lookupTaskId) async {
            taskProfileLookupCount++;
            expect(lookupTaskId, taskId, reason: '$scenario');
            return scenario.hasTaskProfileId ? taskProfileId : null;
          },
        );

        final result = await generatedResolver.resolveForSubject(taskId);

        if (scenario.resolvesViaAgent) {
          expect(
            result,
            agentProfile.forAgent(
              agentId: agent.agentId,
              agentName: agent.displayName,
            ),
            reason: '$scenario',
          );
        } else if (scenario.resolvesViaTask) {
          // A profile the subject inherited names no agent.
          expect(result, same(taskProfile), reason: '$scenario');
          expect(result?.agentId, isNull, reason: '$scenario');
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

  // `resolveForSubject` answers which profile drives the task's agent. Once a
  // thinking model is picked by hand that answer is a bare model route with no
  // capability slots and no skill assignments, so automation needs the
  // profiles the task inherits as well.
  group('resolveAutomationFallbacks', () {
    ProfileAutomationResolver makeResolver({
      SubjectProfileLookup? subjectProfileLookup,
      CategoryProfileLookup? categoryProfileLookup,
      SubjectCategoryLookup? subjectCategoryLookup,
    }) {
      return ProfileAutomationResolver(
        subjectAgentLookup: mockTaskAgentService.getTaskAgentForTask,
        templateService: mockTemplateService,
        profileResolver: mockProfileResolver,
        domainLogger: MockDomainLogger(),
        subjectProfileLookup: subjectProfileLookup,
        categoryProfileLookup: categoryProfileLookup,
        subjectCategoryLookup: subjectCategoryLookup,
      );
    }

    test(
      'returns the task profile before the category default',
      () async {
        final taskProfile = makeResolvedProfile();
        final categoryProfile = ResolvedProfile(
          thinkingModelId: 'category-thinking',
          thinkingProvider: testInferenceProvider(id: 'p-category'),
        );
        final fallbackResolver = makeResolver(
          subjectProfileLookup: (_) async => 'task-profile',
          subjectCategoryLookup: (_) async => 'cat-1',
          categoryProfileLookup: (categoryId) async =>
              categoryId == 'cat-1' ? 'category-profile' : null,
        );
        when(
          () => mockProfileResolver.resolveByProfileId('task-profile'),
        ).thenAnswer((_) async => taskProfile);
        when(
          () => mockProfileResolver.resolveByProfileId('category-profile'),
        ).thenAnswer((_) async => categoryProfile);

        final result = await fallbackResolver.resolveAutomationFallbacks(
          'task-1',
        );

        expect(result, [taskProfile, categoryProfile]);
        // The agent path belongs to `resolveForSubject`; the fallback walk must
        // not re-run it.
        verifyNever(() => mockTaskAgentService.getTaskAgentForTask(any()));
      },
    );

    test('resolves a shared profile id only once', () async {
      final profile = makeResolvedProfile();
      final fallbackResolver = makeResolver(
        subjectProfileLookup: (_) async => 'shared-profile',
        subjectCategoryLookup: (_) async => 'cat-1',
        categoryProfileLookup: (_) async => 'shared-profile',
      );
      when(
        () => mockProfileResolver.resolveByProfileId('shared-profile'),
      ).thenAnswer((_) async => profile);

      final result = await fallbackResolver.resolveAutomationFallbacks(
        'task-1',
      );

      expect(result, [profile]);
      verify(
        () => mockProfileResolver.resolveByProfileId('shared-profile'),
      ).called(1);
    });

    // A task created before its category had a default profile carries no
    // `profileId` of its own — the category is the only thing left that can
    // supply the capability.
    test(
      'falls through to the category when the task has no profile',
      () async {
        final categoryProfile = makeResolvedProfile();
        final fallbackResolver = makeResolver(
          subjectProfileLookup: (_) async => null,
          subjectCategoryLookup: (_) async => 'cat-1',
          categoryProfileLookup: (_) async => 'category-profile',
        );
        when(
          () => mockProfileResolver.resolveByProfileId('category-profile'),
        ).thenAnswer((_) async => categoryProfile);

        final result = await fallbackResolver.resolveAutomationFallbacks(
          'task-1',
        );

        expect(result, [categoryProfile]);
      },
    );

    // A deleted or broken profile must not hide the one behind it.
    test(
      'skips a candidate that cannot be resolved and keeps walking',
      () async {
        final categoryProfile = makeResolvedProfile();
        final fallbackResolver = makeResolver(
          subjectProfileLookup: (_) async => 'deleted-profile',
          subjectCategoryLookup: (_) async => 'cat-1',
          categoryProfileLookup: (_) async => 'category-profile',
        );
        when(
          () => mockProfileResolver.resolveByProfileId('deleted-profile'),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileResolver.resolveByProfileId('category-profile'),
        ).thenAnswer((_) async => categoryProfile);

        final result = await fallbackResolver.resolveAutomationFallbacks(
          'task-1',
        );

        expect(result, [categoryProfile]);
      },
    );

    test('returns nothing when the entry has no category', () async {
      final fallbackResolver = makeResolver(
        subjectProfileLookup: (_) async => null,
        subjectCategoryLookup: (_) async => null,
        categoryProfileLookup: (_) async =>
            fail('category profile must not be read without a category'),
      );

      final result = await fallbackResolver.resolveAutomationFallbacks(
        'task-1',
      );

      expect(result, isEmpty);
    });

    test('returns nothing when no lookups are wired', () async {
      final result = await resolver.resolveAutomationFallbacks('task-1');

      expect(result, isEmpty);
      verifyNever(() => mockProfileResolver.resolveByProfileId(any()));
    });
  });

  // The rule Goals and People recordings both transcribe by: the category's
  // profile, else the Settings default — whichever owns a transcription slot.
  group('resolveTranscriptionProfile', () {
    ResolvedProfile transcribing(String id, {bool model = true}) =>
        ResolvedProfile(
          profileId: id,
          thinkingModelId: 'thinking-$id',
          thinkingProvider: testInferenceProvider(),
          transcriptionModelId: model ? 'transcription-$id' : null,
          transcriptionProvider: testInferenceProvider(id: 'audio-$id'),
        );

    ProfileAutomationResolver withCategories({
      Map<String, String> categoryProfiles = const {},
      SubjectCategoryLookup? subjectCategoryLookup,
    }) => ProfileAutomationResolver(
      subjectAgentLookup: mockTaskAgentService.getTaskAgentForTask,
      templateService: mockTemplateService,
      profileResolver: mockProfileResolver,
      domainLogger: MockDomainLogger(),
      categoryProfileLookup: (categoryId) async => categoryProfiles[categoryId],
      subjectCategoryLookup: subjectCategoryLookup,
    );

    void stubDefault(ResolvedProfile? profile) => when(
      () => mockProfileResolver.resolveDefaultProfile(),
    ).thenAnswer((_) async => profile);

    void stubProfile(String id, ResolvedProfile? profile) => when(
      () => mockProfileResolver.resolveByProfileId(id),
    ).thenAnswer((_) async => profile);

    test(
      "the category's profile wins, and the default is never asked",
      () async {
        final category = transcribing('people-profile');
        stubProfile('people-profile', category);
        stubDefault(transcribing('default'));

        final result = await withCategories(
          categoryProfiles: {'people': 'people-profile'},
        ).resolveTranscriptionProfile(categoryId: 'people');

        expect(result, same(category));
        verifyNever(() => mockProfileResolver.resolveDefaultProfile());
      },
    );

    test(
      'a category profile that names no transcription model falls to the '
      'Settings default',
      () async {
        final fallback = transcribing('default');
        stubProfile('goals-profile', transcribing('goals', model: false));
        stubDefault(fallback);

        final result = await withCategories(
          categoryProfiles: {'goals': 'goals-profile'},
        ).resolveTranscriptionProfile(categoryId: 'goals');

        expect(result, same(fallback));
      },
    );

    test(
      'a category without a profile, and no category at all, both fall to '
      'the Settings default',
      () async {
        final fallback = transcribing('default');
        stubDefault(fallback);
        final resolver = withCategories();

        expect(
          await resolver.resolveTranscriptionProfile(categoryId: 'bare'),
          same(fallback),
        );
        expect(await resolver.resolveTranscriptionProfile(), same(fallback));
        verifyNever(() => mockProfileResolver.resolveByProfileId(any()));
      },
    );

    for (final missing in ['profile', 'model', 'provider']) {
      test(
        'nothing transcribes when the default has no $missing',
        () async {
          stubDefault(switch (missing) {
            'profile' => null,
            'model' => transcribing('default', model: false),
            _ => ResolvedProfile(
              thinkingModelId: 'thinking',
              thinkingProvider: testInferenceProvider(),
              transcriptionModelId: 'transcription',
            ),
          });

          expect(await withCategories().resolveTranscriptionProfile(), isNull);
        },
      );
    }

    test('categoryOfSubject reads the wired lookup, and is null without '
        'one', () async {
      final wired = withCategories(
        subjectCategoryLookup: (subjectId) async =>
            subjectId == 'goal-1' ? 'goals' : null,
      );

      expect(await wired.categoryOfSubject('goal-1'), 'goals');
      expect(await wired.categoryOfSubject('other'), isNull);
      expect(await resolver.categoryOfSubject('goal-1'), isNull);
    });
  });
}
