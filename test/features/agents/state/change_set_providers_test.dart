import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
  });

  group('pendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for task', () async {
      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => null,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Keep a subscription alive to prevent premature disposal.
      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, __) {},
      );
      addTearDown(sub.close);

      final result =
          await container.read(pendingChangeSetsProvider('task-001').future);

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('fetches change sets from repo when agent exists', () async {
      final agent = makeTestIdentity();
      final changeSet = makeTestChangeSet(agentId: agent.agentId);

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).thenAnswer((_) async => [changeSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => agent,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, __) {},
      );
      addTearDown(sub.close);

      final result =
          await container.read(pendingChangeSetsProvider('task-001').future);

      expect(result, hasLength(1));
      expect(result.first, isA<ChangeSetEntity>());

      verify(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).called(1);
    });

    test('returns empty list when agent is not an identity entity', () async {
      // Return a non-agent variant (agentState) — mapOrNull returns null.
      final state = makeTestState();

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => state,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, __) {},
      );
      addTearDown(sub.close);

      final result =
          await container.read(pendingChangeSetsProvider('task-001').future);

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });
  });

  group('changeSetConfirmationServiceProvider', () {
    test('creates service with resolved dependencies', () {
      final mockSyncService = MockAgentSyncService();
      final mockJournalDb = MockJournalDb();
      final mockJournalRepository = MockJournalRepository();
      final mockChecklistRepository = MockChecklistRepository();
      final mockLabelsRepository = MockLabelsRepository();

      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          checklistRepositoryProvider
              .overrideWithValue(mockChecklistRepository),
          labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(changeSetConfirmationServiceProvider);

      expect(service, isA<ChangeSetConfirmationService>());
    });
  });
}
