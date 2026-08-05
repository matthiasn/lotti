import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'wake_orchestrator_test_helpers.dart';

export 'dart:async';

export 'package:clock/clock.dart';
export 'package:fake_async/fake_async.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:lotti/features/agents/database/agent_database.dart';
export 'package:lotti/features/agents/model/agent_config.dart';
export 'package:lotti/features/agents/model/agent_domain_entity.dart';
export 'package:lotti/features/agents/model/agent_enums.dart';
export 'package:lotti/features/agents/wake/wake_orchestrator.dart';
export 'package:lotti/features/agents/wake/wake_queue.dart';
export 'package:lotti/features/agents/wake/wake_runner.dart';
export 'package:lotti/features/sync/vector_clock.dart';
export 'package:lotti/services/db_notification.dart';
export 'package:lotti/services/domain_logging.dart';
export 'package:mocktail/mocktail.dart';

export '../../../helpers/fallbacks.dart';
export '../../../mocks/mocks.dart';
export '../test_utils.dart';
export 'wake_orchestrator_test_helpers.dart';

extension WakeQueueTestExtensions on WakeQueue {
  WakeJob? dequeue() => dequeueFirstWhere((_) => true);
}

enum GeneratedWakeReplacementSlot {
  none,
  tokenB,
  agentB,
  predicateFalse,
  expanded,
}

enum GeneratedWakeExtraSubscriptionSlot {
  none,
  sameAgentTrue,
  sameAgentFalse,
  otherAgentTrue,
  otherAgentFalse,
  agentCTrue,
}

enum GeneratedWakeRemovalSlot {
  none,
  agentA,
  agentB,
  agentC,
  agentAAndB,
}

enum GeneratedWakeBatchSlot {
  empty,
  entityA,
  entityB,
  shared,
  extraA,
  extraB,
  entityC,
  mixedAExtraA,
  sharedExtraB,
  noiseOnly,
  all,
}

enum GeneratedWakeBusySlot { none, agentA, agentB, agentC }

enum GeneratedWakeDrainAgentSlot { agentA, agentB, agentC }

enum GeneratedWakeDrainReasonSlot { subscription, reanalysis, scheduled }

enum GeneratedWakeDrainContentSlot {
  notAwaiting,
  awaitingNoContent,
  awaitingHasContent,
  awaitingNoTask,
  checkerThrows,
}

enum GeneratedWakeDrainInsertSlot { succeeds, throwsException }

enum GeneratedWakeDrainExecutorSlot {
  succeedsEmpty,
  succeedsWithMutation,
  throwsException,
}

enum GeneratedPendingWakeRestoreDueSlot {
  deepPast,
  justPast,
  exactlyNow,
  nearFuture,
  farFuture,
}

enum GeneratedPendingWakeRestorePriorThrottleSlot {
  none,
  earlierFuture,
  laterFuture,
}

enum GeneratedPostRunReasonSlot { subscription, reanalysis, scheduled }

enum GeneratedPostRunQueuedSlot { empty, direct, propagatedOnly }

enum GeneratedPostRunClockSlot { beforeMorning, afterMorning }

class GeneratedWakeSubscriptionSpec {
  const GeneratedWakeSubscriptionSpec({
    required this.id,
    required this.agentId,
    required this.matchEntityIds,
    required this.predicateAllows,
  });

  final String id;
  final String agentId;
  final Set<String> matchEntityIds;
  final bool predicateAllows;

  AgentSubscription toSubscription() {
    return AgentSubscription(
      id: id,
      agentId: agentId,
      matchEntityIds: matchEntityIds,
      predicate: predicateAllows ? null : (_) => false,
    );
  }
}

class ExpectedWakeJob {
  ExpectedWakeJob({
    required this.agentId,
    required this.reasonId,
    required Set<String> triggerTokens,
  }) : triggerTokens = Set<String>.from(triggerTokens);

  final String agentId;
  final String reasonId;
  final Set<String> triggerTokens;
}

class GeneratedWakeRoutingScenario {
  const GeneratedWakeRoutingScenario({
    required this.replacementSlot,
    required this.extraSubscriptionSlot,
    required this.removalSlot,
    required this.batchSlot,
    required this.busySlot,
  });

  final GeneratedWakeReplacementSlot replacementSlot;
  final GeneratedWakeExtraSubscriptionSlot extraSubscriptionSlot;
  final GeneratedWakeRemovalSlot removalSlot;
  final GeneratedWakeBatchSlot batchSlot;
  final GeneratedWakeBusySlot busySlot;

  List<GeneratedWakeSubscriptionSpec> get subscriptionSpecs {
    final specs = <GeneratedWakeSubscriptionSpec>[
      const GeneratedWakeSubscriptionSpec(
        id: 'sub-a',
        agentId: 'agent-a',
        matchEntityIds: {'entity-a', 'shared'},
        predicateAllows: true,
      ),
    ];

    final replacement = switch (replacementSlot) {
      GeneratedWakeReplacementSlot.none => null,
      GeneratedWakeReplacementSlot.tokenB =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-b'},
          predicateAllows: true,
        ),
      GeneratedWakeReplacementSlot.agentB =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-b',
          matchEntityIds: {'entity-b', 'shared'},
          predicateAllows: true,
        ),
      GeneratedWakeReplacementSlot.predicateFalse =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-a', 'entity-b'},
          predicateAllows: false,
        ),
      GeneratedWakeReplacementSlot.expanded =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-a', 'entity-b', 'shared'},
          predicateAllows: true,
        ),
    };
    if (replacement != null) specs.add(replacement);

    final extra = switch (extraSubscriptionSlot) {
      GeneratedWakeExtraSubscriptionSlot.none => null,
      GeneratedWakeExtraSubscriptionSlot.sameAgentTrue =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-extra-a', 'shared'},
          predicateAllows: true,
        ),
      GeneratedWakeExtraSubscriptionSlot.sameAgentFalse =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-extra-a', 'shared'},
          predicateAllows: false,
        ),
      GeneratedWakeExtraSubscriptionSlot.otherAgentTrue =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-b',
          agentId: 'agent-b',
          matchEntityIds: {'entity-extra-b', 'shared'},
          predicateAllows: true,
        ),
      GeneratedWakeExtraSubscriptionSlot.otherAgentFalse =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-b',
          agentId: 'agent-b',
          matchEntityIds: {'entity-extra-b', 'shared'},
          predicateAllows: false,
        ),
      GeneratedWakeExtraSubscriptionSlot.agentCTrue =>
        const GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-c',
          agentId: 'agent-c',
          matchEntityIds: {'entity-c'},
          predicateAllows: true,
        ),
    };
    if (extra != null) specs.add(extra);

    return specs;
  }

  Set<String> get removedAgentIds {
    return switch (removalSlot) {
      GeneratedWakeRemovalSlot.none => const <String>{},
      GeneratedWakeRemovalSlot.agentA => {'agent-a'},
      GeneratedWakeRemovalSlot.agentB => {'agent-b'},
      GeneratedWakeRemovalSlot.agentC => {'agent-c'},
      GeneratedWakeRemovalSlot.agentAAndB => {'agent-a', 'agent-b'},
    };
  }

  Set<String> get batchTokens {
    return switch (batchSlot) {
      GeneratedWakeBatchSlot.empty => const <String>{},
      GeneratedWakeBatchSlot.entityA => {'entity-a'},
      GeneratedWakeBatchSlot.entityB => {'entity-b'},
      GeneratedWakeBatchSlot.shared => {'shared'},
      GeneratedWakeBatchSlot.extraA => {'entity-extra-a'},
      GeneratedWakeBatchSlot.extraB => {'entity-extra-b'},
      GeneratedWakeBatchSlot.entityC => {'entity-c'},
      GeneratedWakeBatchSlot.mixedAExtraA => {
        'entity-a',
        'entity-extra-a',
        'noise',
      },
      GeneratedWakeBatchSlot.sharedExtraB => {
        'shared',
        'entity-extra-b',
        'noise',
      },
      GeneratedWakeBatchSlot.noiseOnly => {'noise'},
      GeneratedWakeBatchSlot.all => {
        'entity-a',
        'entity-b',
        'entity-extra-a',
        'entity-extra-b',
        'entity-c',
        'shared',
        'noise',
      },
    };
  }

  String? get busyAgentId {
    return switch (busySlot) {
      GeneratedWakeBusySlot.none => null,
      GeneratedWakeBusySlot.agentA => 'agent-a',
      GeneratedWakeBusySlot.agentB => 'agent-b',
      GeneratedWakeBusySlot.agentC => 'agent-c',
    };
  }

  List<GeneratedWakeSubscriptionSpec> get effectiveSubscriptions {
    final idsInOrder = <String>[];
    final byId = <String, GeneratedWakeSubscriptionSpec>{};
    for (final spec in subscriptionSpecs) {
      if (!byId.containsKey(spec.id)) idsInOrder.add(spec.id);
      byId[spec.id] = spec;
    }
    return [
      for (final id in idsInOrder)
        if (!removedAgentIds.contains(byId[id]!.agentId)) byId[id]!,
    ];
  }

  List<ExpectedWakeJob> get expectedJobs {
    final byAgent = <String, ExpectedWakeJob>{};
    final tokens = batchTokens;

    for (final spec in effectiveSubscriptions) {
      final matched = tokens.intersection(spec.matchEntityIds);
      if (matched.isEmpty || !spec.predicateAllows) continue;

      final existing = byAgent[spec.agentId];
      if (existing == null) {
        byAgent[spec.agentId] = ExpectedWakeJob(
          agentId: spec.agentId,
          reasonId: spec.id,
          triggerTokens: matched,
        );
      } else {
        existing.triggerTokens.addAll(matched);
      }
    }

    return byAgent.values.toList();
  }

  @override
  String toString() {
    return 'GeneratedWakeRoutingScenario('
        'replacementSlot: $replacementSlot, '
        'extraSubscriptionSlot: $extraSubscriptionSlot, '
        'removalSlot: $removalSlot, batchSlot: $batchSlot, '
        'busySlot: $busySlot)';
  }
}

String generatedWakeDrainAgentId(GeneratedWakeDrainAgentSlot slot) {
  return switch (slot) {
    GeneratedWakeDrainAgentSlot.agentA => 'generated-drain-agent-a',
    GeneratedWakeDrainAgentSlot.agentB => 'generated-drain-agent-b',
    GeneratedWakeDrainAgentSlot.agentC => 'generated-drain-agent-c',
  };
}

String generatedWakeDrainTaskId(GeneratedWakeDrainAgentSlot slot) {
  return 'generated-drain-task-${slot.name}';
}

class GeneratedWakeDrainJobSpec {
  const GeneratedWakeDrainJobSpec({
    required this.agentSlot,
    required this.reasonSlot,
    required this.insertSlot,
    required this.executorSlot,
  });

  final GeneratedWakeDrainAgentSlot agentSlot;
  final GeneratedWakeDrainReasonSlot reasonSlot;
  final GeneratedWakeDrainInsertSlot insertSlot;
  final GeneratedWakeDrainExecutorSlot executorSlot;

  String get agentId => generatedWakeDrainAgentId(agentSlot);

  String get reason => switch (reasonSlot) {
    GeneratedWakeDrainReasonSlot.subscription => WakeReason.subscription.name,
    GeneratedWakeDrainReasonSlot.reanalysis => WakeReason.reanalysis.name,
    GeneratedWakeDrainReasonSlot.scheduled => WakeReason.scheduled.name,
  };

  bool get insertThrows =>
      insertSlot == GeneratedWakeDrainInsertSlot.throwsException;

  bool get executorThrows =>
      executorSlot == GeneratedWakeDrainExecutorSlot.throwsException;

  bool get executorMutates =>
      executorSlot == GeneratedWakeDrainExecutorSlot.succeedsWithMutation;

  WakeJob job(int index) {
    return WakeJob(
      runKey: runKey(index),
      agentId: agentId,
      reason: reason,
      triggerTokens: {
        'generated-trigger-$index',
        'generated-trigger-${agentSlot.name}',
      },
      reasonId: reasonSlot == GeneratedWakeDrainReasonSlot.subscription
          ? 'generated-subscription-$index'
          : null,
      createdAt: generatedWakeDrainCreatedAt(index),
    );
  }

  String runKey(int index) => 'generated-drain-run-$index';

  @override
  String toString() {
    return 'GeneratedWakeDrainJobSpec('
        'agentSlot: $agentSlot, reasonSlot: $reasonSlot, '
        'insertSlot: $insertSlot, executorSlot: $executorSlot)';
  }
}

class GeneratedWakeDrainScenario {
  const GeneratedWakeDrainScenario({
    required this.jobs,
    required this.agentAContent,
    required this.agentBContent,
    required this.agentCContent,
    required this.busySlot,
  });

  final List<GeneratedWakeDrainJobSpec> jobs;
  final GeneratedWakeDrainContentSlot agentAContent;
  final GeneratedWakeDrainContentSlot agentBContent;
  final GeneratedWakeDrainContentSlot agentCContent;
  final GeneratedWakeBusySlot busySlot;

  String? get busyAgentId {
    return switch (busySlot) {
      GeneratedWakeBusySlot.none => null,
      GeneratedWakeBusySlot.agentA => generatedWakeDrainAgentId(
        GeneratedWakeDrainAgentSlot.agentA,
      ),
      GeneratedWakeBusySlot.agentB => generatedWakeDrainAgentId(
        GeneratedWakeDrainAgentSlot.agentB,
      ),
      GeneratedWakeBusySlot.agentC => generatedWakeDrainAgentId(
        GeneratedWakeDrainAgentSlot.agentC,
      ),
    };
  }

  GeneratedWakeDrainContentSlot contentFor(
    GeneratedWakeDrainAgentSlot slot,
  ) {
    return switch (slot) {
      GeneratedWakeDrainAgentSlot.agentA => agentAContent,
      GeneratedWakeDrainAgentSlot.agentB => agentBContent,
      GeneratedWakeDrainAgentSlot.agentC => agentCContent,
    };
  }

  GeneratedWakeDrainJobSpec? specForRunKey(String runKey) {
    for (var index = 0; index < jobs.length; index += 1) {
      if (jobs[index].runKey(index) == runKey) return jobs[index];
    }
    return null;
  }

  ExpectedWakeDrainModel expectedModel() {
    final agentAwaiting = {
      for (final slot in GeneratedWakeDrainAgentSlot.values)
        generatedWakeDrainAgentId(slot):
            contentFor(slot) != GeneratedWakeDrainContentSlot.notAwaiting,
    };
    final insertRunKeys = <String>[];
    final executedRunKeys = <String>[];
    final statusUpdates = <ExpectedWakeDrainStatusUpdate>[];
    final requeuedRunKeys = <String>[];
    final clearedAgentIds = <String>{};
    final throttledAgentIds = <String>{};

    for (var index = 0; index < jobs.length; index += 1) {
      final spec = jobs[index];
      final runKey = spec.runKey(index);
      if (spec.agentId == busyAgentId) {
        requeuedRunKeys.add(runKey);
        continue;
      }

      if (spec.reason == WakeReason.subscription.name &&
          throttledAgentIds.contains(spec.agentId)) {
        requeuedRunKeys.add(runKey);
        continue;
      }

      final contentSlot = contentFor(spec.agentSlot);
      final awaiting = agentAwaiting[spec.agentId] ?? false;
      if (awaiting) {
        if (contentSlot == GeneratedWakeDrainContentSlot.awaitingNoContent) {
          continue;
        }
        if (contentSlot == GeneratedWakeDrainContentSlot.awaitingHasContent) {
          agentAwaiting[spec.agentId] = false;
          clearedAgentIds.add(spec.agentId);
        }
      }

      insertRunKeys.add(runKey);
      if (spec.insertThrows) {
        continue;
      }

      executedRunKeys.add(runKey);
      statusUpdates.add(
        ExpectedWakeDrainStatusUpdate(
          runKey: runKey,
          status: spec.executorThrows
              ? WakeRunStatus.failed.name
              : WakeRunStatus.completed.name,
        ),
      );
      if (!spec.executorThrows && spec.reason == WakeReason.subscription.name) {
        throttledAgentIds.add(spec.agentId);
      }
    }

    return ExpectedWakeDrainModel(
      insertRunKeys: insertRunKeys,
      executedRunKeys: executedRunKeys,
      statusUpdates: statusUpdates,
      requeuedRunKeys: requeuedRunKeys,
      clearedAgentIds: clearedAgentIds,
    );
  }

  @override
  String toString() {
    return 'GeneratedWakeDrainScenario('
        'jobs: $jobs, agentAContent: $agentAContent, '
        'agentBContent: $agentBContent, agentCContent: $agentCContent, '
        'busySlot: $busySlot)';
  }
}

class ExpectedWakeDrainModel {
  const ExpectedWakeDrainModel({
    required this.insertRunKeys,
    required this.executedRunKeys,
    required this.statusUpdates,
    required this.requeuedRunKeys,
    required this.clearedAgentIds,
  });

  final List<String> insertRunKeys;
  final List<String> executedRunKeys;
  final List<ExpectedWakeDrainStatusUpdate> statusUpdates;
  final List<String> requeuedRunKeys;
  final Set<String> clearedAgentIds;
}

class ExpectedWakeDrainStatusUpdate {
  const ExpectedWakeDrainStatusUpdate({
    required this.runKey,
    required this.status,
  });

  final String runKey;
  final String status;
}

class ObservedWakeDrainExecution {
  const ObservedWakeDrainExecution({
    required this.agentId,
    required this.runKey,
    required this.triggers,
    required this.threadId,
  });

  final String agentId;
  final String runKey;
  final Set<String> triggers;
  final String threadId;
}

class ObservedWakeDrainStatusUpdate {
  const ObservedWakeDrainStatusUpdate({
    required this.runKey,
    required this.status,
    required this.errorMessage,
  });

  final String runKey;
  final String status;
  final String? errorMessage;
}

class GeneratedPendingWakeRestoreSpec {
  const GeneratedPendingWakeRestoreSpec({required this.dueSlot});

  final GeneratedPendingWakeRestoreDueSlot dueSlot;

  DateTime dueAt(DateTime now) {
    return switch (dueSlot) {
      GeneratedPendingWakeRestoreDueSlot.deepPast => now.subtract(
        const Duration(hours: 8),
      ),
      GeneratedPendingWakeRestoreDueSlot.justPast => now.subtract(
        const Duration(milliseconds: 1),
      ),
      GeneratedPendingWakeRestoreDueSlot.exactlyNow => now,
      GeneratedPendingWakeRestoreDueSlot.nearFuture => now.add(
        const Duration(minutes: 2),
      ),
      GeneratedPendingWakeRestoreDueSlot.farFuture => now.add(
        const Duration(hours: 6),
      ),
    };
  }

  bool isFuture(DateTime now) => dueAt(now).isAfter(now);

  @override
  String toString() {
    return 'GeneratedPendingWakeRestoreSpec(dueSlot: $dueSlot)';
  }
}

class GeneratedPendingWakeRestoreScenario {
  const GeneratedPendingWakeRestoreScenario({
    required this.specs,
    required this.priorThrottleSlot,
    required this.duplicateRestoreCalls,
    required this.registerSubscriptions,
  });

  final List<GeneratedPendingWakeRestoreSpec> specs;
  final GeneratedPendingWakeRestorePriorThrottleSlot priorThrottleSlot;
  final bool duplicateRestoreCalls;
  final bool registerSubscriptions;

  DateTime? priorThrottleDeadline(DateTime now, DateTime dueAt) {
    return switch (priorThrottleSlot) {
      GeneratedPendingWakeRestorePriorThrottleSlot.none => null,
      GeneratedPendingWakeRestorePriorThrottleSlot.earlierFuture => now.add(
        const Duration(seconds: 30),
      ),
      GeneratedPendingWakeRestorePriorThrottleSlot.laterFuture => dueAt.add(
        const Duration(minutes: 30),
      ),
    };
  }

  @override
  String toString() {
    return 'GeneratedPendingWakeRestoreScenario('
        'specs: $specs, priorThrottleSlot: $priorThrottleSlot, '
        'duplicateRestoreCalls: $duplicateRestoreCalls, '
        'registerSubscriptions: $registerSubscriptions)';
  }
}

class GeneratedPostRunThrottleScenario {
  const GeneratedPostRunThrottleScenario({
    required this.reasonSlot,
    required this.queuedSlot,
    required this.clockSlot,
  });

  final GeneratedPostRunReasonSlot reasonSlot;
  final GeneratedPostRunQueuedSlot queuedSlot;
  final GeneratedPostRunClockSlot clockSlot;

  String get reason {
    return switch (reasonSlot) {
      GeneratedPostRunReasonSlot.subscription => WakeReason.subscription.name,
      GeneratedPostRunReasonSlot.reanalysis => WakeReason.reanalysis.name,
      GeneratedPostRunReasonSlot.scheduled => WakeReason.scheduled.name,
    };
  }

  DateTime get now {
    return switch (clockSlot) {
      GeneratedPostRunClockSlot.beforeMorning => DateTime(2026, 5, 10, 3, 15),
      GeneratedPostRunClockSlot.afterMorning => DateTime(2026, 5, 10, 21, 30),
    };
  }

  DateTime? get expectedDeadline {
    if (reasonSlot != GeneratedPostRunReasonSlot.subscription) {
      return null;
    }
    return switch (queuedSlot) {
      GeneratedPostRunQueuedSlot.empty => null,
      GeneratedPostRunQueuedSlot.direct => now.add(
        WakeOrchestrator.throttleWindow,
      ),
      GeneratedPostRunQueuedSlot.propagatedOnly => switch (clockSlot) {
        GeneratedPostRunClockSlot.beforeMorning => DateTime(2026, 5, 10, 6),
        GeneratedPostRunClockSlot.afterMorning => DateTime(2026, 5, 11, 6),
      },
    };
  }

  bool get hasFollowUp => queuedSlot != GeneratedPostRunQueuedSlot.empty;

  bool get followUpHasDirectMatch =>
      queuedSlot == GeneratedPostRunQueuedSlot.direct;

  @override
  String toString() {
    return 'GeneratedPostRunThrottleScenario('
        'reasonSlot: $reasonSlot, queuedSlot: $queuedSlot, '
        'clockSlot: $clockSlot)';
  }
}

DateTime generatedWakeDrainCreatedAt(int index) {
  return DateTime(2026, 5, 20, 8).add(Duration(minutes: index));
}

extension AnyGeneratedWakeOrchestratorScenario on glados.Any {
  glados.Generator<GeneratedWakeReplacementSlot> get wakeReplacementSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeReplacementSlot.values);

  glados.Generator<GeneratedWakeExtraSubscriptionSlot>
  get wakeExtraSubscriptionSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeExtraSubscriptionSlot.values);

  glados.Generator<GeneratedWakeRemovalSlot> get wakeRemovalSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeRemovalSlot.values);

  glados.Generator<GeneratedWakeBatchSlot> get wakeBatchSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeBatchSlot.values);

  glados.Generator<GeneratedWakeBusySlot> get wakeBusySlot =>
      glados.AnyUtils(this).choose(GeneratedWakeBusySlot.values);

  glados.Generator<GeneratedWakeRoutingScenario> get wakeRoutingScenario =>
      glados.CombinableAny(this).combine5(
        wakeReplacementSlot,
        wakeExtraSubscriptionSlot,
        wakeRemovalSlot,
        wakeBatchSlot,
        wakeBusySlot,
        (
          GeneratedWakeReplacementSlot replacementSlot,
          GeneratedWakeExtraSubscriptionSlot extraSubscriptionSlot,
          GeneratedWakeRemovalSlot removalSlot,
          GeneratedWakeBatchSlot batchSlot,
          GeneratedWakeBusySlot busySlot,
        ) => GeneratedWakeRoutingScenario(
          replacementSlot: replacementSlot,
          extraSubscriptionSlot: extraSubscriptionSlot,
          removalSlot: removalSlot,
          batchSlot: batchSlot,
          busySlot: busySlot,
        ),
      );

  glados.Generator<GeneratedWakeDrainAgentSlot> get wakeDrainAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeDrainAgentSlot.values);

  glados.Generator<GeneratedWakeDrainReasonSlot> get wakeDrainReasonSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeDrainReasonSlot.values);

  glados.Generator<GeneratedWakeDrainContentSlot> get wakeDrainContentSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeDrainContentSlot.values);

  glados.Generator<GeneratedWakeDrainInsertSlot> get wakeDrainInsertSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeDrainInsertSlot.values);

  glados.Generator<GeneratedWakeDrainExecutorSlot> get wakeDrainExecutorSlot =>
      glados.AnyUtils(this).choose(GeneratedWakeDrainExecutorSlot.values);

  glados.Generator<GeneratedPendingWakeRestoreDueSlot>
  get pendingWakeRestoreDueSlot =>
      glados.AnyUtils(this).choose(GeneratedPendingWakeRestoreDueSlot.values);

  glados.Generator<GeneratedPendingWakeRestoreSpec>
  get pendingWakeRestoreSpec => pendingWakeRestoreDueSlot.map(
    (dueSlot) => GeneratedPendingWakeRestoreSpec(dueSlot: dueSlot),
  );

  glados.Generator<GeneratedPendingWakeRestorePriorThrottleSlot>
  get pendingWakeRestorePriorThrottleSlot => glados.AnyUtils(
    this,
  ).choose(GeneratedPendingWakeRestorePriorThrottleSlot.values);

  glados.Generator<GeneratedPendingWakeRestoreScenario>
  get pendingWakeRestoreScenario => glados.CombinableAny(this).combine4(
    glados.ListAnys(this).listWithLengthInRange(1, 5, pendingWakeRestoreSpec),
    pendingWakeRestorePriorThrottleSlot,
    glados.any.bool,
    glados.any.bool,
    (
      List<GeneratedPendingWakeRestoreSpec> specs,
      GeneratedPendingWakeRestorePriorThrottleSlot priorThrottleSlot,
      bool duplicateRestoreCalls,
      bool registerSubscriptions,
    ) => GeneratedPendingWakeRestoreScenario(
      specs: specs,
      priorThrottleSlot: priorThrottleSlot,
      duplicateRestoreCalls: duplicateRestoreCalls,
      registerSubscriptions: registerSubscriptions,
    ),
  );

  glados.Generator<GeneratedPostRunReasonSlot> get postRunReasonSlot =>
      glados.AnyUtils(this).choose(GeneratedPostRunReasonSlot.values);

  glados.Generator<GeneratedPostRunQueuedSlot> get postRunQueuedSlot =>
      glados.AnyUtils(this).choose(GeneratedPostRunQueuedSlot.values);

  glados.Generator<GeneratedPostRunClockSlot> get postRunClockSlot =>
      glados.AnyUtils(this).choose(GeneratedPostRunClockSlot.values);

  glados.Generator<GeneratedPostRunThrottleScenario>
  get postRunThrottleScenario => glados.CombinableAny(this).combine3(
    postRunReasonSlot,
    postRunQueuedSlot,
    postRunClockSlot,
    (
      GeneratedPostRunReasonSlot reasonSlot,
      GeneratedPostRunQueuedSlot queuedSlot,
      GeneratedPostRunClockSlot clockSlot,
    ) => GeneratedPostRunThrottleScenario(
      reasonSlot: reasonSlot,
      queuedSlot: queuedSlot,
      clockSlot: clockSlot,
    ),
  );

  glados.Generator<GeneratedWakeDrainJobSpec> get wakeDrainJobSpec =>
      glados.CombinableAny(this).combine4(
        wakeDrainAgentSlot,
        wakeDrainReasonSlot,
        wakeDrainInsertSlot,
        wakeDrainExecutorSlot,
        (
          GeneratedWakeDrainAgentSlot agentSlot,
          GeneratedWakeDrainReasonSlot reasonSlot,
          GeneratedWakeDrainInsertSlot insertSlot,
          GeneratedWakeDrainExecutorSlot executorSlot,
        ) => GeneratedWakeDrainJobSpec(
          agentSlot: agentSlot,
          reasonSlot: reasonSlot,
          insertSlot: insertSlot,
          executorSlot: executorSlot,
        ),
      );

  glados.Generator<GeneratedWakeDrainScenario> get wakeDrainScenario =>
      glados.CombinableAny(this).combine5(
        glados.ListAnys(this).listWithLengthInRange(1, 7, wakeDrainJobSpec),
        wakeDrainContentSlot,
        wakeDrainContentSlot,
        wakeDrainContentSlot,
        wakeBusySlot,
        (
          List<GeneratedWakeDrainJobSpec> jobs,
          GeneratedWakeDrainContentSlot agentAContent,
          GeneratedWakeDrainContentSlot agentBContent,
          GeneratedWakeDrainContentSlot agentCContent,
          GeneratedWakeBusySlot busySlot,
        ) => GeneratedWakeDrainScenario(
          jobs: jobs,
          agentAContent: agentAContent,
          agentBContent: agentBContent,
          agentCContent: agentCContent,
          busySlot: busySlot,
        ),
      );
}

late MockAgentRepository mockRepository;
late WakeQueue queue;
late WakeRunner runner;
late WakeOrchestrator orchestrator;

/// Registers the shared lifecycle used by every focused wake-orchestrator suite.
void configureWakeOrchestratorTestSuite() {
  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepository = MockAgentRepository();
    queue = WakeQueue();
    runner = WakeRunner();

    // Default stubs so that processNext (called automatically from _onBatch)
    // does not fail on unstubbed mock methods.
    stubWakeRepositoryDefaults(mockRepository);

    orchestrator = WakeOrchestrator(
      repository: mockRepository,
      queue: queue,
      runner: runner,
    );
  });

  tearDown(() async {
    await orchestrator.stop();
  });
}

/// Sends [tokens] and flushes microtasks so the listener fires in fake time.
void emitTokens(
  FakeAsync async,
  StreamController<Set<String>> controller,
  Set<String> tokens,
) {
  controller.add(tokens);
  async.flushMicrotasks();
}

/// Emits [tokens] and advances past the throttle window to execute the job.
void emitAndDrain(
  FakeAsync async,
  StreamController<Set<String>> controller,
  Set<String> tokens,
) {
  emitTokens(async, controller, tokens);
  async
    ..elapse(WakeOrchestrator.throttleWindow)
    ..flushMicrotasks();
}
