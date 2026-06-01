import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedProjectActivityAffectedSlot {
  empty,
  directProjectToken,
  taskToken,
  mixedTokens,
}

enum _GeneratedProjectActivityLinkSlot {
  none,
  single,
  newerSecond,
  tieBreakById,
}

enum _GeneratedProjectActivityStateSlot {
  missing,
  activeNoPending,
  activePastPending,
  activeAtNowPending,
  activeFuturePending,
  deleted,
}

enum _GeneratedProjectActivityFailureSlot {
  none,
  linksThrow,
  stateThrow,
  upsertThrow,
}

final _generatedProjectActivityNow = DateTime(2026, 4, 3, 15, 45);

class _GeneratedProjectActivitySpec {
  const _GeneratedProjectActivitySpec({
    required this.linkSlot,
    required this.stateSlot,
    required this.failureSlot,
  });

  final _GeneratedProjectActivityLinkSlot linkSlot;
  final _GeneratedProjectActivityStateSlot stateSlot;
  final _GeneratedProjectActivityFailureSlot failureSlot;

  bool get hasPrimaryLink => linkSlot != _GeneratedProjectActivityLinkSlot.none;

  bool get canLoadState =>
      hasPrimaryLink &&
      failureSlot != _GeneratedProjectActivityFailureSlot.linksThrow &&
      failureSlot != _GeneratedProjectActivityFailureSlot.stateThrow;

  bool get hasWritableState {
    return canLoadState &&
        switch (stateSlot) {
          _GeneratedProjectActivityStateSlot.activeNoPending ||
          _GeneratedProjectActivityStateSlot.activePastPending => true,
          _GeneratedProjectActivityStateSlot.missing ||
          _GeneratedProjectActivityStateSlot.activeAtNowPending ||
          _GeneratedProjectActivityStateSlot.activeFuturePending ||
          _GeneratedProjectActivityStateSlot.deleted => false,
        };
  }

  bool get expectsUiNotification =>
      hasWritableState &&
      failureSlot != _GeneratedProjectActivityFailureSlot.upsertThrow;

  String projectId(int index) => 'generated-project-$index';

  String primaryAgentId(int index) {
    return switch (linkSlot) {
      _GeneratedProjectActivityLinkSlot.none => 'missing-agent-$index',
      _GeneratedProjectActivityLinkSlot.single => 'generated-agent-$index-a',
      _GeneratedProjectActivityLinkSlot.newerSecond =>
        'generated-agent-$index-new',
      _GeneratedProjectActivityLinkSlot.tieBreakById =>
        'generated-agent-$index-z',
    };
  }

  List<AgentLink> links(int index) {
    final projectId = this.projectId(index);
    return switch (linkSlot) {
      _GeneratedProjectActivityLinkSlot.none => const <AgentLink>[],
      _GeneratedProjectActivityLinkSlot.single => [
        _agentProjectLink(
          id: 'generated-link-$index-a',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
      ],
      _GeneratedProjectActivityLinkSlot.newerSecond => [
        _agentProjectLink(
          id: 'generated-link-$index-old',
          fromId: 'generated-agent-$index-old',
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
        _agentProjectLink(
          id: 'generated-link-$index-new',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4, 2),
        ),
      ],
      _GeneratedProjectActivityLinkSlot.tieBreakById => [
        _agentProjectLink(
          id: 'generated-link-$index-a',
          fromId: 'generated-agent-$index-a',
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
        _agentProjectLink(
          id: 'generated-link-$index-z',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
      ],
    };
  }

  AgentStateEntity? state(int index) {
    if (stateSlot == _GeneratedProjectActivityStateSlot.missing) return null;

    final pendingProjectActivityAt = switch (stateSlot) {
      _GeneratedProjectActivityStateSlot.activePastPending =>
        _generatedProjectActivityNow.subtract(const Duration(minutes: 5)),
      _GeneratedProjectActivityStateSlot.activeAtNowPending =>
        _generatedProjectActivityNow,
      _GeneratedProjectActivityStateSlot.activeFuturePending =>
        _generatedProjectActivityNow.add(const Duration(minutes: 5)),
      _GeneratedProjectActivityStateSlot.missing ||
      _GeneratedProjectActivityStateSlot.activeNoPending ||
      _GeneratedProjectActivityStateSlot.deleted => null,
    };

    final state = makeTestState(
      id: 'generated-state-$index',
      agentId: primaryAgentId(index),
      revision: index + 1,
      slots: AgentSlots(
        activeProjectId: projectId(index),
        pendingProjectActivityAt: pendingProjectActivityAt,
      ),
    );

    if (stateSlot == _GeneratedProjectActivityStateSlot.deleted) {
      return state.copyWith(deletedAt: DateTime(2026, 4, 2));
    }
    return state;
  }

  @override
  String toString() {
    return '_GeneratedProjectActivitySpec('
        'linkSlot: $linkSlot, stateSlot: $stateSlot, '
        'failureSlot: $failureSlot)';
  }
}

class _GeneratedProjectActivityScenario {
  const _GeneratedProjectActivityScenario({
    required this.affectedSlot,
    required this.specs,
  });

  final _GeneratedProjectActivityAffectedSlot affectedSlot;
  final List<_GeneratedProjectActivitySpec> specs;

  Set<String> get affectedIds {
    return switch (affectedSlot) {
      _GeneratedProjectActivityAffectedSlot.empty => const <String>{},
      _GeneratedProjectActivityAffectedSlot.directProjectToken =>
        specs.isEmpty ? {'project-unmapped'} : {'generated-project-0'},
      _GeneratedProjectActivityAffectedSlot.taskToken => {'generated-task-1'},
      _GeneratedProjectActivityAffectedSlot.mixedTokens => {
        'generated-task-1',
        'generated-project-0',
        projectNotification,
      },
    };
  }

  Set<String> get resolvedProjectIds {
    return switch (affectedSlot) {
      _GeneratedProjectActivityAffectedSlot.empty => const <String>{},
      _GeneratedProjectActivityAffectedSlot.directProjectToken => {
        if (specs.isEmpty) 'project-unmapped' else specs[0].projectId(0),
      },
      _GeneratedProjectActivityAffectedSlot.taskToken => {
        if (specs.length > 1) specs[1].projectId(1) else 'generated-project-1',
      },
      _GeneratedProjectActivityAffectedSlot.mixedTokens => {
        if (specs.isEmpty) 'generated-project-0' else specs[0].projectId(0),
        if (specs.length > 1) specs[1].projectId(1) else 'generated-project-1',
      },
    };
  }

  int indexForAgentId(String agentId) {
    return Iterable<int>.generate(specs.length).firstWhere(
      (index) => specs[index].primaryAgentId(index) == agentId,
      orElse: () => -1,
    );
  }

  @override
  String toString() {
    return '_GeneratedProjectActivityScenario('
        'affectedSlot: $affectedSlot, specs: $specs)';
  }
}

AgentLink _agentProjectLink({
  required String id,
  required String fromId,
  required String toId,
  required DateTime createdAt,
}) {
  return AgentLink.agentProject(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: createdAt,
    updatedAt: createdAt,
    vectorClock: null,
  );
}

extension _AnyGeneratedProjectActivityScenario on glados.Any {
  glados.Generator<_GeneratedProjectActivityAffectedSlot>
  get projectActivityAffectedSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedProjectActivityAffectedSlot.values);

  glados.Generator<_GeneratedProjectActivityLinkSlot>
  get projectActivityLinkSlot =>
      glados.AnyUtils(this).choose(_GeneratedProjectActivityLinkSlot.values);

  glados.Generator<_GeneratedProjectActivityStateSlot>
  get projectActivityStateSlot =>
      glados.AnyUtils(this).choose(_GeneratedProjectActivityStateSlot.values);

  glados.Generator<_GeneratedProjectActivityFailureSlot>
  get projectActivityFailureSlot =>
      glados.AnyUtils(this).choose(_GeneratedProjectActivityFailureSlot.values);

  glados.Generator<_GeneratedProjectActivitySpec> get projectActivitySpec =>
      glados.CombinableAny(this).combine3(
        projectActivityLinkSlot,
        projectActivityStateSlot,
        projectActivityFailureSlot,
        (
          _GeneratedProjectActivityLinkSlot linkSlot,
          _GeneratedProjectActivityStateSlot stateSlot,
          _GeneratedProjectActivityFailureSlot failureSlot,
        ) => _GeneratedProjectActivitySpec(
          linkSlot: linkSlot,
          stateSlot: stateSlot,
          failureSlot: failureSlot,
        ),
      );

  glados.Generator<_GeneratedProjectActivityScenario>
  get projectActivityScenario => glados.CombinableAny(this).combine2(
    projectActivityAffectedSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 5, projectActivitySpec),
    (
      _GeneratedProjectActivityAffectedSlot affectedSlot,
      List<_GeneratedProjectActivitySpec> specs,
    ) => _GeneratedProjectActivityScenario(
      affectedSlot: affectedSlot,
      specs: specs,
    ),
  );
}

class _GeneratedProjectActivityBench {
  factory _GeneratedProjectActivityBench(
    _GeneratedProjectActivityScenario scenario,
  ) {
    final notifications = MockUpdateNotifications();
    final repository = MockAgentRepository();
    final projectRepository = MockProjectRepository();
    final syncService = MockAgentSyncService();
    final controller = StreamController<Set<String>>.broadcast();
    final writtenStates = <AgentStateEntity>[];
    final uiNotifications = <Set<String>>[];

    when(
      () => notifications.localUpdateStream,
    ).thenAnswer((_) => controller.stream);
    when(() => notifications.notifyUiOnly(any())).thenAnswer((invocation) {
      uiNotifications.add(
        Set<String>.from(invocation.positionalArguments.single as Set),
      );
    });
    when(
      () => projectRepository.resolveAffectedProjectIds(any()),
    ).thenAnswer((_) async => scenario.resolvedProjectIds);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentStateEntity;
      writtenStates.add(entity);
      final index = scenario.indexForAgentId(entity.agentId);
      if (index >= 0 &&
          scenario.specs[index].failureSlot ==
              _GeneratedProjectActivityFailureSlot.upsertThrow) {
        throw StateError('generated upsert failure');
      }
    });
    when(
      () => repository.getLinksTo(
        any(),
        type: AgentLinkTypes.agentProject,
      ),
    ).thenAnswer((_) async => const <AgentLink>[]);
    when(() => repository.getAgentState(any())).thenAnswer((_) async => null);

    for (final (index, spec) in scenario.specs.indexed) {
      final projectId = spec.projectId(index);
      when(
        () => repository.getLinksTo(
          projectId,
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async {
        if (spec.failureSlot ==
            _GeneratedProjectActivityFailureSlot.linksThrow) {
          throw StateError('generated links failure');
        }
        return spec.links(index);
      });

      final agentId = spec.primaryAgentId(index);
      when(() => repository.getAgentState(agentId)).thenAnswer((_) async {
        if (spec.failureSlot ==
            _GeneratedProjectActivityFailureSlot.stateThrow) {
          throw StateError('generated state failure');
        }
        return spec.state(index);
      });
    }

    final monitor = ProjectActivityMonitor(
      notifications: notifications,
      agentRepository: repository,
      projectRepository: projectRepository,
      syncService: syncService,
      clock: Clock.fixed(_generatedProjectActivityNow),
    );

    return _GeneratedProjectActivityBench._(
      notifications: notifications,
      repository: repository,
      projectRepository: projectRepository,
      syncService: syncService,
      controller: controller,
      monitor: monitor,
      writtenStates: writtenStates,
      uiNotifications: uiNotifications,
    );
  }

  _GeneratedProjectActivityBench._({
    required this.notifications,
    required this.repository,
    required this.projectRepository,
    required this.syncService,
    required this.controller,
    required this.monitor,
    required this.writtenStates,
    required this.uiNotifications,
  });

  final MockUpdateNotifications notifications;
  final MockAgentRepository repository;
  final MockProjectRepository projectRepository;
  final MockAgentSyncService syncService;
  final StreamController<Set<String>> controller;
  final ProjectActivityMonitor monitor;
  final List<AgentStateEntity> writtenStates;
  final List<Set<String>> uiNotifications;

  Future<void> dispose() async {
    await monitor.stop();
    await controller.close();
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 3, 22, 14, 5);
  late MockUpdateNotifications notifications;
  late MockAgentRepository repository;
  late MockProjectRepository projectRepository;
  late MockAgentSyncService syncService;
  late StreamController<Set<String>> updateController;
  late ProjectActivityMonitor monitor;

  setUp(() {
    notifications = MockUpdateNotifications();
    repository = MockAgentRepository();
    projectRepository = MockProjectRepository();
    syncService = MockAgentSyncService();
    updateController = StreamController<Set<String>>.broadcast();

    when(() => notifications.localUpdateStream).thenAnswer(
      (_) => updateController.stream,
    );
    when(
      () => notifications.notify(
        any(),
        fromSync: any(named: 'fromSync'),
      ),
    ).thenReturn(null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => projectRepository.resolveAffectedProjectIds(any()),
    ).thenAnswer((invocation) async {
      final affectedIds = invocation.positionalArguments.first as Set<String>;
      return affectedIds.where((id) => id.startsWith('project-')).toSet();
    });

    monitor = ProjectActivityMonitor(
      notifications: notifications,
      agentRepository: repository,
      projectRepository: projectRepository,
      syncService: syncService,
      clock: Clock.fixed(now),
    );
  });

  tearDown(() async {
    await monitor.stop();
    await updateController.close();
  });

  group('ProjectActivityMonitor', () {
    glados.Glados(
      glados.any.projectActivityScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated project activity marking semantics', (
      scenario,
    ) async {
      final bench = _GeneratedProjectActivityBench(scenario);

      try {
        bench.monitor.start();
        bench.controller.add(scenario.affectedIds);
        await pumpEventQueue(times: 4);

        final expectedWrittenAgentIds = <String>[
          for (var i = 0; i < scenario.specs.length; i++)
            if (scenario.resolvedProjectIds.contains(
                  scenario.specs[i].projectId(i),
                ) &&
                scenario.specs[i].hasWritableState)
              scenario.specs[i].primaryAgentId(i),
        ];
        expect(
          bench.writtenStates.map((state) => state.agentId).toList(),
          expectedWrittenAgentIds,
          reason: '$scenario',
        );

        for (final state in bench.writtenStates) {
          final index = scenario.indexForAgentId(state.agentId);
          expect(index, isNonNegative, reason: '$scenario');
          final original = scenario.specs[index].state(index)!;
          expect(
            state.slots.activeProjectId,
            original.slots.activeProjectId,
            reason: '$scenario',
          );
          expect(
            state.slots.pendingProjectActivityAt,
            _generatedProjectActivityNow,
            reason: '$scenario',
          );
          expect(state.updatedAt, _generatedProjectActivityNow);
        }

        final expectedUiNotifications = <Set<String>>[
          for (var i = 0; i < scenario.specs.length; i++)
            if (scenario.resolvedProjectIds.contains(
                  scenario.specs[i].projectId(i),
                ) &&
                scenario.specs[i].expectsUiNotification)
              {scenario.specs[i].primaryAgentId(i), agentNotification},
        ];
        expect(
          bench.uiNotifications,
          expectedUiNotifications,
          reason: '$scenario',
        );

        if (scenario.affectedIds.isEmpty) {
          verifyNever(
            () => bench.projectRepository.resolveAffectedProjectIds(any()),
          );
        } else {
          verify(
            () => bench.projectRepository.resolveAffectedProjectIds(
              scenario.affectedIds,
            ),
          ).called(1);
        }
      } finally {
        await bench.dispose();
      }
    }, tags: 'glados');

    test('marks pending activity for linked project agents', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final state = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.activeProjectId, 'project-1');
      expect(captured.slots.pendingProjectActivityAt, now);

      verify(
        () => notifications.notifyUiOnly({'agent-1', agentNotification}),
      ).called(1);
    });

    test('resolves project IDs from updated task IDs', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final state = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      when(
        () => projectRepository.resolveAffectedProjectIds({'task-1'}),
      ).thenAnswer((_) async => {'project-1'});
      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'task-1'});
      await pumpEventQueue(times: 2);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.pendingProjectActivityAt, now);
    });

    test('skips deleted agents', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final deletedState = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      ).copyWith(deletedAt: DateTime(2026, 3, 20));

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => deletedState);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('skips when agent state is null', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => null);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('skips when pending activity is already set in the future', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final futureActivity = now.add(const Duration(hours: 1));
      final state = makeTestState(
        agentId: 'agent-1',
        slots: AgentSlots(
          activeProjectId: 'project-1',
          pendingProjectActivityAt: futureActivity,
        ),
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('handles errors gracefully without domainLogger', () async {
      when(
        () => repository.getLinksTo(
          'project-err',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenThrow(Exception('DB down'));

      monitor.start();

      updateController.add({'project-err'});
      await pumpEventQueue(times: 2);

      // Should not crash — error is caught and logged via developer.log
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('handles errors gracefully with domainLogger', () async {
      final mockLogger = MockDomainLogger();
      when(
        () => mockLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final loggedMonitor = ProjectActivityMonitor(
        notifications: notifications,
        agentRepository: repository,
        projectRepository: projectRepository,
        syncService: syncService,
        domainLogger: mockLogger,
        clock: Clock.fixed(now),
      );

      when(
        () => repository.getLinksTo(
          'project-err2',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenThrow(Exception('DB down'));

      loggedMonitor.start();

      updateController.add({'project-err2'});
      await pumpEventQueue(times: 2);

      verify(
        () => mockLogger.error(
          any(),
          any(),
          message: any(
            named: 'message',
            that: contains('failed to mark project activity'),
          ),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      await loggedMonitor.stop();
    });

    test('ignores empty affected IDs batch', () async {
      monitor.start();

      updateController.add(<String>{});
      await pumpEventQueue();

      verifyNever(
        () => projectRepository.resolveAffectedProjectIds(any()),
      );
      verifyNever(
        () => repository.getLinksTo(
          any(),
          type: any(named: 'type'),
        ),
      );
    });

    test('ignores affected ids that do not map to project agents', () async {
      when(
        () =>
            projectRepository.resolveAffectedProjectIds({projectNotification}),
      ).thenAnswer((_) async => {});

      monitor.start();

      updateController.add({projectNotification});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
      verifyNever(
        () => notifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });
  });
}
