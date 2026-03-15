import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/profile_automation_resolver.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

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
        ],
      );
    });

    tearDown(() => container.dispose());

    test('profileResolverProvider constructs a ProfileResolver', () {
      final resolver = container.read(profileResolverProvider);
      expect(resolver, isA<ProfileResolver>());
    });

    test(
      'profileAutomationResolverProvider constructs a '
      'ProfileAutomationResolver',
      () {
        final resolver = container.read(profileAutomationResolverProvider);
        expect(resolver, isA<ProfileAutomationResolver>());
      },
    );

    test(
      'profileAutomationServiceProvider constructs a '
      'ProfileAutomationService',
      () {
        final service = container.read(profileAutomationServiceProvider);
        expect(service, isA<ProfileAutomationService>());
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
          journalDbProvider.overrideWithValue(mockDb),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('resolveForTask falls back to task profileId when no agent',
        () async {
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
}
