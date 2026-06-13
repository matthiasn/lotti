import 'dart:async';

import 'package:clock/clock.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum GeneratedProjectActivityAffectedSlot {
  empty,
  directProjectToken,
  taskToken,
  mixedTokens,
}

enum GeneratedProjectActivityLinkSlot {
  none,
  single,
  newerSecond,
  tieBreakById,
}

enum GeneratedProjectActivityStateSlot {
  missing,
  activeNoPending,
  activePastPending,
  activeAtNowPending,
  activeFuturePending,
  deleted,
}

enum GeneratedProjectActivityFailureSlot {
  none,
  linksThrow,
  stateThrow,
  upsertThrow,
}

final hGeneratedProjectActivityNow = DateTime(2026, 4, 3, 15, 45);

class GeneratedProjectActivitySpec {
  const GeneratedProjectActivitySpec({
    required this.linkSlot,
    required this.stateSlot,
    required this.failureSlot,
  });

  final GeneratedProjectActivityLinkSlot linkSlot;
  final GeneratedProjectActivityStateSlot stateSlot;
  final GeneratedProjectActivityFailureSlot failureSlot;

  bool get hasPrimaryLink => linkSlot != GeneratedProjectActivityLinkSlot.none;

  bool get canLoadState =>
      hasPrimaryLink &&
      failureSlot != GeneratedProjectActivityFailureSlot.linksThrow &&
      failureSlot != GeneratedProjectActivityFailureSlot.stateThrow;

  bool get hasWritableState {
    return canLoadState &&
        switch (stateSlot) {
          GeneratedProjectActivityStateSlot.activeNoPending ||
          GeneratedProjectActivityStateSlot.activePastPending => true,
          GeneratedProjectActivityStateSlot.missing ||
          GeneratedProjectActivityStateSlot.activeAtNowPending ||
          GeneratedProjectActivityStateSlot.activeFuturePending ||
          GeneratedProjectActivityStateSlot.deleted => false,
        };
  }

  bool get expectsUiNotification =>
      hasWritableState &&
      failureSlot != GeneratedProjectActivityFailureSlot.upsertThrow;

  String projectId(int index) => 'generated-project-$index';

  String primaryAgentId(int index) {
    return switch (linkSlot) {
      GeneratedProjectActivityLinkSlot.none => 'missing-agent-$index',
      GeneratedProjectActivityLinkSlot.single => 'generated-agent-$index-a',
      GeneratedProjectActivityLinkSlot.newerSecond =>
        'generated-agent-$index-new',
      GeneratedProjectActivityLinkSlot.tieBreakById =>
        'generated-agent-$index-z',
    };
  }

  List<AgentLink> links(int index) {
    final projectId = this.projectId(index);
    return switch (linkSlot) {
      GeneratedProjectActivityLinkSlot.none => const <AgentLink>[],
      GeneratedProjectActivityLinkSlot.single => [
        hAgentProjectLink(
          id: 'generated-link-$index-a',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
      ],
      GeneratedProjectActivityLinkSlot.newerSecond => [
        hAgentProjectLink(
          id: 'generated-link-$index-old',
          fromId: 'generated-agent-$index-old',
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
        hAgentProjectLink(
          id: 'generated-link-$index-new',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4, 2),
        ),
      ],
      GeneratedProjectActivityLinkSlot.tieBreakById => [
        hAgentProjectLink(
          id: 'generated-link-$index-a',
          fromId: 'generated-agent-$index-a',
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
        hAgentProjectLink(
          id: 'generated-link-$index-z',
          fromId: primaryAgentId(index),
          toId: projectId,
          createdAt: DateTime(2026, 4),
        ),
      ],
    };
  }

  AgentStateEntity? state(int index) {
    if (stateSlot == GeneratedProjectActivityStateSlot.missing) return null;

    final pendingProjectActivityAt = switch (stateSlot) {
      GeneratedProjectActivityStateSlot.activePastPending =>
        hGeneratedProjectActivityNow.subtract(const Duration(minutes: 5)),
      GeneratedProjectActivityStateSlot.activeAtNowPending =>
        hGeneratedProjectActivityNow,
      GeneratedProjectActivityStateSlot.activeFuturePending =>
        hGeneratedProjectActivityNow.add(const Duration(minutes: 5)),
      GeneratedProjectActivityStateSlot.missing ||
      GeneratedProjectActivityStateSlot.activeNoPending ||
      GeneratedProjectActivityStateSlot.deleted => null,
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

    if (stateSlot == GeneratedProjectActivityStateSlot.deleted) {
      return state.copyWith(deletedAt: DateTime(2026, 4, 2));
    }
    return state;
  }

  @override
  String toString() {
    return 'GeneratedProjectActivitySpec('
        'linkSlot: $linkSlot, stateSlot: $stateSlot, '
        'failureSlot: $failureSlot)';
  }
}

class GeneratedProjectActivityScenario {
  const GeneratedProjectActivityScenario({
    required this.affectedSlot,
    required this.specs,
  });

  final GeneratedProjectActivityAffectedSlot affectedSlot;
  final List<GeneratedProjectActivitySpec> specs;

  Set<String> get affectedIds {
    return switch (affectedSlot) {
      GeneratedProjectActivityAffectedSlot.empty => const <String>{},
      GeneratedProjectActivityAffectedSlot.directProjectToken =>
        specs.isEmpty ? {'project-unmapped'} : {'generated-project-0'},
      GeneratedProjectActivityAffectedSlot.taskToken => {'generated-task-1'},
      GeneratedProjectActivityAffectedSlot.mixedTokens => {
        'generated-task-1',
        'generated-project-0',
        projectNotification,
      },
    };
  }

  Set<String> get resolvedProjectIds {
    return switch (affectedSlot) {
      GeneratedProjectActivityAffectedSlot.empty => const <String>{},
      GeneratedProjectActivityAffectedSlot.directProjectToken => {
        if (specs.isEmpty) 'project-unmapped' else specs[0].projectId(0),
      },
      GeneratedProjectActivityAffectedSlot.taskToken => {
        if (specs.length > 1) specs[1].projectId(1) else 'generated-project-1',
      },
      GeneratedProjectActivityAffectedSlot.mixedTokens => {
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
    return 'GeneratedProjectActivityScenario('
        'affectedSlot: $affectedSlot, specs: $specs)';
  }
}

AgentLink hAgentProjectLink({
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

extension AnyGeneratedProjectActivityScenario on glados.Any {
  glados.Generator<GeneratedProjectActivityAffectedSlot>
  get projectActivityAffectedSlot => glados.AnyUtils(
    this,
  ).choose(GeneratedProjectActivityAffectedSlot.values);

  glados.Generator<GeneratedProjectActivityLinkSlot>
  get projectActivityLinkSlot =>
      glados.AnyUtils(this).choose(GeneratedProjectActivityLinkSlot.values);

  glados.Generator<GeneratedProjectActivityStateSlot>
  get projectActivityStateSlot =>
      glados.AnyUtils(this).choose(GeneratedProjectActivityStateSlot.values);

  glados.Generator<GeneratedProjectActivityFailureSlot>
  get projectActivityFailureSlot =>
      glados.AnyUtils(this).choose(GeneratedProjectActivityFailureSlot.values);

  glados.Generator<GeneratedProjectActivitySpec> get projectActivitySpec =>
      glados.CombinableAny(this).combine3(
        projectActivityLinkSlot,
        projectActivityStateSlot,
        projectActivityFailureSlot,
        (
          GeneratedProjectActivityLinkSlot linkSlot,
          GeneratedProjectActivityStateSlot stateSlot,
          GeneratedProjectActivityFailureSlot failureSlot,
        ) => GeneratedProjectActivitySpec(
          linkSlot: linkSlot,
          stateSlot: stateSlot,
          failureSlot: failureSlot,
        ),
      );

  glados.Generator<GeneratedProjectActivityScenario>
  get projectActivityScenario => glados.CombinableAny(this).combine2(
    projectActivityAffectedSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 5, projectActivitySpec),
    (
      GeneratedProjectActivityAffectedSlot affectedSlot,
      List<GeneratedProjectActivitySpec> specs,
    ) => GeneratedProjectActivityScenario(
      affectedSlot: affectedSlot,
      specs: specs,
    ),
  );
}

class GeneratedProjectActivityBench {
  factory GeneratedProjectActivityBench(
    GeneratedProjectActivityScenario scenario,
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
              GeneratedProjectActivityFailureSlot.upsertThrow) {
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
            GeneratedProjectActivityFailureSlot.linksThrow) {
          throw StateError('generated links failure');
        }
        return spec.links(index);
      });

      final agentId = spec.primaryAgentId(index);
      when(() => repository.getAgentState(agentId)).thenAnswer((_) async {
        if (spec.failureSlot ==
            GeneratedProjectActivityFailureSlot.stateThrow) {
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
      clock: Clock.fixed(hGeneratedProjectActivityNow),
    );

    return GeneratedProjectActivityBench._(
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

  GeneratedProjectActivityBench._({
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
