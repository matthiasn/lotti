import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/service/project_lifecycle_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  final project = makeTestProject(id: 'project-1');
  final first = makeTestIdentity(agentId: 'agent-1');
  final second = makeTestIdentity(agentId: 'agent-2');
  late MockProjectRepository repository;
  late MockProjectAgentService projectAgents;
  late MockAgentService agents;
  late ProjectAgentMutationCoordinator coordinator;
  late ProjectLifecycleService service;

  setUp(() {
    repository = MockProjectRepository();
    projectAgents = MockProjectAgentService();
    agents = MockAgentService();
    coordinator = ProjectAgentMutationCoordinator();
    service = ProjectLifecycleService(
      projectRepository: repository,
      projectAgentService: projectAgents,
      agentService: agents,
      mutationCoordinator: coordinator,
    );
    when(
      () => projectAgents.getProjectAgentsForProject(project.id),
    ).thenAnswer((_) async => [first, second]);
    when(projectAgents.restoreSubscriptions).thenAnswer((_) async {});
    when(() => agents.abortRunningWake(any())).thenReturn(true);
    when(() => agents.waitForAgentExecutors(any())).thenAnswer((_) async {});
    when(() => agents.destroyAgent(any())).thenAnswer((_) async => true);
    when(() => agents.getAgent(any())).thenAnswer((_) async => null);
    for (final lifecycle in AgentLifecycle.values) {
      when(
        () => agents.restoreAgentLifecycle(any(), lifecycle),
      ).thenAnswer((_) async => true);
    }
    when(
      () => repository.getProjectById(project.id),
    ).thenAnswer((_) async => project);
    when(
      () => repository.deleteProject(any(), deletedAt: any(named: 'deletedAt')),
    ).thenAnswer((_) async => true);
  });

  void failDelete() {
    when(
      () => repository.deleteProject(any(), deletedAt: any(named: 'deletedAt')),
    ).thenAnswer((_) async => false);
  }

  void verifyNoProjectWrite() {
    verifyNever(
      () => repository.deleteProject(any(), deletedAt: any(named: 'deletedAt')),
    );
  }

  test(
    'provider retires all agents before deleting the latest project',
    () async {
      final updated = project.copyWith(
        data: project.data.copyWith(title: 'Latest title'),
      );
      when(
        () => repository.getProjectById(project.id),
      ).thenAnswer((_) async => updated);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          projectAgentServiceProvider.overrideWithValue(projectAgents),
          agentServiceProvider.overrideWithValue(agents),
          projectAgentMutationCoordinatorProvider.overrideWithValue(
            coordinator,
          ),
        ],
      );
      addTearDown(container.dispose);
      final now = DateTime(2026, 9, 4);
      await withClock(Clock.fixed(now), () async {
        expect(
          await container
              .read(projectLifecycleServiceProvider)
              .deleteProject(
                project.id,
              ),
          isTrue,
        );
      });
      verifyInOrder([
        () => agents.abortRunningWake(first.agentId),
        () => agents.destroyAgent(first.agentId),
        () => agents.abortRunningWake(second.agentId),
        () => agents.destroyAgent(second.agentId),
        () => repository.deleteProject(updated, deletedAt: now),
      ]);
      verifyNever(projectAgents.restoreSubscriptions);
    },
  );

  test('waits for provisioning before resolving agents', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final provisioning = coordinator.run(project.id, () async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final deletion = service.deleteProject(project.id);
    await Future<void>.value();
    verifyZeroInteractions(projectAgents);
    release.complete();
    await provisioning;
    expect(await deletion, isTrue);
  });

  test(
    'does not tombstone the project until retired executors settle',
    () async {
      final finished = Completer<void>();
      when(
        () => agents.waitForAgentExecutors(first.agentId),
      ).thenAnswer((_) => finished.future);
      final deletion = service.deleteProject(project.id);
      await pumpEventQueue(times: 3);
      verify(() => agents.destroyAgent(first.agentId)).called(1);
      verifyNoProjectWrite();
      finished.complete();
      expect(await deletion, isTrue);
      verify(() => agents.waitForAgentExecutors(first.agentId)).called(1);
      verify(() => agents.waitForAgentExecutors(second.agentId)).called(1);
    },
  );

  test('agent lookup failure does not delete the project', () async {
    when(
      () => projectAgents.getProjectAgentsForProject(project.id),
    ).thenThrow(StateError('lookup failed'));
    expect(await service.deleteProject(project.id), isFalse);
    verifyZeroInteractions(agents);
    verifyNoProjectWrite();
  });

  test('missing agents and projects are already deleted', () async {
    when(() => agents.destroyAgent(any())).thenAnswer((_) async => false);
    when(
      () => repository.getProjectById(project.id),
    ).thenAnswer((_) async => null);
    expect(await service.deleteProject(project.id), isTrue);
    verifyNoProjectWrite();
    verifyNever(projectAgents.restoreSubscriptions);
  });

  for (final committed in [false, true]) {
    test(
      'retirement failure compensates committed agents ($committed)',
      () async {
        when(() => agents.destroyAgent(second.agentId)).thenThrow(
          StateError('retirement failed'),
        );
        when(() => agents.getAgent(second.agentId)).thenAnswer(
          (_) async => committed
              ? second.copyWith(lifecycle: AgentLifecycle.destroyed)
              : second,
        );
        expect(await service.deleteProject(project.id), isFalse);
        verifyNoProjectWrite();
        verify(
          () => agents.restoreAgentLifecycle(first.agentId, first.lifecycle),
        ).called(1);
        if (committed) {
          verify(
            () =>
                agents.restoreAgentLifecycle(second.agentId, second.lifecycle),
          ).called(1);
        } else {
          verifyNever(
            () =>
                agents.restoreAgentLifecycle(second.agentId, second.lifecycle),
          );
        }
        verify(projectAgents.restoreSubscriptions).called(1);
      },
    );
  }

  test('verification failure still restores earlier retired agents', () async {
    when(
      () => agents.destroyAgent(second.agentId),
    ).thenThrow(StateError('fail'));
    when(() => agents.getAgent(second.agentId)).thenThrow(StateError('read'));
    expect(await service.deleteProject(project.id), isFalse);
    verifyNoProjectWrite();
    verify(
      () => agents.restoreAgentLifecycle(first.agentId, first.lifecycle),
    ).called(1);
    verify(projectAgents.restoreSubscriptions).called(1);
  });

  for (final lifecycle in [AgentLifecycle.active, AgentLifecycle.dormant]) {
    test('failed deletion restores exact $lifecycle lifecycle', () async {
      final identity = first.copyWith(lifecycle: lifecycle);
      when(
        () => projectAgents.getProjectAgentsForProject(project.id),
      ).thenAnswer((_) async => [identity]);
      failDelete();
      expect(await service.deleteProject(project.id), isFalse);
      verify(
        () => agents.restoreAgentLifecycle(identity.agentId, lifecycle),
      ).called(1);
      if (lifecycle == AgentLifecycle.active) {
        verify(projectAgents.restoreSubscriptions).called(1);
      } else {
        verifyNever(projectAgents.restoreSubscriptions);
      }
    });
  }

  for (final tombstoneCommitted in [false, true]) {
    test(
      'verifies throwing deletion before recovery ($tombstoneCommitted)',
      () async {
        var attempted = false;
        when(
          () => repository.deleteProject(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async {
          attempted = true;
          throw StateError('delete failed');
        });
        when(() => repository.getProjectById(project.id)).thenAnswer(
          (_) async => attempted && tombstoneCommitted ? null : project,
        );
        expect(await service.deleteProject(project.id), tombstoneCommitted);
        if (tombstoneCommitted) {
          verifyNever(projectAgents.restoreSubscriptions);
        } else {
          verify(projectAgents.restoreSubscriptions).called(1);
        }
      },
    );
  }

  test('unverifiable deletion restores agents', () async {
    when(
      () => repository.getProjectById(project.id),
    ).thenThrow(StateError('read failed'));
    expect(await service.deleteProject(project.id), isFalse);
    verify(projectAgents.restoreSubscriptions).called(1);
  });

  for (final committed in [false, true]) {
    test('verifies a throwing lifecycle restore ($committed)', () async {
      when(
        () => projectAgents.getProjectAgentsForProject(project.id),
      ).thenAnswer((_) async => [first]);
      failDelete();
      when(
        () => agents.restoreAgentLifecycle(first.agentId, first.lifecycle),
      ).thenThrow(StateError('restore failed'));
      when(() => agents.getAgent(first.agentId)).thenAnswer(
        (_) async => committed ? first : null,
      );
      expect(await service.deleteProject(project.id), isFalse);
      if (committed) {
        verify(projectAgents.restoreSubscriptions).called(1);
      } else {
        verifyNever(projectAgents.restoreSubscriptions);
      }
    });
  }

  for (final throws in [false, true]) {
    test(
      'continues recovery after one agent cannot be restored ($throws)',
      () async {
        failDelete();
        when(
          () => agents.restoreAgentLifecycle(first.agentId, first.lifecycle),
        ).thenAnswer((_) async {
          if (throws) throw StateError('restore failed');
          return false;
        });
        when(
          () => agents.getAgent(first.agentId),
        ).thenThrow(StateError('read'));
        expect(await service.deleteProject(project.id), isFalse);
        verify(
          () => agents.restoreAgentLifecycle(second.agentId, second.lifecycle),
        ).called(1);
        verify(projectAgents.restoreSubscriptions).called(1);
      },
    );
  }

  test('subscription failure does not mask the deletion result', () async {
    failDelete();
    when(projectAgents.restoreSubscriptions).thenThrow(StateError('subscribe'));
    expect(await service.deleteProject(project.id), isFalse);
    verify(projectAgents.restoreSubscriptions).called(1);
  });
}
