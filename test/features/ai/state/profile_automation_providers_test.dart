import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('Profile automation providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(
            MockAiConfigRepository(),
          ),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          agentTemplateServiceProvider.overrideWithValue(
            MockAgentTemplateService(),
          ),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
    });

    tearDown(() => container.dispose());

    test(
      'profileResolverProvider wires the repo into a working resolver',
      () async {
        final mockAiConfigRepo = MockAiConfigRepository();
        final profile = AiTestDataFactory.createTestProfile(id: 'profile-1');
        when(
          () => mockAiConfigRepo.getConfigById('profile-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-1',
              providerModelId: profile.thinkingModelId,
              inferenceProviderId: 'provider-1',
            ),
          ],
        );
        when(() => mockAiConfigRepo.getConfigById('provider-1')).thenAnswer(
          (_) async => AiTestDataFactory.createTestProvider(id: 'provider-1'),
        );

        final scoped = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
            agentTemplateServiceProvider.overrideWithValue(
              MockAgentTemplateService(),
            ),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          ],
        );
        addTearDown(scoped.dispose);

        final resolver = scoped.read(profileResolverProvider);
        final resolved = await resolver.resolveByProfileId('profile-1');

        expect(resolved, isNotNull);
        expect(resolved!.thinkingModelId, profile.thinkingModelId);
        expect(resolved.thinkingProvider.id, 'provider-1');
        verify(() => mockAiConfigRepo.getConfigById('profile-1')).called(1);
      },
    );

    test(
      'profileAutomationServiceProvider reports no automation when nothing '
      'is configured',
      () async {
        final mockAiConfigRepo = MockAiConfigRepository();
        final mockDb = MockJournalDb();
        final mockTaskAgentService = MockTaskAgentService();
        when(
          () => mockAiConfigRepo.getConfigById(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => []);
        when(
          () => mockDb.journalEntityById(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockTaskAgentService.getTaskAgentForTask(any()),
        ).thenAnswer((_) async => null);

        final scoped = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
            taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
            agentTemplateServiceProvider.overrideWithValue(
              MockAgentTemplateService(),
            ),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
            journalDbProvider.overrideWithValue(mockDb),
          ],
        );
        addTearDown(scoped.dispose);

        final service = scoped.read(profileAutomationServiceProvider);
        final hasTranscription = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(hasTranscription, isFalse);
        // The category gate denies first — an entry with no category has
        // nobody who opted in — so the agent lookup is never reached.
        verifyNever(() => mockTaskAgentService.getTaskAgentForTask('task-1'));
        verify(() => mockDb.journalEntityById('task-1')).called(1);
      },
    );
  });

  group('taskProfileLookup via resolveForTask', () {
    late MockJournalDb mockDb;
    late MockTaskAgentService mockTaskAgentService;
    late MockAiConfigRepository mockAiConfigRepo;

    setUp(() {
      mockDb = MockJournalDb();
      mockTaskAgentService = MockTaskAgentService();
      mockAiConfigRepo = MockAiConfigRepository();
      // Stub getConfigById so it doesn't throw on unstubbed calls.
      when(
        () => mockAiConfigRepo.getConfigById(any()),
      ).thenAnswer((_) async => null);
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
          taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
          agentTemplateServiceProvider.overrideWithValue(
            MockAgentTemplateService(),
          ),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          journalDbProvider.overrideWithValue(mockDb),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('resolveForTask falls back to task profileId when no agent', () async {
      // No agent for this task — agent path returns null.
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-1'),
      ).thenAnswer((_) async => null);

      // Task has a profileId.
      when(() => mockDb.journalEntityById('task-1')).thenAnswer(
        (_) async => JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: TaskData(
            status: taskStatusFromString(''),
            title: 'Test',
            statusHistory: [],
            dateTo: DateTime(2024),
            dateFrom: DateTime(2024),
            estimate: Duration.zero,
            profileId: 'profile-abc',
          ),
        ),
      );

      final container = createContainer();
      final resolver = container.read(profileAutomationResolverProvider);
      // resolveForTask exercises the taskProfileLookup closure.
      // It will return null because profile-abc is not a real config,
      // but the lookup itself is executed (covering the provider lines).
      final result = await resolver.resolveForTask('task-1');
      // The profile can't be resolved (no real AI config), so result is null.
      // But we verify the DB was queried for the task.
      verify(() => mockDb.journalEntityById('task-1')).called(1);
      expect(result, isNull);
    });

    test('resolveForTask returns null when entity is not a Task', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('entry-1'),
      ).thenAnswer((_) async => null);

      when(() => mockDb.journalEntityById('entry-1')).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          entryText: const EntryText(plainText: 'some text'),
        ),
      );

      final container = createContainer();
      final resolver = container.read(profileAutomationResolverProvider);
      final result = await resolver.resolveForTask('entry-1');
      expect(result, isNull);
    });

    test('resolveForTask returns null when task has no profileId', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('task-2'),
      ).thenAnswer((_) async => null);

      when(() => mockDb.journalEntityById('task-2')).thenAnswer(
        (_) async => JournalEntity.task(
          meta: Metadata(
            id: 'task-2',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
          ),
          data: TaskData(
            status: taskStatusFromString(''),
            title: 'Test',
            statusHistory: [],
            dateTo: DateTime(2024),
            dateFrom: DateTime(2024),
            estimate: Duration.zero,
          ),
        ),
      );

      final container = createContainer();
      final resolver = container.read(profileAutomationResolverProvider);
      final result = await resolver.resolveForTask('task-2');
      expect(result, isNull);
    });

    test('resolveForTask returns null when entity not found', () async {
      when(
        () => mockTaskAgentService.getTaskAgentForTask('gone'),
      ).thenAnswer((_) async => null);

      when(() => mockDb.journalEntityById('gone')).thenAnswer(
        (_) async => null,
      );

      final container = createContainer();
      final resolver = container.read(profileAutomationResolverProvider);
      final result = await resolver.resolveForTask('gone');
      expect(result, isNull);
    });
  });

  group('categoryProfileLookup via resolveForCategory', () {
    late MockJournalDb mockDb;
    late MockAiConfigRepository mockAiConfigRepo;

    setUp(() {
      mockDb = MockJournalDb();
      mockAiConfigRepo = MockAiConfigRepository();
      when(
        () => mockAiConfigRepo.getConfigById(any()),
      ).thenAnswer((_) async => null);
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          agentTemplateServiceProvider.overrideWithValue(
            MockAgentTemplateService(),
          ),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          journalDbProvider.overrideWithValue(mockDb),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    CategoryDefinition makeCategory({String? defaultProfileId}) {
      return CategoryDefinition(
        id: 'cat-1',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        name: 'Journal',
        vectorClock: null,
        private: false,
        active: true,
        defaultProfileId: defaultProfileId,
      );
    }

    test(
      'resolveForCategory queries the DB and forwards defaultProfileId',
      () async {
        when(
          () => mockDb.getCategoryById('cat-1'),
        ).thenAnswer((_) async => makeCategory(defaultProfileId: 'profile-x'));

        final container = createContainer();
        final resolver = container.read(profileAutomationResolverProvider);
        // The profile-x lookup returns null (mockAiConfigRepo default), so the
        // resolver returns null — but the closure ran, covering the lines.
        final result = await resolver.resolveForCategory('cat-1');

        verify(() => mockDb.getCategoryById('cat-1')).called(1);
        verify(() => mockAiConfigRepo.getConfigById('profile-x')).called(1);
        expect(result, isNull);
      },
    );

    test(
      'resolveForCategory returns null when category has no defaultProfileId',
      () async {
        when(
          () => mockDb.getCategoryById('cat-no-profile'),
        ).thenAnswer((_) async => makeCategory());

        final container = createContainer();
        final resolver = container.read(profileAutomationResolverProvider);
        final result = await resolver.resolveForCategory('cat-no-profile');

        verify(() => mockDb.getCategoryById('cat-no-profile')).called(1);
        verifyNever(() => mockAiConfigRepo.getConfigById(any()));
        expect(result, isNull);
      },
    );

    test('resolveForCategory returns null when category not found', () async {
      when(
        () => mockDb.getCategoryById('cat-missing'),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      final resolver = container.read(profileAutomationResolverProvider);
      final result = await resolver.resolveForCategory('cat-missing');

      verify(() => mockDb.getCategoryById('cat-missing')).called(1);
      verifyNever(() => mockAiConfigRepo.getConfigById(any()));
      expect(result, isNull);
    });

    // The fallback walk needs the task's category, not just its profileId:
    // a task created before its category had a default profile carries no
    // profileId of its own.
    group('taskCategoryLookup via resolveAutomationFallbacks', () {
      JournalEntity taskWith({String? categoryId, String? profileId}) {
        return JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: categoryId,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024),
              utcOffset: 0,
            ),
            title: 'Task',
            statusHistory: const [],
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            estimate: Duration.zero,
            profileId: profileId,
          ),
        );
      }

      test('walks the task profile and then the category default', () async {
        when(() => mockDb.journalEntityById('task-1')).thenAnswer(
          (_) async => taskWith(categoryId: 'cat-1', profileId: 'profile-task'),
        );
        when(
          () => mockDb.getCategoryById('cat-1'),
        ).thenAnswer(
          (_) async => makeCategory(defaultProfileId: 'profile-cat'),
        );

        final container = createContainer();
        final resolver = container.read(profileAutomationResolverProvider);
        // Both profile lookups return null (mockAiConfigRepo default), so the
        // walk yields nothing — what matters is which ids it reached for.
        final result = await resolver.resolveAutomationFallbacks('task-1');

        expect(result, isEmpty);
        verify(() => mockAiConfigRepo.getConfigById('profile-task')).called(1);
        verify(() => mockAiConfigRepo.getConfigById('profile-cat')).called(1);
      });

      test('reaches the category default with no task profile', () async {
        when(
          () => mockDb.journalEntityById('task-1'),
        ).thenAnswer((_) async => taskWith(categoryId: 'cat-1'));
        when(
          () => mockDb.getCategoryById('cat-1'),
        ).thenAnswer(
          (_) async => makeCategory(defaultProfileId: 'profile-cat'),
        );

        final container = createContainer();
        final resolver = container.read(profileAutomationResolverProvider);
        await resolver.resolveAutomationFallbacks('task-1');

        verify(() => mockAiConfigRepo.getConfigById('profile-cat')).called(1);
      });

      test('reads no category when the entry is missing', () async {
        when(
          () => mockDb.journalEntityById('task-gone'),
        ).thenAnswer((_) async => null);

        final container = createContainer();
        final resolver = container.read(profileAutomationResolverProvider);
        final result = await resolver.resolveAutomationFallbacks('task-gone');

        expect(result, isEmpty);
        verifyNever(() => mockDb.getCategoryById(any()));
      });
    });

    // The gate the service applies before any automation: the entry's
    // category must have automatic inference switched on.
    group('categoryAutomationLookup', () {
      JournalEntity taskEntity({String? categoryId}) {
        return JournalEntity.task(
          meta: Metadata(
            id: 'entry-1',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: categoryId,
          ),
          data: TaskData(
            status: taskStatusFromString(''),
            title: 'Test',
            statusHistory: const [],
            dateTo: DateTime(2024),
            dateFrom: DateTime(2024),
            estimate: Duration.zero,
          ),
        );
      }

      Future<bool> lookupFor({
        required JournalEntity? entity,
        CategoryDefinition? category,
      }) async {
        when(
          () => mockDb.journalEntityById('entry-1'),
        ).thenAnswer((_) async => entity);
        when(
          () => mockDb.getCategoryById(any()),
        ).thenAnswer((_) async => category);

        final container = createContainer();
        final service = container.read(profileAutomationServiceProvider);
        // The lookup is private to the service; exercise it through the one
        // public entry point that consults it and nothing else.
        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => const <AiConfig>[]);
        return service.hasAutomatedSkillType(
          taskId: 'entry-1',
          skillType: SkillType.imageAnalysis,
        );
      }

      test('denies when the entry has no category', () async {
        final allowed = await lookupFor(
          entity: taskEntity(),
        );

        expect(allowed, isFalse);
        verifyNever(() => mockDb.getCategoryById(any()));
      });

      test('denies when the category never opted in', () async {
        final allowed = await lookupFor(
          entity: taskEntity(categoryId: 'cat-1'),
          category: makeCategory(),
        );

        expect(allowed, isFalse);
      });

      test('denies when the entry is missing entirely', () async {
        final allowed = await lookupFor(entity: null);

        expect(allowed, isFalse);
      });
    });

    /// Decides whether the category settings form shows the automatic-
    /// inference switch at all. It must answer yes for both ways automation
    /// can happen, or the fallback path would run with no visible control.
    group('categoryAutomationAvailableProvider', () {
      AiConfigInferenceProfile profileWith({required bool automated}) {
        return AiTestDataFactory.createTestProfile(id: 'profile-1').copyWith(
          skillAssignments: [
            SkillAssignment(skillId: 'skill-transcribe', automate: automated),
          ],
        );
      }

      /// A configured speech-to-text model plus its provider — the state in
      /// which the direct transcription fallback could run.
      void stubFallbackAvailable({required bool available}) {
        when(
          () => mockAiConfigRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'stt-model',
              inferenceProviderId: 'provider-1',
              inputModalities: available
                  ? const [Modality.audio]
                  : const [Modality.text],
              // Spelled out even though it matches the default: audio-in /
              // text-out is exactly what makes this a speech-to-text row.
              // ignore: avoid_redundant_argument_values
              outputModalities: const [Modality.text],
            ),
          ],
        );
        when(() => mockAiConfigRepo.getConfigById('provider-1')).thenAnswer(
          (_) async => AiTestDataFactory.createTestProvider(id: 'provider-1'),
        );
      }

      Future<bool> availableFor(String? profileId) async {
        final container = createContainer();
        return container.read(
          categoryAutomationAvailableProvider(profileId).future,
        );
      }

      test(
        'true when the selected profile carries an automated skill',
        () async {
          when(
            () => mockAiConfigRepo.getConfigById('profile-1'),
          ).thenAnswer((_) async => profileWith(automated: true));
          stubFallbackAvailable(available: false);

          expect(await availableFor('profile-1'), isTrue);
        },
      );

      // A profile whose skills are all manual still leaves the fallback, so
      // the switch stays offered rather than silently disappearing.
      test(
        'falls through to the direct fallback for a manual profile',
        () async {
          when(
            () => mockAiConfigRepo.getConfigById('profile-1'),
          ).thenAnswer((_) async => profileWith(automated: false));
          stubFallbackAvailable(available: true);

          expect(await availableFor('profile-1'), isTrue);
        },
      );

      // The mobile case: no profile selectable, but an MLX Audio model
      // configured. Hiding the switch here would strand the fallback.
      test('true from the fallback when the category has no profile', () async {
        stubFallbackAvailable(available: true);

        expect(await availableFor(null), isTrue);
      });

      test('false when nothing can be automated', () async {
        stubFallbackAvailable(available: false);

        expect(await availableFor(null), isFalse);
      });
    });
  });
}
