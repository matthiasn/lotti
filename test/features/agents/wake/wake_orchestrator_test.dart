import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'wake_orchestrator_test_helpers.dart';

enum _GeneratedWakeReplacementSlot {
  none,
  tokenB,
  agentB,
  predicateFalse,
  expanded,
}

enum _GeneratedWakeExtraSubscriptionSlot {
  none,
  sameAgentTrue,
  sameAgentFalse,
  otherAgentTrue,
  otherAgentFalse,
  agentCTrue,
}

enum _GeneratedWakeRemovalSlot {
  none,
  agentA,
  agentB,
  agentC,
  agentAAndB,
}

enum _GeneratedWakeBatchSlot {
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

enum _GeneratedWakeBusySlot { none, agentA, agentB, agentC }

enum _GeneratedWakeDrainAgentSlot { agentA, agentB, agentC }

enum _GeneratedWakeDrainReasonSlot { subscription, reanalysis, scheduled }

enum _GeneratedWakeDrainContentSlot {
  notAwaiting,
  awaitingNoContent,
  awaitingHasContent,
  awaitingNoTask,
  checkerThrows,
}

enum _GeneratedWakeDrainInsertSlot { succeeds, throwsException }

enum _GeneratedWakeDrainExecutorSlot {
  succeedsEmpty,
  succeedsWithMutation,
  throwsException,
}

enum _GeneratedPendingWakeRestoreDueSlot {
  deepPast,
  justPast,
  exactlyNow,
  nearFuture,
  farFuture,
}

enum _GeneratedPendingWakeRestorePriorThrottleSlot {
  none,
  earlierFuture,
  laterFuture,
}

enum _GeneratedPostRunReasonSlot { subscription, reanalysis, scheduled }

enum _GeneratedPostRunQueuedSlot { empty, direct, propagatedOnly }

enum _GeneratedPostRunClockSlot { beforeMorning, afterMorning }

class _GeneratedWakeSubscriptionSpec {
  const _GeneratedWakeSubscriptionSpec({
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

class _ExpectedWakeJob {
  _ExpectedWakeJob({
    required this.agentId,
    required this.reasonId,
    required Set<String> triggerTokens,
  }) : triggerTokens = Set<String>.from(triggerTokens);

  final String agentId;
  final String reasonId;
  final Set<String> triggerTokens;
}

class _GeneratedWakeRoutingScenario {
  const _GeneratedWakeRoutingScenario({
    required this.replacementSlot,
    required this.extraSubscriptionSlot,
    required this.removalSlot,
    required this.batchSlot,
    required this.busySlot,
  });

  final _GeneratedWakeReplacementSlot replacementSlot;
  final _GeneratedWakeExtraSubscriptionSlot extraSubscriptionSlot;
  final _GeneratedWakeRemovalSlot removalSlot;
  final _GeneratedWakeBatchSlot batchSlot;
  final _GeneratedWakeBusySlot busySlot;

  List<_GeneratedWakeSubscriptionSpec> get subscriptionSpecs {
    final specs = <_GeneratedWakeSubscriptionSpec>[
      const _GeneratedWakeSubscriptionSpec(
        id: 'sub-a',
        agentId: 'agent-a',
        matchEntityIds: {'entity-a', 'shared'},
        predicateAllows: true,
      ),
    ];

    final replacement = switch (replacementSlot) {
      _GeneratedWakeReplacementSlot.none => null,
      _GeneratedWakeReplacementSlot.tokenB =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-b'},
          predicateAllows: true,
        ),
      _GeneratedWakeReplacementSlot.agentB =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-b',
          matchEntityIds: {'entity-b', 'shared'},
          predicateAllows: true,
        ),
      _GeneratedWakeReplacementSlot.predicateFalse =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-a', 'entity-b'},
          predicateAllows: false,
        ),
      _GeneratedWakeReplacementSlot.expanded =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-a', 'entity-b', 'shared'},
          predicateAllows: true,
        ),
    };
    if (replacement != null) specs.add(replacement);

    final extra = switch (extraSubscriptionSlot) {
      _GeneratedWakeExtraSubscriptionSlot.none => null,
      _GeneratedWakeExtraSubscriptionSlot.sameAgentTrue =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-extra-a', 'shared'},
          predicateAllows: true,
        ),
      _GeneratedWakeExtraSubscriptionSlot.sameAgentFalse =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-a',
          agentId: 'agent-a',
          matchEntityIds: {'entity-extra-a', 'shared'},
          predicateAllows: false,
        ),
      _GeneratedWakeExtraSubscriptionSlot.otherAgentTrue =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-b',
          agentId: 'agent-b',
          matchEntityIds: {'entity-extra-b', 'shared'},
          predicateAllows: true,
        ),
      _GeneratedWakeExtraSubscriptionSlot.otherAgentFalse =>
        const _GeneratedWakeSubscriptionSpec(
          id: 'sub-extra-b',
          agentId: 'agent-b',
          matchEntityIds: {'entity-extra-b', 'shared'},
          predicateAllows: false,
        ),
      _GeneratedWakeExtraSubscriptionSlot.agentCTrue =>
        const _GeneratedWakeSubscriptionSpec(
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
      _GeneratedWakeRemovalSlot.none => const <String>{},
      _GeneratedWakeRemovalSlot.agentA => {'agent-a'},
      _GeneratedWakeRemovalSlot.agentB => {'agent-b'},
      _GeneratedWakeRemovalSlot.agentC => {'agent-c'},
      _GeneratedWakeRemovalSlot.agentAAndB => {'agent-a', 'agent-b'},
    };
  }

  Set<String> get batchTokens {
    return switch (batchSlot) {
      _GeneratedWakeBatchSlot.empty => const <String>{},
      _GeneratedWakeBatchSlot.entityA => {'entity-a'},
      _GeneratedWakeBatchSlot.entityB => {'entity-b'},
      _GeneratedWakeBatchSlot.shared => {'shared'},
      _GeneratedWakeBatchSlot.extraA => {'entity-extra-a'},
      _GeneratedWakeBatchSlot.extraB => {'entity-extra-b'},
      _GeneratedWakeBatchSlot.entityC => {'entity-c'},
      _GeneratedWakeBatchSlot.mixedAExtraA => {
        'entity-a',
        'entity-extra-a',
        'noise',
      },
      _GeneratedWakeBatchSlot.sharedExtraB => {
        'shared',
        'entity-extra-b',
        'noise',
      },
      _GeneratedWakeBatchSlot.noiseOnly => {'noise'},
      _GeneratedWakeBatchSlot.all => {
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
      _GeneratedWakeBusySlot.none => null,
      _GeneratedWakeBusySlot.agentA => 'agent-a',
      _GeneratedWakeBusySlot.agentB => 'agent-b',
      _GeneratedWakeBusySlot.agentC => 'agent-c',
    };
  }

  List<_GeneratedWakeSubscriptionSpec> get effectiveSubscriptions {
    final idsInOrder = <String>[];
    final byId = <String, _GeneratedWakeSubscriptionSpec>{};
    for (final spec in subscriptionSpecs) {
      if (!byId.containsKey(spec.id)) idsInOrder.add(spec.id);
      byId[spec.id] = spec;
    }
    return [
      for (final id in idsInOrder)
        if (!removedAgentIds.contains(byId[id]!.agentId)) byId[id]!,
    ];
  }

  List<_ExpectedWakeJob> get expectedJobs {
    final byAgent = <String, _ExpectedWakeJob>{};
    final tokens = batchTokens;

    for (final spec in effectiveSubscriptions) {
      final matched = tokens.intersection(spec.matchEntityIds);
      if (matched.isEmpty || !spec.predicateAllows) continue;

      final existing = byAgent[spec.agentId];
      if (existing == null) {
        byAgent[spec.agentId] = _ExpectedWakeJob(
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
    return '_GeneratedWakeRoutingScenario('
        'replacementSlot: $replacementSlot, '
        'extraSubscriptionSlot: $extraSubscriptionSlot, '
        'removalSlot: $removalSlot, batchSlot: $batchSlot, '
        'busySlot: $busySlot)';
  }
}

String _generatedWakeDrainAgentId(_GeneratedWakeDrainAgentSlot slot) {
  return switch (slot) {
    _GeneratedWakeDrainAgentSlot.agentA => 'generated-drain-agent-a',
    _GeneratedWakeDrainAgentSlot.agentB => 'generated-drain-agent-b',
    _GeneratedWakeDrainAgentSlot.agentC => 'generated-drain-agent-c',
  };
}

String _generatedWakeDrainTaskId(_GeneratedWakeDrainAgentSlot slot) {
  return 'generated-drain-task-${slot.name}';
}

class _GeneratedWakeDrainJobSpec {
  const _GeneratedWakeDrainJobSpec({
    required this.agentSlot,
    required this.reasonSlot,
    required this.insertSlot,
    required this.executorSlot,
  });

  final _GeneratedWakeDrainAgentSlot agentSlot;
  final _GeneratedWakeDrainReasonSlot reasonSlot;
  final _GeneratedWakeDrainInsertSlot insertSlot;
  final _GeneratedWakeDrainExecutorSlot executorSlot;

  String get agentId => _generatedWakeDrainAgentId(agentSlot);

  String get reason => switch (reasonSlot) {
    _GeneratedWakeDrainReasonSlot.subscription => WakeReason.subscription.name,
    _GeneratedWakeDrainReasonSlot.reanalysis => WakeReason.reanalysis.name,
    _GeneratedWakeDrainReasonSlot.scheduled => WakeReason.scheduled.name,
  };

  bool get insertThrows =>
      insertSlot == _GeneratedWakeDrainInsertSlot.throwsException;

  bool get executorThrows =>
      executorSlot == _GeneratedWakeDrainExecutorSlot.throwsException;

  bool get executorMutates =>
      executorSlot == _GeneratedWakeDrainExecutorSlot.succeedsWithMutation;

  WakeJob job(int index) {
    return WakeJob(
      runKey: runKey(index),
      agentId: agentId,
      reason: reason,
      triggerTokens: {
        'generated-trigger-$index',
        'generated-trigger-${agentSlot.name}',
      },
      reasonId: reasonSlot == _GeneratedWakeDrainReasonSlot.subscription
          ? 'generated-subscription-$index'
          : null,
      createdAt: _generatedWakeDrainCreatedAt(index),
    );
  }

  String runKey(int index) => 'generated-drain-run-$index';

  @override
  String toString() {
    return '_GeneratedWakeDrainJobSpec('
        'agentSlot: $agentSlot, reasonSlot: $reasonSlot, '
        'insertSlot: $insertSlot, executorSlot: $executorSlot)';
  }
}

class _GeneratedWakeDrainScenario {
  const _GeneratedWakeDrainScenario({
    required this.jobs,
    required this.agentAContent,
    required this.agentBContent,
    required this.agentCContent,
    required this.busySlot,
  });

  final List<_GeneratedWakeDrainJobSpec> jobs;
  final _GeneratedWakeDrainContentSlot agentAContent;
  final _GeneratedWakeDrainContentSlot agentBContent;
  final _GeneratedWakeDrainContentSlot agentCContent;
  final _GeneratedWakeBusySlot busySlot;

  String? get busyAgentId {
    return switch (busySlot) {
      _GeneratedWakeBusySlot.none => null,
      _GeneratedWakeBusySlot.agentA => _generatedWakeDrainAgentId(
        _GeneratedWakeDrainAgentSlot.agentA,
      ),
      _GeneratedWakeBusySlot.agentB => _generatedWakeDrainAgentId(
        _GeneratedWakeDrainAgentSlot.agentB,
      ),
      _GeneratedWakeBusySlot.agentC => _generatedWakeDrainAgentId(
        _GeneratedWakeDrainAgentSlot.agentC,
      ),
    };
  }

  _GeneratedWakeDrainContentSlot contentFor(
    _GeneratedWakeDrainAgentSlot slot,
  ) {
    return switch (slot) {
      _GeneratedWakeDrainAgentSlot.agentA => agentAContent,
      _GeneratedWakeDrainAgentSlot.agentB => agentBContent,
      _GeneratedWakeDrainAgentSlot.agentC => agentCContent,
    };
  }

  _GeneratedWakeDrainJobSpec? specForRunKey(String runKey) {
    for (var index = 0; index < jobs.length; index += 1) {
      if (jobs[index].runKey(index) == runKey) return jobs[index];
    }
    return null;
  }

  _ExpectedWakeDrainModel expectedModel() {
    final agentAwaiting = {
      for (final slot in _GeneratedWakeDrainAgentSlot.values)
        _generatedWakeDrainAgentId(slot):
            contentFor(slot) != _GeneratedWakeDrainContentSlot.notAwaiting,
    };
    final insertRunKeys = <String>[];
    final executedRunKeys = <String>[];
    final statusUpdates = <_ExpectedWakeDrainStatusUpdate>[];
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
        if (contentSlot == _GeneratedWakeDrainContentSlot.awaitingNoContent) {
          continue;
        }
        if (contentSlot == _GeneratedWakeDrainContentSlot.awaitingHasContent) {
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
        _ExpectedWakeDrainStatusUpdate(
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

    return _ExpectedWakeDrainModel(
      insertRunKeys: insertRunKeys,
      executedRunKeys: executedRunKeys,
      statusUpdates: statusUpdates,
      requeuedRunKeys: requeuedRunKeys,
      clearedAgentIds: clearedAgentIds,
    );
  }

  @override
  String toString() {
    return '_GeneratedWakeDrainScenario('
        'jobs: $jobs, agentAContent: $agentAContent, '
        'agentBContent: $agentBContent, agentCContent: $agentCContent, '
        'busySlot: $busySlot)';
  }
}

class _ExpectedWakeDrainModel {
  const _ExpectedWakeDrainModel({
    required this.insertRunKeys,
    required this.executedRunKeys,
    required this.statusUpdates,
    required this.requeuedRunKeys,
    required this.clearedAgentIds,
  });

  final List<String> insertRunKeys;
  final List<String> executedRunKeys;
  final List<_ExpectedWakeDrainStatusUpdate> statusUpdates;
  final List<String> requeuedRunKeys;
  final Set<String> clearedAgentIds;
}

class _ExpectedWakeDrainStatusUpdate {
  const _ExpectedWakeDrainStatusUpdate({
    required this.runKey,
    required this.status,
  });

  final String runKey;
  final String status;
}

class _ObservedWakeDrainExecution {
  const _ObservedWakeDrainExecution({
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

class _ObservedWakeDrainStatusUpdate {
  const _ObservedWakeDrainStatusUpdate({
    required this.runKey,
    required this.status,
    required this.errorMessage,
  });

  final String runKey;
  final String status;
  final String? errorMessage;
}

class _GeneratedPendingWakeRestoreSpec {
  const _GeneratedPendingWakeRestoreSpec({required this.dueSlot});

  final _GeneratedPendingWakeRestoreDueSlot dueSlot;

  DateTime dueAt(DateTime now) {
    return switch (dueSlot) {
      _GeneratedPendingWakeRestoreDueSlot.deepPast => now.subtract(
        const Duration(hours: 8),
      ),
      _GeneratedPendingWakeRestoreDueSlot.justPast => now.subtract(
        const Duration(milliseconds: 1),
      ),
      _GeneratedPendingWakeRestoreDueSlot.exactlyNow => now,
      _GeneratedPendingWakeRestoreDueSlot.nearFuture => now.add(
        const Duration(minutes: 2),
      ),
      _GeneratedPendingWakeRestoreDueSlot.farFuture => now.add(
        const Duration(hours: 6),
      ),
    };
  }

  bool isFuture(DateTime now) => dueAt(now).isAfter(now);

  @override
  String toString() {
    return '_GeneratedPendingWakeRestoreSpec(dueSlot: $dueSlot)';
  }
}

class _GeneratedPendingWakeRestoreScenario {
  const _GeneratedPendingWakeRestoreScenario({
    required this.specs,
    required this.priorThrottleSlot,
    required this.duplicateRestoreCalls,
    required this.registerSubscriptions,
  });

  final List<_GeneratedPendingWakeRestoreSpec> specs;
  final _GeneratedPendingWakeRestorePriorThrottleSlot priorThrottleSlot;
  final bool duplicateRestoreCalls;
  final bool registerSubscriptions;

  DateTime? priorThrottleDeadline(DateTime now, DateTime dueAt) {
    return switch (priorThrottleSlot) {
      _GeneratedPendingWakeRestorePriorThrottleSlot.none => null,
      _GeneratedPendingWakeRestorePriorThrottleSlot.earlierFuture => now.add(
        const Duration(seconds: 30),
      ),
      _GeneratedPendingWakeRestorePriorThrottleSlot.laterFuture => dueAt.add(
        const Duration(minutes: 30),
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedPendingWakeRestoreScenario('
        'specs: $specs, priorThrottleSlot: $priorThrottleSlot, '
        'duplicateRestoreCalls: $duplicateRestoreCalls, '
        'registerSubscriptions: $registerSubscriptions)';
  }
}

class _GeneratedPostRunThrottleScenario {
  const _GeneratedPostRunThrottleScenario({
    required this.reasonSlot,
    required this.queuedSlot,
    required this.clockSlot,
  });

  final _GeneratedPostRunReasonSlot reasonSlot;
  final _GeneratedPostRunQueuedSlot queuedSlot;
  final _GeneratedPostRunClockSlot clockSlot;

  String get reason {
    return switch (reasonSlot) {
      _GeneratedPostRunReasonSlot.subscription => WakeReason.subscription.name,
      _GeneratedPostRunReasonSlot.reanalysis => WakeReason.reanalysis.name,
      _GeneratedPostRunReasonSlot.scheduled => WakeReason.scheduled.name,
    };
  }

  DateTime get now {
    return switch (clockSlot) {
      _GeneratedPostRunClockSlot.beforeMorning => DateTime(2026, 5, 10, 3, 15),
      _GeneratedPostRunClockSlot.afterMorning => DateTime(2026, 5, 10, 21, 30),
    };
  }

  DateTime? get expectedDeadline {
    if (reasonSlot != _GeneratedPostRunReasonSlot.subscription) {
      return null;
    }
    return switch (queuedSlot) {
      _GeneratedPostRunQueuedSlot.empty => null,
      _GeneratedPostRunQueuedSlot.direct => now.add(
        WakeOrchestrator.throttleWindow,
      ),
      _GeneratedPostRunQueuedSlot.propagatedOnly => switch (clockSlot) {
        _GeneratedPostRunClockSlot.beforeMorning => DateTime(2026, 5, 10, 6),
        _GeneratedPostRunClockSlot.afterMorning => DateTime(2026, 5, 11, 6),
      },
    };
  }

  bool get hasFollowUp => queuedSlot != _GeneratedPostRunQueuedSlot.empty;

  bool get followUpHasDirectMatch =>
      queuedSlot == _GeneratedPostRunQueuedSlot.direct;

  @override
  String toString() {
    return '_GeneratedPostRunThrottleScenario('
        'reasonSlot: $reasonSlot, queuedSlot: $queuedSlot, '
        'clockSlot: $clockSlot)';
  }
}

DateTime _generatedWakeDrainCreatedAt(int index) {
  return DateTime(2026, 5, 20, 8).add(Duration(minutes: index));
}

extension _AnyGeneratedWakeOrchestratorScenario on glados.Any {
  glados.Generator<_GeneratedWakeReplacementSlot> get wakeReplacementSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeReplacementSlot.values);

  glados.Generator<_GeneratedWakeExtraSubscriptionSlot>
  get wakeExtraSubscriptionSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeExtraSubscriptionSlot.values);

  glados.Generator<_GeneratedWakeRemovalSlot> get wakeRemovalSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeRemovalSlot.values);

  glados.Generator<_GeneratedWakeBatchSlot> get wakeBatchSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeBatchSlot.values);

  glados.Generator<_GeneratedWakeBusySlot> get wakeBusySlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeBusySlot.values);

  glados.Generator<_GeneratedWakeRoutingScenario> get wakeRoutingScenario =>
      glados.CombinableAny(this).combine5(
        wakeReplacementSlot,
        wakeExtraSubscriptionSlot,
        wakeRemovalSlot,
        wakeBatchSlot,
        wakeBusySlot,
        (
          _GeneratedWakeReplacementSlot replacementSlot,
          _GeneratedWakeExtraSubscriptionSlot extraSubscriptionSlot,
          _GeneratedWakeRemovalSlot removalSlot,
          _GeneratedWakeBatchSlot batchSlot,
          _GeneratedWakeBusySlot busySlot,
        ) => _GeneratedWakeRoutingScenario(
          replacementSlot: replacementSlot,
          extraSubscriptionSlot: extraSubscriptionSlot,
          removalSlot: removalSlot,
          batchSlot: batchSlot,
          busySlot: busySlot,
        ),
      );

  glados.Generator<_GeneratedWakeDrainAgentSlot> get wakeDrainAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeDrainAgentSlot.values);

  glados.Generator<_GeneratedWakeDrainReasonSlot> get wakeDrainReasonSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeDrainReasonSlot.values);

  glados.Generator<_GeneratedWakeDrainContentSlot> get wakeDrainContentSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeDrainContentSlot.values);

  glados.Generator<_GeneratedWakeDrainInsertSlot> get wakeDrainInsertSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeDrainInsertSlot.values);

  glados.Generator<_GeneratedWakeDrainExecutorSlot> get wakeDrainExecutorSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeDrainExecutorSlot.values);

  glados.Generator<_GeneratedPendingWakeRestoreDueSlot>
  get pendingWakeRestoreDueSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeRestoreDueSlot.values);

  glados.Generator<_GeneratedPendingWakeRestoreSpec>
  get pendingWakeRestoreSpec => pendingWakeRestoreDueSlot.map(
    (dueSlot) => _GeneratedPendingWakeRestoreSpec(dueSlot: dueSlot),
  );

  glados.Generator<_GeneratedPendingWakeRestorePriorThrottleSlot>
  get pendingWakeRestorePriorThrottleSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedPendingWakeRestorePriorThrottleSlot.values);

  glados.Generator<_GeneratedPendingWakeRestoreScenario>
  get pendingWakeRestoreScenario => glados.CombinableAny(this).combine4(
    glados.ListAnys(this).listWithLengthInRange(1, 5, pendingWakeRestoreSpec),
    pendingWakeRestorePriorThrottleSlot,
    glados.any.bool,
    glados.any.bool,
    (
      List<_GeneratedPendingWakeRestoreSpec> specs,
      _GeneratedPendingWakeRestorePriorThrottleSlot priorThrottleSlot,
      bool duplicateRestoreCalls,
      bool registerSubscriptions,
    ) => _GeneratedPendingWakeRestoreScenario(
      specs: specs,
      priorThrottleSlot: priorThrottleSlot,
      duplicateRestoreCalls: duplicateRestoreCalls,
      registerSubscriptions: registerSubscriptions,
    ),
  );

  glados.Generator<_GeneratedPostRunReasonSlot> get postRunReasonSlot =>
      glados.AnyUtils(this).choose(_GeneratedPostRunReasonSlot.values);

  glados.Generator<_GeneratedPostRunQueuedSlot> get postRunQueuedSlot =>
      glados.AnyUtils(this).choose(_GeneratedPostRunQueuedSlot.values);

  glados.Generator<_GeneratedPostRunClockSlot> get postRunClockSlot =>
      glados.AnyUtils(this).choose(_GeneratedPostRunClockSlot.values);

  glados.Generator<_GeneratedPostRunThrottleScenario>
  get postRunThrottleScenario => glados.CombinableAny(this).combine3(
    postRunReasonSlot,
    postRunQueuedSlot,
    postRunClockSlot,
    (
      _GeneratedPostRunReasonSlot reasonSlot,
      _GeneratedPostRunQueuedSlot queuedSlot,
      _GeneratedPostRunClockSlot clockSlot,
    ) => _GeneratedPostRunThrottleScenario(
      reasonSlot: reasonSlot,
      queuedSlot: queuedSlot,
      clockSlot: clockSlot,
    ),
  );

  glados.Generator<_GeneratedWakeDrainJobSpec> get wakeDrainJobSpec =>
      glados.CombinableAny(this).combine4(
        wakeDrainAgentSlot,
        wakeDrainReasonSlot,
        wakeDrainInsertSlot,
        wakeDrainExecutorSlot,
        (
          _GeneratedWakeDrainAgentSlot agentSlot,
          _GeneratedWakeDrainReasonSlot reasonSlot,
          _GeneratedWakeDrainInsertSlot insertSlot,
          _GeneratedWakeDrainExecutorSlot executorSlot,
        ) => _GeneratedWakeDrainJobSpec(
          agentSlot: agentSlot,
          reasonSlot: reasonSlot,
          insertSlot: insertSlot,
          executorSlot: executorSlot,
        ),
      );

  glados.Generator<_GeneratedWakeDrainScenario> get wakeDrainScenario =>
      glados.CombinableAny(this).combine5(
        glados.ListAnys(this).listWithLengthInRange(1, 7, wakeDrainJobSpec),
        wakeDrainContentSlot,
        wakeDrainContentSlot,
        wakeDrainContentSlot,
        wakeBusySlot,
        (
          List<_GeneratedWakeDrainJobSpec> jobs,
          _GeneratedWakeDrainContentSlot agentAContent,
          _GeneratedWakeDrainContentSlot agentBContent,
          _GeneratedWakeDrainContentSlot agentCContent,
          _GeneratedWakeBusySlot busySlot,
        ) => _GeneratedWakeDrainScenario(
          jobs: jobs,
          agentAContent: agentAContent,
          agentBContent: agentBContent,
          agentCContent: agentCContent,
          busySlot: busySlot,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late WakeQueue queue;
  late WakeRunner runner;
  late WakeOrchestrator orchestrator;

  setUp(() {
    mockRepository = MockAgentRepository();
    queue = WakeQueue();
    runner = WakeRunner();

    // Default stubs so that processNext (called automatically from _onBatch)
    // does not fail on unstubbed mock methods.
    when(
      () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
    ).thenAnswer((_) async {});
    when(
      () => mockRepository.updateWakeRunStatus(
        any(),
        any(),
        completedAt: any(named: 'completedAt'),
        errorMessage: any(named: 'errorMessage'),
      ),
    ).thenAnswer((_) async {});
    // Stub getAgentState for throttle deadline persistence.
    when(
      () => mockRepository.getAgentState(any()),
    ).thenAnswer((_) async => null);
    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});

    orchestrator = WakeOrchestrator(
      repository: mockRepository,
      queue: queue,
      runner: runner,
    );
  });

  tearDown(() async {
    await orchestrator.stop();
  });

  /// Helper: sends [tokens] on [controller] and flushes microtasks so that
  /// the orchestrator's listener fires within `fakeAsync`.
  ///
  /// Note: with defer-first throttling, subscription wakes are NOT executed
  /// immediately — they are enqueued and a deferred drain is scheduled.
  /// Use [emitAndDrain] to also advance past the throttle window.
  void emitTokens(
    FakeAsync async,
    StreamController<Set<String>> controller,
    Set<String> tokens,
  ) {
    controller.add(tokens);
    async.flushMicrotasks();
  }

  /// Helper: emits tokens AND advances past the throttle window so the
  /// deferred drain fires and the queued job executes.
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

  group('WakeOrchestrator', () {
    group('subscription management', () {
      glados.Glados(
        glados.any.wakeRoutingScenario,
        glados.ExploreConfig(numRuns: 240),
      ).test(
        'matches generated subscription routing, replacement, and removal',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
            );
            final controller = StreamController<Set<String>>.broadcast();

            when(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            ).thenAnswer((_) async {});
            when(
              () => generatedRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).thenAnswer((_) async {});
            when(
              () => generatedRepository.getAgentState(any()),
            ).thenAnswer((_) async => null);
            when(
              () => generatedRepository.upsertEntity(any()),
            ).thenAnswer((_) async {});

            for (final spec in scenario.subscriptionSpecs) {
              generatedOrchestrator.addSubscription(spec.toSubscription());
            }
            scenario.removedAgentIds.forEach(
              generatedOrchestrator.removeSubscriptions,
            );

            final busyAgentId = scenario.busyAgentId;
            if (busyAgentId != null) {
              generatedRunner.tryAcquire(busyAgentId);
              async.flushMicrotasks();
            }

            generatedOrchestrator.start(controller.stream);
            emitTokens(async, controller, scenario.batchTokens);

            final actualJobs = <WakeJob>[];
            while (!generatedQueue.isEmpty) {
              actualJobs.add(generatedQueue.dequeue()!);
            }
            final expectedJobs = scenario.expectedJobs;

            expect(actualJobs, hasLength(expectedJobs.length));
            for (var i = 0; i < expectedJobs.length; i++) {
              final actual = actualJobs[i];
              final expected = expectedJobs[i];

              expect(actual.agentId, expected.agentId, reason: '$scenario');
              expect(actual.reason, WakeReason.subscription.name);
              expect(actual.reasonId, expected.reasonId, reason: '$scenario');
              expect(
                actual.triggerTokens,
                expected.triggerTokens,
                reason: '$scenario',
              );
            }

            verifyNever(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            );

            if (busyAgentId != null) generatedRunner.release(busyAgentId);
            generatedOrchestrator.stop();
            controller.close();
          });
        },
        tags: 'glados',
      );

      test('addSubscription registers a subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain fires after throttleWindow, consuming the job
          // and persisting a wake run entry.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-1');
          expect(captured.reason, 'subscription');
          expect(captured.reasonId, 'sub-1');

          controller.close();
        });
      });

      test('addSubscription replaces existing subscription with same id', () {
        fakeAsync((async) {
          // Add a subscription matching entity-1.
          orchestrator
            ..addSubscription(makeSub())
            // Replace it with one matching entity-2 (same id).
            ..addSubscription(makeSub(matchEntityIds: {'entity-2'}));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // entity-1 should no longer match (replaced).
          emitTokens(async, controller, {'entity-1'});
          expect(queue.isEmpty, isTrue);

          // entity-2 should match (the replacement).
          emitAndDrain(async, controller, {'entity-2'});
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('addSubscription with same id does not create duplicates '
          'that cause duplicate wake jobs', () {
        fakeAsync((async) {
          // Add the same subscription twice.
          for (var i = 0; i < 2; i++) {
            orchestrator.addSubscription(makeSub());
          }

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Should produce exactly one wake run, not two.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('removeSubscriptions removes all subscriptions for an agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', matchEntityIds: {'entity-2'}),
            )
            ..addSubscription(
              makeSub(id: 'sub-3', agentId: 'agent-2'),
            )
            ..removeSubscriptions('agent-1');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Only agent-2's subscription should fire; deferred drain consumes it.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });

      test('removeSubscription removes only the named subscription', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', matchEntityIds: {'entity-2'}),
            )
            // Drop the second subscription; the first must keep firing so a
            // per-link delete on agent-1 does not silence the agent's other
            // subscriptions or its per-agent throttle/suppression state.
            ..removeSubscription('sub-2');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-1');
          expect(captured.reasonId, 'sub-1');

          controller.close();
        });
      });
    });

    group('notification matching', () {
      test('ignores tokens that do not match any subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-99', 'entity-100'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('enqueues job when tokens match subscription', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-2', 'other-entity'});

          // Deferred drain consumes the job; verify the persisted entry.
          expect(capturedEntries, hasLength(1));
          expect(capturedEntries.first.agentId, 'agent-1');

          controller.close();
        });
      });

      test('matches multiple subscriptions in a single batch', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(
                id: 'sub-2',
                agentId: 'agent-2',
                matchEntityIds: {'entity-2'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Deferred drain processes all ready jobs.
          final captured = captureWakeRuns(mockRepository);

          expect(captured.length, equals(2));
          final ids = captured.map((e) => e.agentId).toSet();
          expect(ids, containsAll(['agent-1', 'agent-2']));

          controller.close();
        });
      });
    });

    group('predicate filtering', () {
      test('skips subscription when predicate returns false', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            makeSub(predicate: (tokens) => false),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('allows subscription when predicate returns true', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            makeSub(predicate: (tokens) => tokens.contains('entity-1')),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('predicate receives only matched tokens, not the full batch', () {
        fakeAsync((async) {
          Set<String>? receivedTokens;

          // Subscription matches only entity-1 and entity-2.
          orchestrator.addSubscription(
            makeSub(
              matchEntityIds: {'entity-1', 'entity-2'},
              predicate: (tokens) {
                receivedTokens = tokens;
                return true;
              },
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Batch contains entity-1 (matches) plus entity-99 and entity-100
          // (do not match the subscription). The predicate should only see
          // the intersection: {entity-1}.
          emitAndDrain(
            async,
            controller,
            {'entity-1', 'entity-99', 'entity-100'},
          );

          expect(
            receivedTokens,
            equals({'entity-1'}),
            reason:
                'Predicate must receive only the tokens that matched '
                "the subscription's entityIds, not the entire batch",
          );

          controller.close();
        });
      });
    });

    group('self-notification suppression', () {
      test('suppresses wake when all matched tokens were self-mutated', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
              'entity-2': const VectorClock({'node-1': 2}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          // Prove suppression prevented the wake — not just that the queue
          // drained via processNext.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('allows wake when some matched tokens are external', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          // entity-1 is self-mutated, entity-2 is external
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('does not suppress when agent has no mutation records', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('expires suppression after TTL elapses', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Advance past the 5-second suppression TTL.
          async.elapse(const Duration(seconds: 6));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Suppression should have expired — wake should proceed.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('does not expire suppression within TTL', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Only 2 seconds — within the 5-second TTL.
          async.elapse(const Duration(seconds: 2));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // Prove suppression prevented the wake — not just that the queue
          // drained via processNext.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('suppression is per-agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', agentId: 'agent-2'),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // agent-1 is suppressed, agent-2 is not; deferred drain persists
          // only agent-2's run.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });
    });

    group('token merging / coalescing', () {
      test('merges tokens into existing queued job for same agent', () {
        fakeAsync((async) {
          // Pre-lock agent-1 so the first job gets deferred (stays in queue).
          // The second batch can then merge into the queued job.
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First batch enqueues a job (entity-1 matches).
          emitTokens(async, controller, {'entity-1'});
          // Job is deferred because agent-1 is locked, so it stays in queue.

          // Second batch should merge into the existing queued job.
          emitTokens(async, controller, {'entity-2'});

          // Queue should have exactly one job (merged), not two.
          expect(queue.length, 1);
          final job = queue.dequeue()!;
          expect(job.agentId, 'agent-1');
          expect(
            job.triggerTokens,
            containsAll(['entity-1', 'entity-2']),
            reason:
                'Second batch tokens should have been merged into the '
                'existing queued job',
          );

          // No wake runs should have been persisted (agent was locked).
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          runner.release('agent-1');
          controller.close();
        });
      });
    });

    group('lifecycle', () {
      test('start subscribes to notification stream', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      // Uses real async (not fakeAsync) because StreamSubscription.cancel()
      // on broadcast streams does not resolve within fakeAsync.flushMicrotasks.
      // With defer-first throttling, subscription wakes are not dispatched
      // immediately — this test only verifies stream attachment/detachment
      // by checking that _onBatch fires (enqueue) vs not (old stream ignored).
      test('start replaces previous subscription when called twice', () async {
        orchestrator.addSubscription(makeSub());

        final controller1 = StreamController<Set<String>>.broadcast();
        final controller2 = StreamController<Set<String>>.broadcast();

        await orchestrator.start(controller1.stream);
        // Calling start again cancels the first subscription.
        await orchestrator.start(controller2.stream);

        // Emit on the old stream — should NOT enqueue anything.
        controller1.add({'entity-1'});
        await pumpEventQueue();
        expect(queue.isEmpty, isTrue);

        // Emit on the new stream — should enqueue a job (deferred).
        controller2.add({'entity-1'});
        await pumpEventQueue();
        // Job is enqueued but not yet executed (deferred by throttle).
        expect(queue.length, 1);

        await controller1.close();
        await controller2.close();
      });

      test('stop cancels notification subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator
            ..start(controller.stream)
            ..stop();
          async.flushMicrotasks();

          emitTokens(async, controller, {'entity-1'});
          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });
    });

    group('processNext', () {
      glados.Glados(
        glados.any.wakeDrainScenario,
        glados.ExploreConfig(numRuns: 220),
      ).test(
        'matches generated drain persistence, content gates, and requeueing',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final entries = <WakeRunLogData>[];
            final statusUpdates = <_ObservedWakeDrainStatusUpdate>[];
            final executions = <_ObservedWakeDrainExecution>[];
            final upsertedStates = <AgentStateEntity>[];
            final stateByAgent = <String, AgentStateEntity>{};
            final contentSlotByTaskId =
                <String, _GeneratedWakeDrainContentSlot>{};

            for (final slot in _GeneratedWakeDrainAgentSlot.values) {
              final contentSlot = scenario.contentFor(slot);
              if (contentSlot == _GeneratedWakeDrainContentSlot.notAwaiting) {
                continue;
              }

              final taskId =
                  contentSlot == _GeneratedWakeDrainContentSlot.awaitingNoTask
                  ? null
                  : _generatedWakeDrainTaskId(slot);
              if (taskId != null) {
                contentSlotByTaskId[taskId] = contentSlot;
              }
              final agentId = _generatedWakeDrainAgentId(slot);
              stateByAgent[agentId] = makeTestState(
                id: 'generated-drain-state-${slot.name}',
                agentId: agentId,
                awaitingContent: true,
                slots: AgentSlots(activeTaskId: taskId),
              );
            }

            when(
              () => generatedRepository.getAgentState(any()),
            ).thenAnswer((invocation) async {
              final agentId = invocation.positionalArguments.single as String;
              return stateByAgent[agentId];
            });
            when(
              () => generatedRepository.upsertEntity(any()),
            ).thenAnswer((invocation) async {
              final entity =
                  invocation.positionalArguments.single as AgentDomainEntity;
              if (entity is AgentStateEntity) {
                stateByAgent[entity.agentId] = entity;
                upsertedStates.add(entity);
              }
            });
            when(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            ).thenAnswer((invocation) async {
              final entry = invocation.namedArguments[#entry] as WakeRunLogData;
              entries.add(entry);
              final spec = scenario.specForRunKey(entry.runKey)!;
              if (spec.insertThrows) {
                throw StateError('generated insert failure');
              }
            });
            when(
              () => generatedRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).thenAnswer((invocation) async {
              statusUpdates.add(
                _ObservedWakeDrainStatusUpdate(
                  runKey: invocation.positionalArguments[0] as String,
                  status: invocation.positionalArguments[1] as String,
                  errorMessage:
                      invocation.namedArguments[#errorMessage] as String?,
                ),
              );
            });

            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
              taskContentChecker: (taskId) async {
                final contentSlot = contentSlotByTaskId[taskId];
                if (contentSlot ==
                    _GeneratedWakeDrainContentSlot.checkerThrows) {
                  throw StateError('generated content check failure');
                }
                return contentSlot ==
                    _GeneratedWakeDrainContentSlot.awaitingHasContent;
              },
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                executions.add(
                  _ObservedWakeDrainExecution(
                    agentId: agentId,
                    runKey: runKey,
                    triggers: Set<String>.from(triggers),
                    threadId: threadId,
                  ),
                );
                final spec = scenario.specForRunKey(runKey)!;
                if (spec.executorThrows) {
                  throw StateError('generated executor failure');
                }
                if (spec.executorMutates) {
                  return {
                    'generated-mutation-$runKey': const VectorClock({
                      'generated-node': 1,
                    }),
                  };
                }
                return null;
              },
            );

            for (var index = 0; index < scenario.jobs.length; index += 1) {
              generatedQueue.enqueue(scenario.jobs[index].job(index));
            }

            final busyAgentId = scenario.busyAgentId;
            if (busyAgentId != null) {
              generatedRunner.tryAcquire(busyAgentId);
              async.flushMicrotasks();
            }

            generatedOrchestrator.processNext();
            async.flushMicrotasks();

            final expected = scenario.expectedModel();
            expect(
              entries.map((entry) => entry.runKey).toList(),
              expected.insertRunKeys,
              reason: '$scenario',
            );
            for (final entry in entries) {
              final spec = scenario.specForRunKey(entry.runKey)!;
              final index = int.parse(entry.runKey.split('-').last);
              expect(entry.agentId, spec.agentId, reason: '$scenario');
              expect(entry.reason, spec.reason, reason: '$scenario');
              expect(entry.threadId, entry.runKey, reason: '$scenario');
              expect(
                entry.createdAt,
                _generatedWakeDrainCreatedAt(index),
                reason: '$scenario',
              );
              expect(entry.status, WakeRunStatus.running.name);
            }

            expect(
              executions.map((execution) => execution.runKey).toList(),
              expected.executedRunKeys,
              reason: '$scenario',
            );
            for (final execution in executions) {
              final spec = scenario.specForRunKey(execution.runKey)!;
              final index = int.parse(execution.runKey.split('-').last);
              expect(execution.agentId, spec.agentId, reason: '$scenario');
              expect(execution.threadId, execution.runKey, reason: '$scenario');
              expect(
                execution.triggers,
                spec.job(index).triggerTokens,
                reason: '$scenario',
              );
            }

            expect(statusUpdates, hasLength(expected.statusUpdates.length));
            for (var index = 0; index < statusUpdates.length; index += 1) {
              final actual = statusUpdates[index];
              final expectedUpdate = expected.statusUpdates[index];
              expect(actual.runKey, expectedUpdate.runKey, reason: '$scenario');
              expect(actual.status, expectedUpdate.status, reason: '$scenario');
              if (expectedUpdate.status == WakeRunStatus.failed.name) {
                expect(actual.errorMessage, isNotNull, reason: '$scenario');
              } else {
                expect(actual.errorMessage, isNull, reason: '$scenario');
              }
            }

            final remainingRunKeys = <String>[];
            while (!generatedQueue.isEmpty) {
              remainingRunKeys.add(generatedQueue.dequeue()!.runKey);
            }
            expect(
              remainingRunKeys,
              expected.requeuedRunKeys,
              reason: '$scenario',
            );

            for (final agentId in expected.clearedAgentIds) {
              expect(
                stateByAgent[agentId]?.awaitingContent,
                isFalse,
                reason: '$scenario',
              );
              expect(
                upsertedStates.any(
                  (state) => state.agentId == agentId && !state.awaitingContent,
                ),
                isTrue,
                reason: '$scenario',
              );
            }

            for (final slot in _GeneratedWakeDrainAgentSlot.values) {
              final agentId = _generatedWakeDrainAgentId(slot);
              expect(
                generatedRunner.isRunning(agentId),
                agentId == busyAgentId,
                reason: '$scenario',
              );
            }

            generatedOrchestrator.stop();
            async.flushMicrotasks();
            if (busyAgentId != null) {
              generatedRunner.release(busyAgentId);
            }
          });
        },
        tags: 'glados',
      );

      test('does nothing when queue is empty', () {
        fakeAsync((async) {
          orchestrator.processNext();
          async.flushMicrotasks();

          // No repository calls should have been made
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );
        });
      });

      test('acquires runner lock, persists run, and releases lock', () {
        fakeAsync((async) {
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((_) async {});

          queue.enqueue(makeJob(reasonId: 'sub-1'));

          orchestrator.processNext();
          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // Lock should be released after processNext completes
          expect(runner.isRunning('agent-1'), isFalse);
        });
      });

      test('re-enqueues job when agent is already running', () {
        fakeAsync((async) {
          // Pre-lock the agent
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue.enqueue(makeJob());

          orchestrator.processNext();
          async.flushMicrotasks();

          // Job should be back in the queue (deferred by the loop)
          expect(queue.isEmpty, isFalse);
          expect(queue.dequeue()!.runKey, 'rk-1');

          // No DB call since we couldn't acquire
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          runner.release('agent-1');
        });
      });

      test('persisted entry has correct fields from job', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          final createdAt = DateTime(2024, 3, 15, 10, 30);
          queue.enqueue(
            makeJob(
              runKey: 'rk-test',
              agentId: 'agent-42',
              reason: 'timer',
              reasonId: 'timer-7',
              createdAt: createdAt,
            ),
          );

          orchestrator.processNext();
          async.flushMicrotasks();

          expect(capturedEntries, hasLength(1));
          final capturedEntry = capturedEntries.first;
          expect(capturedEntry.runKey, 'rk-test');
          expect(capturedEntry.agentId, 'agent-42');
          expect(capturedEntry.reason, 'timer');
          expect(capturedEntry.reasonId, 'timer-7');
          expect(capturedEntry.threadId, 'rk-test');
          expect(capturedEntry.status, 'running');
          expect(capturedEntry.createdAt, createdAt);
          expect(capturedEntry.startedAt, isNotNull);
        });
      });

      test('marks run as failed when wakeExecutor is null', () {
        fakeAsync((async) {
          // orchestrator created without wakeExecutor (default null)
          queue.enqueue(makeJob(runKey: 'rk-null'));

          orchestrator.processNext();
          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          verify(
            () => mockRepository.updateWakeRunStatus(
              'rk-null',
              'failed',
              errorMessage: 'No wake executor registered',
            ),
          ).called(1);

          expect(runner.isRunning('agent-1'), isFalse);
        });
      });

      test('processes multiple agents in one processNext loop', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both jobs processed in one call — no starvation.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.length, equals(2));
          expect(
            captured.map((e) => e.agentId).toSet(),
            containsAll(['agent-1', 'agent-2']),
          );
        });
      });

      test('defers busy agent job and processes others', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          // Pre-lock agent-1
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Only agent-2 processed; agent-1 deferred back to queue.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.length, equals(1));
          expect(captured.first.agentId, 'agent-2');

          // agent-1 job is still in queue
          expect(queue.isEmpty, isFalse);
          expect(queue.dequeue()!.agentId, 'agent-1');

          runner.release('agent-1');
        });
      });

      test('clears history only when queue fully drained', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          // Pre-lock agent-1 so its job gets deferred
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Queue is not empty (agent-1 deferred), so history not cleared.
          // Re-enqueueing rk-1 should fail (key still seen).
          final reEnqueued = queue.enqueue(makeJob());
          // The deferred job was re-enqueued internally, so rk-1 is already
          // in the queue. A second enqueue with the same key should be rejected.
          expect(reEnqueued, isFalse);

          runner.release('agent-1');
        });
      });

      test('clears mutation history when wake produces no mutations', () {
        fakeAsync((async) {
          // Pre-record mutations, executor returns null (no mutations)
          orchestrator
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            })
            ..wakeExecutor = noOpExecutor;

          queue.enqueue(makeJob());

          orchestrator.processNext();
          async.flushMicrotasks();

          // Now entity-1 should no longer be suppressed for agent-1
          orchestrator.addSubscription(makeSub());

          // Clear verify history to isolate the next assertion.
          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the cooldown.
          orchestrator.clearThrottle('agent-1');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Wake should NOT be suppressed since mutation history was cleared.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('removeSubscriptions also clears mutation history', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            })
            ..removeSubscriptions('agent-1')
            // Re-add subscription after removal
            ..addSubscription(makeSub(id: 'sub-1b'));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Wake should NOT be suppressed — mutation history was cleared
          // when subscriptions were removed.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('mid-execution signals are queued but suppressed during drain '
          'when they match self-mutations', () {
        fakeAsync((async) {
          // Use a completer to pause the executor mid-flight so we can
          // inject a notification that would match the agent's subscription.
          final gate = Completer<Map<String, VectorClock>?>();

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              return gate.future;
            };

          // Start execution via direct enqueue (bypasses _onBatch deferral).
          queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
          orchestrator.processNext();
          async.flushMicrotasks();

          // Executor is now paused on `gate`. Fire a notification for the
          // same entity while the agent is executing.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // The notification is NOT suppressed by _onBatch (so external
          // signals during execution are preserved). Instead it is queued
          // and will be suppressed during the drain re-check using the
          // pre-registered suppression data.
          expect(queue.isEmpty, isFalse);

          // Complete the executor — returns the mutation set confirming
          // entity-1 was self-written.
          gate.complete({
            'entity-1': const VectorClock({'node-1': 1}),
          });
          async.flushMicrotasks();

          // The queued job should have been suppressed during drain
          // re-check (pre-registered suppression covers entity-1).
          // Only one wake run should have been persisted (the original).
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'external signal for different entity during execution '
        'is NOT suppressed after execution completes (only actual '
        'mutations are recorded)',
        () {
          fakeAsync((async) {
            final gate = Completer<Map<String, VectorClock>?>();
            var executionCount = 0;

            orchestrator
              ..addSubscription(
                makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
              )
              ..wakeExecutor = (agentId, runKey, triggers, threadId) {
                executionCount++;
                if (executionCount == 1) return gate.future;
                return Future.value();
              };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            // Start execution via direct enqueue (bypasses _onBatch deferral).
            queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
            orchestrator.processNext();
            async.flushMicrotasks();
            expect(executionCount, 1);

            // While executing, an external change to entity-2 arrives.
            // Since _onBatch sets throttle on first non-throttled match,
            // this will enqueue and set throttle + deferred drain.
            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);
            emitTokens(async, controller, {'entity-2'});

            // The signal should be queued.
            expect(queue.isEmpty, isFalse);

            // Complete first execution — only entity-1 was mutated.
            // Only actual mutations (entity-1) are recorded in the
            // confirmed suppression record; entity-2 is NOT suppressed.
            gate.complete({
              'entity-1': const VectorClock({'node-1': 1}),
            });
            async.flushMicrotasks();

            // Only the first wake should have run so far (throttle gate).
            expect(executionCount, 1);

            // After the throttle window expires, the deferred drain fires.
            // entity-2 is NOT in the confirmed suppression set (only
            // entity-1 was mutated), so the queued job proceeds.
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();
            expect(executionCount, 2);

            controller.close();
          });
        },
      );

      test('only actual mutations are suppressed after execution '
          '(non-mutated subscribed IDs are not suppressed)', () {
        fakeAsync((async) {
          // Executor mutates entity-1 but not entity-2.
          // Only entity-1 should be in the confirmed suppression record.
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              // Only entity-1 was actually mutated.
              return {
                'entity-1': const VectorClock({'node-1': 1}),
              };
            };

          // Trigger the first execution.
          queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
          orchestrator.processNext();
          async.flushMicrotasks();

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the cooldown.
          orchestrator.clearThrottle('agent-1');

          // entity-2 was NOT mutated, so it is NOT suppressed — the
          // notification should enqueue a wake job immediately.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-2'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'catches insertWakeRun failure, releases lock, and continues drain',
        () {
          fakeAsync((async) {
            var insertCallCount = 0;
            when(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).thenAnswer((_) async {
              insertCallCount++;
              if (insertCallCount == 1) throw Exception('DB failure');
            });

            // Enqueue two jobs for different agents.
            queue
              ..enqueue(makeJob(runKey: 'rk-fail'))
              ..enqueue(
                makeJob(
                  runKey: 'rk-ok',
                  agentId: 'agent-2',
                  triggerTokens: {'tok-b'},
                ),
              );

            // processNext should NOT throw — the error is caught internally.
            orchestrator.processNext();
            async.flushMicrotasks();

            // Both locks should be released.
            expect(runner.isRunning('agent-1'), isFalse);
            expect(runner.isRunning('agent-2'), isFalse);

            // The second job should still have been processed despite the
            // first one failing.
            expect(insertCallCount, 2);
          });
        },
      );

      test(
        'suppresses deferred subscription job that becomes self-mutated',
        () {
          fakeAsync((async) {
            // Agent-1 is busy (pre-locked). A subscription job is enqueued and
            // deferred because the agent is running. While deferred, the
            // orchestrator records mutations that cover all trigger tokens.
            // When the deferred job is re-processed, the drain suppression
            // re-check should skip it.

            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = (agentId, runKey, triggers, threadId) {
                if (runKey.contains('manual')) {
                  return gate.future;
                }
                return Future.value();
              };

            // Enqueue a manual wake that will hold the lock.
            queue.enqueue(
              makeJob(runKey: 'manual-rk', reason: 'manual', triggerTokens: {}),
            );
            orchestrator.processNext();
            async.flushMicrotasks();

            // Agent-1 is now busy executing the manual job.
            // Enqueue a subscription job that will be deferred.
            queue.enqueue(
              makeJob(runKey: 'sub-rk', triggerTokens: {'entity-1'}),
            );
            orchestrator.processNext();
            async.flushMicrotasks();

            // Complete the manual job with mutations covering entity-1.
            gate.complete({
              'entity-1': const VectorClock({'node-1': 1}),
            });
            async.flushMicrotasks();

            // The deferred subscription job should now be suppressed because
            // entity-1 was self-mutated by the manual execution.
            // Only the manual run's insertWakeRun should have been called.
            final captured = captureWakeRuns(mockRepository);

            // Only the manual wake run should have been persisted;
            // the subscription job should have been suppressed at re-check.
            expect(captured.length, 1);
            expect(captured.first.reason, 'manual');
          });
        },
      );

      test('continues drain when updateWakeRunStatus throws on completion', () {
        fakeAsync((async) {
          var executorCallCount = 0;
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executorCallCount++;
                return null;
              };

          // Make updateWakeRunStatus throw on the first call (completion
          // status update for agent-1) but succeed on the second (agent-2).
          var updateCallCount = 0;
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((_) async {
            updateCallCount++;
            if (updateCallCount == 1) throw Exception('DB write failed');
          });

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both executors should have run despite the status update failure.
          expect(executorCallCount, 2);
          // Both locks should be released.
          expect(runner.isRunning('agent-1'), isFalse);
          expect(runner.isRunning('agent-2'), isFalse);
        });
      });

      test('continues drain when updateWakeRunStatus throws on failure', () {
        fakeAsync((async) {
          // Executor throws for agent-1; the subsequent updateWakeRunStatus
          // ('failed') also throws. Agent-2 should still be processed.
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                if (agentId == 'agent-1') throw Exception('Executor error');
                return null;
              };

          var updateCallCount = 0;
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((_) async {
            updateCallCount++;
            // First update is for agent-1's 'failed' status — throw.
            if (updateCallCount == 1) throw Exception('DB write failed');
          });

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both locks should be released.
          expect(runner.isRunning('agent-1'), isFalse);
          expect(runner.isRunning('agent-2'), isFalse);
          // Agent-2's status update should have succeeded.
          expect(updateCallCount, 2);
        });
      });

      test('single-flight guard processes jobs enqueued during drain', () {
        fakeAsync((async) {
          // Use a completer to pause the first job mid-execution so we can
          // enqueue a second job while the drain is in-flight.
          final gate = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            executionCount++;
            if (executionCount == 1) return gate.future;
            return Future.value();
          };

          // Enqueue and start draining the first job.
          queue.enqueue(makeJob(reason: 'test'));
          orchestrator.processNext();
          async.flushMicrotasks();

          // Drain is blocked on gate. Enqueue a second job for a different
          // agent and call processNext again — the guard should defer it.
          queue.enqueue(
            makeJob(
              runKey: 'rk-2',
              agentId: 'agent-2',
              reason: 'test',
              triggerTokens: {'tok-b'},
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

          // Only the first job should have started so far.
          expect(executionCount, 1);

          // Complete the first job — the drain should pick up the second.
          gate.complete(null);
          async.flushMicrotasks();

          expect(executionCount, 2);
        });
      });
    });

    group('enqueueManualWake', () {
      test('enqueues a job and triggers processNext', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: noOpExecutor,
          )).enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'task-1'},
          );

          async.flushMicrotasks();

          // The job should have been executed (run persisted + completed).
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
          verify(
            () => mockRepository.updateWakeRunStatus(
              any(),
              'completed',
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
        });
      });

      test('uses the provided reason in the wake job', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: noOpExecutor,
          )).enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          );

          async.flushMicrotasks();

          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured;
          final entry = captured.first as WakeRunLogData;
          expect(entry.reason, 'reanalysis');
          expect(entry.agentId, 'agent-1');
        });
      });

      test('bypasses self-notification suppression', () {
        fakeAsync((async) {
          orchestrator =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: runner,
                  wakeExecutor: noOpExecutor,
                )
                // Record mutations for agent-1 that include task-1.
                ..recordMutatedEntities('agent-1', {
                  'task-1': const VectorClock({}),
                })
                // Manual wake should still go through despite suppression state.
                ..enqueueManualWake(
                  agentId: 'agent-1',
                  reason: 'creation',
                  triggerTokens: {'task-1'},
                );

          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
        });
      });
      test('removes pending subscription jobs for the same agent', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          // ignore: cascade_invocations
          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'task-1'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Emit a notification that enqueues a subscription job.
          controller.add({'task-1'});
          async.flushMicrotasks();

          // The job is deferred (not yet executed). Queue should have 1 job.
          expect(queue.length, 1);

          // Manual wake should remove the pending subscription job and
          // enqueue only the manual one → single execution.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'manual',
          );
          async.flushMicrotasks();

          // Only one wake run should have been executed (the manual one).
          expect(capturedEntries, hasLength(1));
          expect(capturedEntries.first.reason, 'manual');

          controller.close();
        });
      });
    });

    group('monotonic wake counter', () {
      test('identical notifications produce different run keys', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          // ignore: cascade_invocations
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: first notification enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});

          // Advance past the 5s suppression TTL so the second notification
          // is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));

          // Clear throttle so the second notification is not blocked.
          orchestrator.clearThrottle('agent-1');

          // Second identical notification — must produce a different run key
          emitAndDrain(async, controller, {'entity-1'});

          expect(capturedEntries.length, equals(2));
          expect(
            capturedEntries[0].runKey,
            isNot(equals(capturedEntries[1].runKey)),
            reason:
                'Identical notifications must produce distinct run keys '
                'via the monotonic wake counter',
          );

          controller.close();
        });
      });

      test('removeSubscriptions resets counter for agent', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          // ignore: cascade_invocations
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Fire twice to increment counter to 1 (defer-first: drain each).
          emitAndDrain(async, controller, {'entity-1'});
          // Advance past the 5s suppression TTL so the second notification
          // is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));
          orchestrator.clearThrottle('agent-1');
          emitAndDrain(async, controller, {'entity-1'});
          expect(capturedEntries.length, equals(2));

          // Remove and re-add subscription (counter resets, throttle clears).
          orchestrator.removeSubscriptions('agent-1');
          // ignore: cascade_invocations
          orchestrator.addSubscription(makeSub());

          // Fire again — counter is back to 0 after reset, so both
          // invocations after the reset should succeed (not be deduped).
          emitAndDrain(async, controller, {'entity-1'});
          expect(capturedEntries.length, equals(3));

          controller.close();
        });
      });
    });

    group('deferred drain via throttle timer', () {
      test('notification during post-execution throttle enqueues for '
          'deferred drain', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First wake: defer-first enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 1);

          // Advance past the 5s suppression TTL so the next notification
          // for entity-1 is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));

          // Agent is now throttled (post-execution throttle). An external
          // notification arrives — no queued job to merge into, so a new
          // job is enqueued for the deferred drain.
          emitTokens(async, controller, {'entity-1'});

          // Advance past the post-execution throttle to fire deferred drain.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Second execution — the external change triggers a follow-up wake.
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('stop cancels deferred drain timers', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Emit tokens — enqueues job + schedules deferred drain.
          emitTokens(async, controller, {'entity-1'});

          // Stop the orchestrator before the deferred drain fires.
          orchestrator.stop();
          async.flushMicrotasks();

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Advance past the throttle window — timer should not fire.
          async
            ..elapse(WakeOrchestrator.throttleWindow * 2)
            ..flushMicrotasks();

          // No wake run should have been persisted after stop.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });
    });

    group('throttle gate', () {
      glados.Glados(
        glados.any.pendingWakeRestoreScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated persisted pending-wake restoration semantics',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final stateByAgent = <String, AgentStateEntity>{};
            final executions = <String>[];
            final now = clock.now();

            when(
              () => generatedRepository.getAgentState(any()),
            ).thenAnswer((invocation) async {
              final agentId = invocation.positionalArguments.single as String;
              return stateByAgent[agentId];
            });
            when(
              () => generatedRepository.upsertEntity(any()),
            ).thenAnswer((invocation) async {
              final entity =
                  invocation.positionalArguments.single as AgentDomainEntity;
              if (entity is AgentStateEntity) {
                stateByAgent[entity.agentId] = entity;
              }
            });
            when(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            ).thenAnswer((_) async {});
            when(
              () => generatedRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).thenAnswer((_) async {});

            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                executions.add(agentId);
                expect(triggers, isEmpty, reason: '$scenario');
                return null;
              },
            );

            final dueByAgent = <String, DateTime>{};
            for (final (index, spec) in scenario.specs.indexed) {
              final agentId = 'generated-restore-agent-$index';
              final dueAt = spec.dueAt(now);
              dueByAgent[agentId] = dueAt;
              stateByAgent[agentId] = makeTestState(
                agentId: agentId,
                nextWakeAt: dueAt,
              );

              if (scenario.registerSubscriptions) {
                generatedOrchestrator.addSubscription(
                  makeSub(
                    id: 'generated-restore-sub-$index',
                    agentId: agentId,
                    matchEntityIds: {'generated-restore-token-$index'},
                  ),
                );
              }

              final prior = scenario.priorThrottleDeadline(now, dueAt);
              if (prior != null && prior.isAfter(now)) {
                generatedOrchestrator.setThrottleDeadline(agentId, prior);
              }

              generatedOrchestrator.restorePendingWake(
                agentId: agentId,
                dueAt: dueAt,
              );
              if (scenario.duplicateRestoreCalls) {
                generatedOrchestrator.restorePendingWake(
                  agentId: agentId,
                  dueAt: dueAt,
                );
              }
            }

            async.flushMicrotasks();

            final overdueAgentIds = dueByAgent.entries
                .where((entry) => !entry.value.isAfter(now))
                .map((entry) => entry.key)
                .toSet();
            final futureEntries =
                dueByAgent.entries
                    .where((entry) => entry.value.isAfter(now))
                    .toList()
                  ..sort((a, b) => a.value.compareTo(b.value));

            expect(executions.toSet(), overdueAgentIds, reason: '$scenario');
            expect(executions, hasLength(overdueAgentIds.length));
            expect(generatedQueue.length, futureEntries.length);

            for (final agentId in overdueAgentIds) {
              expect(
                stateByAgent[agentId]?.nextWakeAt,
                isNull,
                reason: '$scenario',
              );
            }

            if (futureEntries.isNotEmpty) {
              final firstDueAt = futureEntries.first.value;
              async
                ..elapse(
                  firstDueAt.difference(clock.now()) -
                      const Duration(milliseconds: 1),
                )
                ..flushMicrotasks();
              expect(executions, hasLength(overdueAgentIds.length));

              for (final dueAt
                  in futureEntries.map((entry) => entry.value).toSet()) {
                async
                  ..elapse(dueAt.difference(clock.now()))
                  ..flushMicrotasks();

                final expectedExecuted = dueByAgent.entries
                    .where((entry) => !entry.value.isAfter(dueAt))
                    .map((entry) => entry.key)
                    .toSet();
                expect(
                  executions.toSet(),
                  expectedExecuted,
                  reason: '$scenario',
                );
                expect(executions, hasLength(expectedExecuted.length));
              }
            }

            expect(executions, hasLength(scenario.specs.length));
            for (final agentId in dueByAgent.keys) {
              expect(
                stateByAgent[agentId]?.nextWakeAt,
                isNull,
                reason: '$scenario',
              );
            }
            expect(generatedQueue.isEmpty, isTrue, reason: '$scenario');

            generatedOrchestrator.stop();
            async.flushMicrotasks();
          });
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.postRunThrottleScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'matches generated post-run nextWakeAt decision matrix',
        (scenario) {
          withClock(Clock.fixed(scenario.now), () {
            fakeAsync((async) {
              final generatedRepository = MockAgentRepository();
              final generatedQueue = WakeQueue();
              final generatedRunner = WakeRunner();
              final upsertedStates = <AgentStateEntity>[];
              var state = makeTestState(agentId: 'agent-1');

              when(
                () => generatedRepository.getAgentState(any()),
              ).thenAnswer((_) async => state);
              when(
                () => generatedRepository.upsertEntity(any()),
              ).thenAnswer((invocation) async {
                state =
                    invocation.positionalArguments.single as AgentStateEntity;
                upsertedStates.add(state);
              });
              when(
                () => generatedRepository.insertWakeRun(
                  entry: any(named: 'entry'),
                ),
              ).thenAnswer((_) async {});
              when(
                () => generatedRepository.updateWakeRunStatus(
                  any(),
                  any(),
                  completedAt: any(named: 'completedAt'),
                  errorMessage: any(named: 'errorMessage'),
                ),
              ).thenAnswer((_) async {});

              final generatedOrchestrator = WakeOrchestrator(
                repository: generatedRepository,
                queue: generatedQueue,
                runner: generatedRunner,
                wakeExecutor: noOpExecutor,
              );

              generatedQueue.enqueue(
                makeJob(
                  runKey: 'generated-post-run-main',
                  agentId: 'agent-1',
                  reason: scenario.reason,
                  triggerTokens: {'generated-post-run-main-token'},
                  createdAt: scenario.now,
                ),
              );
              if (scenario.hasFollowUp) {
                generatedQueue.enqueue(
                  WakeJob(
                    runKey: 'generated-post-run-follow-up',
                    agentId: 'agent-1',
                    reason: WakeReason.subscription.name,
                    triggerTokens: const {'generated-post-run-follow-up-token'},
                    reasonId: 'generated-post-run-follow-up-sub',
                    createdAt: scenario.now,
                    hasDirectMatch: scenario.followUpHasDirectMatch,
                  ),
                );
              }

              generatedOrchestrator.processNext();
              async.flushMicrotasks();

              final nextWakeWrites = upsertedStates
                  .map((state) => state.nextWakeAt)
                  .whereType<DateTime>()
                  .toList();
              final expectedDeadline = scenario.expectedDeadline;
              if (expectedDeadline == null) {
                expect(nextWakeWrites, isEmpty, reason: '$scenario');
                expect(generatedQueue.isEmpty, isTrue, reason: '$scenario');
              } else {
                expect(nextWakeWrites, [expectedDeadline], reason: '$scenario');
                expect(
                  generatedQueue.hasQueuedJobFor('agent-1'),
                  isTrue,
                  reason: '$scenario',
                );
                expect(
                  generatedQueue.hasDirectQueuedJobFor('agent-1'),
                  scenario.followUpHasDirectMatch,
                  reason: '$scenario',
                );
              }

              generatedOrchestrator.stop();
              async.flushMicrotasks();
            });
          });
        },
        tags: 'glados',
      );

      test('subscription wake sets throttle deadline', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Stub getAgentState for _setThrottleDeadline persistence.
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First notification enqueues job and sets throttle (deferred).
          emitTokens(async, controller, {'entity-1'});

          // No immediate execution — job is deferred.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Second notification within throttle window should be throttled
          // (tokens merged into existing job).
          emitTokens(async, controller, {'entity-1'});

          // Still no execution.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Advance past throttle — deferred drain fires, executes the
          // coalesced job.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('manual wake clears throttle and executes immediately', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First subscription notification sets throttle (deferred).
          emitTokens(async, controller, {'entity-1'});

          // No immediate execution.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Manual wake should bypass throttle.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          );
          async.flushMicrotasks();

          // Manual wake run should have been persisted.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.any((e) => e.reason == 'reanalysis'), isTrue);

          controller.close();
        });
      });

      test('throttle expires after throttleWindow elapses', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First notification sets throttle + schedules deferred drain.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 0);

          // Advance past initial throttle window — deferred drain fires
          // and executes the first wake. Execution sets a new throttle.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();
          expect(executionCount, 1);

          // Advance past the post-execution throttle window + 1s.
          async
            ..elapse(
              WakeOrchestrator.throttleWindow + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

          // Second notification should now proceed (throttle expired).
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('deferred timer fires processNext after throttle window', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Notification enqueues + defers.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 0);

          // Advance to throttle deadline — deferred timer fires.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(executionCount, 1);

          // Execution set a new throttle. Wait for it to expire.
          async
            ..elapse(
              WakeOrchestrator.throttleWindow + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

          // A new notification should now succeed (deferred again).
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('creation wake does NOT set throttle', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          // ignore: cascade_invocations
          orchestrator
            ..addSubscription(makeSub())
            ..enqueueManualWake(
              agentId: 'agent-1',
              reason: 'creation',
              triggerTokens: {'task-1'},
            );
          async
            ..flushMicrotasks()
            // Advance past the 5s suppression TTL so the subscription
            // notification is not suppressed by the confirmed suppression record
            // (which merges all subscribed IDs after the creation wake).
            ..elapse(const Duration(seconds: 6));

          // Subscription notification should still proceed (not throttled by
          // the creation wake). It will be deferred by the initial throttle.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Both the creation wake and subscription wake should have run.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(2);

          controller.close();
        });
      });

      test('removeSubscriptions clears throttle', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});

          // Remove and re-add subscription — throttle should be cleared.
          orchestrator
            ..removeSubscriptions('agent-1')
            ..addSubscription(makeSub(id: 'sub-1b'));

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          emitAndDrain(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline hydrates throttle from persisted state', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Hydrate a throttle deadline 120 seconds in the future.
          final deadline = clock.now().add(const Duration(seconds: 120));
          orchestrator.setThrottleDeadline('agent-1', deadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Notification should be throttled (no immediate execution).
          emitTokens(async, controller, {'entity-1'});
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Advance past deadline — deferred drain fires, executing the
          // throttled job.
          async
            ..elapse(const Duration(seconds: 121))
            ..flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline ignores past deadlines', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Set a past deadline — should be ignored.
          final pastDeadline = clock.now().subtract(
            const Duration(seconds: 10),
          );
          orchestrator.setThrottleDeadline('agent-1', pastDeadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Past deadline is ignored, so the agent is not pre-throttled.
          // Defer-first still applies: emit enqueues + defers, drain executes.
          emitAndDrain(async, controller, {'entity-1'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'restorePendingWake executes overdue persisted deadline immediately',
        () {
          fakeAsync((async) {
            final dueAt = clock.now().subtract(const Duration(hours: 10));
            var executionCount = 0;
            var storedState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: dueAt,
            );

            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              expect(agentId, 'agent-1');
              expect(triggers, isEmpty);
              return Future.value();
            };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => storedState);
            when(() => mockRepository.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              storedState =
                  invocation.positionalArguments.single as AgentStateEntity;
            });

            orchestrator.restorePendingWake(agentId: 'agent-1', dueAt: dueAt);
            async.flushMicrotasks();

            expect(executionCount, 1);
            expect(storedState.nextWakeAt, isNull);

            final captured = captureWakeRuns(mockRepository);
            expect(captured, hasLength(1));
            expect(captured.single.agentId, 'agent-1');
            expect(captured.single.reason, WakeReason.subscription.name);
            expect(captured.single.reasonId, 'restored_pending_wake');
            expect(captured.single.createdAt, dueAt);
          });
        },
      );

      test(
        'restorePendingWake rebuilds future queue job and drains at deadline',
        () {
          fakeAsync((async) {
            const wait = Duration(minutes: 5);
            final dueAt = clock.now().add(wait);
            var executionCount = 0;
            var storedState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: dueAt,
            );

            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              return Future.value();
            };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => storedState);
            when(() => mockRepository.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              storedState =
                  invocation.positionalArguments.single as AgentStateEntity;
            });

            orchestrator.restorePendingWake(agentId: 'agent-1', dueAt: dueAt);
            async.flushMicrotasks();

            expect(executionCount, 0);

            async
              ..elapse(wait - const Duration(milliseconds: 1))
              ..flushMicrotasks();
            expect(executionCount, 0);

            async
              ..elapse(const Duration(milliseconds: 1))
              ..flushMicrotasks();

            expect(executionCount, 1);
            expect(storedState.nextWakeAt, isNull);
            final captured = captureWakeRuns(mockRepository);
            expect(captured.single.reason, WakeReason.subscription.name);
            expect(captured.single.reasonId, 'restored_pending_wake');
          });
        },
      );

      test('stop cancels deferred drain timers', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Trigger wake (sets throttle + deferred timer).
          emitTokens(async, controller, {'entity-1'});

          // Stop the orchestrator.
          orchestrator.stop();
          async.flushMicrotasks();

          // Advance past throttle — deferred timer should NOT fire.
          clearInteractions(mockRepository);
          async
            ..elapse(WakeOrchestrator.throttleWindow * 2)
            ..flushMicrotasks();

          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('subscription wake persists throttle deadline via upsertEntity', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => existingState);
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers, drain executes and
          // _setThrottleDeadline persists the post-execution deadline.
          emitAndDrain(async, controller, {'entity-1'});

          final captured = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured.cast<AgentStateEntity>();

          // Find the persisted throttle deadline (non-null nextWakeAt).
          final withDeadline = captured
              .where((s) => s.nextWakeAt != null)
              .toList();
          expect(withDeadline, isNotEmpty);

          final persisted = withDeadline.last;
          expect(persisted.agentId, 'agent-1');

          // The persisted deadline should be ~120s from the execution time.
          expect(
            persisted.nextWakeAt!.isAfter(clock.now()) ||
                persisted.nextWakeAt!.isAtSameMomentAs(clock.now()),
            isTrue,
          );

          controller.close();
        });
      });

      test(
        'subscription wake clears nextWakeAt when no follow-up job remains',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            final writes = <AgentStateEntity>[];
            var storedState = makeTestState(
              id: 'state-agent-1',
              agentId: 'agent-1',
            );
            when(
              () => mockRepository.getAgentState(any()),
            ).thenAnswer((_) async => storedState);
            when(() => mockRepository.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              storedState =
                  invocation.positionalArguments.single as AgentStateEntity;
              writes.add(storedState);
            });

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            emitAndDrain(async, controller, {'entity-1'});

            expect(writes, hasLength(2));
            expect(writes.first.nextWakeAt, isNotNull);
            expect(writes.last.nextWakeAt, isNull);

            controller.close();
          });
        },
      );

      test(
        '_setThrottleDeadline still sets in-memory throttle on DB error',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            // getAgentState throws to simulate DB failure in persistence.
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenThrow(Exception('DB error'));

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers, drain executes.
            emitAndDrain(async, controller, {'entity-1'});

            // First wake executes despite DB error in persistence.
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            // In-memory throttle should still be active (set by
            // _setThrottleDeadline even when DB persistence fails) —
            // second notification should be merged, not executed.
            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);

            emitTokens(async, controller, {'entity-1'});
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );

            controller.close();
          });
        },
      );

      test('clearThrottle persists nextWakeAt null via upsertEntity', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => existingState);
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers; drain executes and
          // _setThrottleDeadline persists the post-execution deadline.
          emitAndDrain(async, controller, {'entity-1'});

          // Verify _setThrottleDeadline persisted a non-null deadline.
          final setCapture = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured.cast<AgentStateEntity>();
          final withDeadline = setCapture
              .where((s) => s.nextWakeAt != null)
              .toList();
          expect(withDeadline, isNotEmpty);

          // Now clear the throttle.
          clearInteractions(mockRepository);
          when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
            (_) async => existingState.copyWith(
              nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
            ),
          );
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          orchestrator.clearThrottle('agent-1');
          async.flushMicrotasks();

          // Verify _clearPersistedThrottle persisted nextWakeAt: null.
          final clearCapture = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured;
          expect(clearCapture, hasLength(1));
          expect(
            (clearCapture.first as AgentStateEntity).nextWakeAt,
            isNull,
          );

          controller.close();
        });
      });

      test(
        'clearThrottle skips upsert when new throttle set during getAgentState',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            final existingState = makeTestState(
              id: 'state-agent-1',
              agentId: 'agent-1',
            );
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => existingState);
            when(
              () => mockRepository.upsertEntity(any()),
            ).thenAnswer((_) async {});

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers; drain executes and
            // _setThrottleDeadline persists the post-execution deadline.
            emitAndDrain(async, controller, {'entity-1'});

            // Clear interactions so we can track only the clear path.
            clearInteractions(mockRepository);

            // Simulate: getAgentState completes, but during the await a new
            // throttle deadline is set (e.g. by another subscription wake).
            when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
              (_) async {
                // While the DB read is in flight, set a new throttle.
                orchestrator.setThrottleDeadline(
                  'agent-1',
                  clock.now().add(WakeOrchestrator.throttleWindow),
                );
                return existingState.copyWith(
                  nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
                );
              },
            );

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            // The post-await guard should detect the new deadline and skip
            // the upsert — no upsertEntity call for null nextWakeAt.
            verifyNever(() => mockRepository.upsertEntity(any()));

            controller.close();
          });
        },
      );

      test(
        'clearThrottle still clears in-memory state on DB write failure',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers; drain executes.
            emitAndDrain(async, controller, {'entity-1'});
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            // Advance past the 5s suppression TTL so the next entity-1
            // notification is not suppressed by the confirmed suppression record.
            async.elapse(const Duration(seconds: 6));

            // Make getAgentState throw so clearThrottle's DB write fails.
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenThrow(Exception('DB unavailable'));

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            // In-memory throttle should be cleared despite DB failure,
            // so a new subscription notification should execute after deferral.
            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            emitAndDrain(async, controller, {'entity-1'});
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            controller.close();
          });
        },
      );

      test('natural expiry clears persisted nextWakeAt', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );

          // Provide state with non-null nextWakeAt for the expiry clear.
          when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
            (_) async => existingState.copyWith(
              nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
            ),
          );
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          // Hydrate a throttle via setThrottleDeadline (no enqueued job,
          // so the deferred drain timer fires without racing execution).
          final deadline = clock.now().add(WakeOrchestrator.throttleWindow);
          orchestrator.setThrottleDeadline('agent-1', deadline);

          // Advance past the throttle window to fire the deferred timer.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Verify that _clearPersistedThrottle was called with null.
          final captured = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured;
          expect(captured, isNotEmpty);
          expect(
            (captured.last as AgentStateEntity).nextWakeAt,
            isNull,
          );
        });
      });

      test(
        'throttle applies per-agent independently',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..addSubscription(
                makeSub(
                  id: 'sub-2',
                  agentId: 'agent-2',
                  matchEntityIds: {'entity-2'},
                ),
              )
              ..wakeExecutor = noOpExecutor;

            when(
              () => mockRepository.getAgentState(any()),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Both agents execute on separate tokens.
            emitAndDrain(async, controller, {'entity-1', 'entity-2'});
            final firstBatch = captureWakeRuns(mockRepository);
            expect(firstBatch.length, 2);

            // Advance past the 5s suppression TTL so subsequent
            // notifications are not suppressed by the confirmed suppression record.
            async.elapse(const Duration(seconds: 6));

            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);

            // Both agents should be throttled now (post-execution throttle).
            // Only emit entity-1 so agent-2 (which subscribes to entity-2)
            // is not matched and doesn't enqueue during the throttle window.
            emitTokens(async, controller, {'entity-1'});
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );

            // Clear throttle for agent-1 only.
            orchestrator.clearThrottle('agent-1');

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            // Only emit entity-1 token so only agent-1 can match.
            emitAndDrain(async, controller, {'entity-1'});

            // Only agent-1 should run.
            final captured = captureWakeRuns(mockRepository);
            expect(captured.length, 1);
            expect(captured.first.agentId, 'agent-1');

            controller.close();
          });
        },
      );
    });

    group('awaiting-content cache', () {
      test(
        'setAwaitingContent suppresses throttle deadline on subscription wakes',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..setAwaitingContent('agent-1', awaiting: true)
              ..wakeExecutor = noOpExecutor;

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            emitTokens(async, controller, {'entity-1'});

            // Advance just shy of the safety-net interval. With no deferred
            // drain timer scheduled (the throttle was skipped), nothing has
            // surfaced a countdown via persisted nextWakeAt and the wake has
            // not been dispatched.
            async
              ..elapse(
                WakeOrchestrator.safetyNetInterval - const Duration(seconds: 1),
              )
              ..flushMicrotasks();

            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );
            verifyNever(
              () => mockRepository.upsertEntity(
                any(
                  that: isA<AgentStateEntity>().having(
                    (s) => s.nextWakeAt,
                    'nextWakeAt',
                    isNotNull,
                  ),
                ),
              ),
            );
            expect(orchestrator.isAwaitingContent('agent-1'), isTrue);

            controller.close();
          });
        },
      );

      test(
        'content-gate clears the cache once real content arrives',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-cache',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-cache'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-cache'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => true,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async {
                      return null;
                    },
                  )
                  ..setAwaitingContent('agent-cg-cache', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-cache',
                    reason: 'creation',
                  );

            expect(cg.isAwaitingContent('agent-cg-cache'), isTrue);

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // After the content gate finds content, the cache is cleared so
            // subsequent subscription wakes get the normal countdown again.
            expect(cg.isAwaitingContent('agent-cg-cache'), isFalse);

            cg.stop();
          });
        },
      );

      test('removeSubscriptions drops the awaiting-content entry', () {
        orchestrator
          ..addSubscription(makeSub())
          ..setAwaitingContent('agent-1', awaiting: true);

        expect(orchestrator.isAwaitingContent('agent-1'), isTrue);

        orchestrator.removeSubscriptions('agent-1');

        expect(orchestrator.isAwaitingContent('agent-1'), isFalse);
      });
    });

    group('_scheduleDeferredDrain edge cases', () {
      test(
        'setThrottleDeadline with past deadline does not throttle agent',
        () {
          fakeAsync((async) {
            var executionCount = 0;

            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Set a past deadline via public API — should be ignored so the
            // agent is not pre-throttled.
            final pastDeadline = clock.now().subtract(
              const Duration(seconds: 1),
            );
            orchestrator.setThrottleDeadline('agent-1', pastDeadline);

            // Agent should NOT be throttled; emit + drain works normally.
            emitAndDrain(async, controller, {'entity-1'});
            expect(executionCount, 1);

            controller.close();
          });
        },
      );

      test(
        'deadline at exactly clock.now() triggers immediate drain '
        'via scheduleMicrotask',
        () {
          // When setThrottleDeadline is called with deadline == clock.now(),
          // isBefore returns false so the method proceeds, but remaining is
          // Duration.zero. The fix ensures processNext is called immediately
          // via scheduleMicrotask instead of silently dropping.
          fakeAsync((async) {
            var executionCount = 0;

            orchestrator.wakeExecutor =
                (agentId, runKey, triggers, threadId) async {
                  executionCount++;
                  return null;
                };

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Directly enqueue a job so processNext has work.
            queue.enqueue(
              makeJob(runKey: 'edge-case-key', triggerTokens: {'entity-1'}),
            );

            // Set deadline to exactly now — remaining will be Duration.zero.
            // The fix should clear the throttle and schedule processNext
            // via microtask.
            orchestrator.setThrottleDeadline('agent-1', clock.now());

            // Flush the scheduleMicrotask callback.
            async.flushMicrotasks();

            // The job should have been executed via the immediate drain.
            expect(executionCount, 1);

            controller.close();
          });
        },
      );
    });

    group('safety-net periodic drain', () {
      test('safety-net timer fires processNext for stuck jobs', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Directly enqueue a "stuck" job — no deferred drain timer is
          // scheduled, simulating the failure mode the safety net catches.
          queue.enqueue(
            makeJob(runKey: 'stuck-job-key', triggerTokens: {'entity-1'}),
          );

          // Advance past the safety-net interval.
          async
            ..elapse(WakeOrchestrator.safetyNetInterval)
            ..flushMicrotasks();

          // The safety-net should have triggered processNext and executed
          // the stuck job.
          expect(executionCount, 1);

          controller.close();
        });
      });

      test('stop cancels safety-net timer', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator
            ..start(controller.stream)
            // Stop the orchestrator.
            ..stop();
          async
            ..flushMicrotasks()
            // Advance past multiple safety-net intervals.
            ..elapse(WakeOrchestrator.safetyNetInterval * 3)
            ..flushMicrotasks();

          // No execution should have occurred.
          expect(executionCount, 0);

          controller.close();
        });
      });
    });

    group('AgentSubscription', () {
      test('stores all fields correctly', () {
        bool predicateCalled(Set<String> tokens) => true;
        final sub = AgentSubscription(
          id: 'sub-1',
          agentId: 'agent-1',
          matchEntityIds: {'e-1', 'e-2'},
          predicate: predicateCalled,
        );

        expect(sub.id, 'sub-1');
        expect(sub.agentId, 'agent-1');
        expect(sub.matchEntityIds, {'e-1', 'e-2'});
        expect(sub.predicate, isNotNull);
      });

      test('predicate is optional and defaults to null', () {
        final sub = AgentSubscription(
          id: 'sub-1',
          agentId: 'agent-1',
          matchEntityIds: {'e-1'},
        );

        expect(sub.predicate, isNull);
      });
    });

    group('onPersistedStateChanged callback', () {
      test(
        'invokes callback when throttle deadline is persisted after execution',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Set<String>>.broadcast();
            final agentState = makeTestState(agentId: 'agent-1');
            final changedAgentIds = <String>[];

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => agentState);

            orchestrator =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: runner,
                    onPersistedStateChanged: changedAgentIds.add,
                  )
                  ..addSubscription(makeSub())
                  ..wakeExecutor = noOpExecutor;

            // ignore: cascade_invocations
            orchestrator.start(controller.stream);

            // First wake: triggers execution and then persists throttle deadline.
            emitAndDrain(async, controller, {'entity-1'});
            async.flushMicrotasks();

            expect(changedAgentIds, contains('agent-1'));
            controller.close();
          });
        },
      );

      test(
        'invokes callback when clearThrottle persists null nextWakeAt',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Set<String>>.broadcast();
            final changedAgentIds = <String>[];
            final agentState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: DateTime(2024),
            );

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => agentState);

            orchestrator =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: runner,
                    onPersistedStateChanged: changedAgentIds.add,
                  )
                  ..addSubscription(makeSub())
                  ..wakeExecutor = noOpExecutor;

            // ignore: cascade_invocations
            orchestrator.start(controller.stream);

            // Execute once to set a throttle deadline, then clear it.
            emitAndDrain(async, controller, {'entity-1'});
            async.flushMicrotasks();

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            expect(changedAgentIds, contains('agent-1'));
            controller.close();
          });
        },
      );
    });

    group('enqueueManualWake', () {
      test('clears pending subscription jobs for agent', () {
        fakeAsync((async) {
          final controller = StreamController<Set<String>>.broadcast();
          final executedRunKeys = <String>[];

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, tokens, threadId) async {
              executedRunKeys.add(runKey);
              return null;
            };

          // ignore: cascade_invocations
          orchestrator.start(controller.stream);

          // Emit a notification to enqueue a subscription job
          emitTokens(async, controller, {'entity-1'});

          // Queue should have the subscription job
          expect(queue.isEmpty, isFalse);

          // Manual wake supersedes the subscription job.
          // enqueueManualWake calls removeByAgent (clearing the subscription
          // job) then enqueues a manual job and calls processNext.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'user_trigger',
          );
          async.flushMicrotasks();

          // Only one execution should have occurred (the manual wake),
          // not the subscription job. The manual wake's processNext
          // consumes the manual job.
          expect(executedRunKeys, hasLength(1));

          // The deferred drain should not fire the removed subscription job
          // when the throttle window elapses.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Still only one execution — the subscription job was removed.
          expect(executedRunKeys, hasLength(1));

          controller.close();
        });
      });
    });

    group('stale drain recovery (Fix B)', () {
      test('force-resets stale drain and new drain supersedes old one '
          'via generation counter', () {
        fakeAsync((async) {
          final stuckCompleter = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];

          orchestrator
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              // First call hangs; subsequent ones complete immediately.
              if (agentId == 'stuck-agent') return stuckCompleter.future;
              return Future.value();
            }
            ..addSubscription(
              makeSub(
                id: 'sub-stuck',
                agentId: 'stuck-agent',
                matchEntityIds: {'entity-stuck'},
              ),
            )
            ..addSubscription(
              makeSub(
                id: 'sub-ok',
                agentId: 'ok-agent',
                matchEntityIds: {'entity-ok'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Trigger the stuck agent — deferred drain starts after throttle.
          emitAndDrain(async, controller, {'entity-stuck'});

          // The executor is now awaiting the stuckCompleter.
          expect(executedAgentIds, contains('stuck-agent'));

          // Advance past the 5-minute drain timeout.
          async
            ..elapse(const Duration(minutes: 6))
            ..flushMicrotasks();

          // Now trigger ok-agent. processNext should detect the stale drain,
          // force-reset it, and start a new drain for ok-agent.
          emitAndDrain(async, controller, {'entity-ok'});

          expect(executedAgentIds, contains('ok-agent'));

          // Complete the stuck executor so the old drain can finish its
          // finally block.
          stuckCompleter.complete(null);
          async.flushMicrotasks();

          // The orchestrator should be in a clean state — not stuck.
          // Verify by enqueuing another manual wake and seeing it execute.
          executedAgentIds.clear();
          orchestrator.enqueueManualWake(
            agentId: 'ok-agent',
            reason: 'test',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, contains('ok-agent'));

          controller.close();
        });
      });

      test('does not force-reset when drain is within timeout window', () {
        fakeAsync((async) {
          final stuckCompleter = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              if (agentId == 'stuck-agent') return stuckCompleter.future;
              return Future.value();
            }
            ..addSubscription(
              makeSub(
                id: 'sub-stuck',
                agentId: 'stuck-agent',
                matchEntityIds: {'entity-stuck'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Trigger stuck agent.
          emitAndDrain(async, controller, {'entity-stuck'});
          expect(executionCount, 1);

          // Advance 60 seconds — well within both the 5-minute drain
          // stale-lock window and the per-cycle wakeRunMaxDuration cap, so
          // the stuck executor is still in flight.
          async.elapse(const Duration(seconds: 60));

          // Enqueue a manual wake — should set _drainRequested, not
          // force-reset.
          orchestrator.enqueueManualWake(
            agentId: 'stuck-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();

          // No new execution should have happened (drain is still stuck,
          // the manual wake is queued for when the drain loops back).
          expect(executionCount, 1);

          // Clean up.
          stuckCompleter.complete(null);
          async.flushMicrotasks();

          controller.close();
        });
      });
    });
  });

  group('_drain(generation) bail-out', () {
    test('old drain bails out when generation changes during iteration', () {
      fakeAsync((async) {
        final stuckCompleter = Completer<Map<String, VectorClock>?>();
        final executedAgentIds = <String>[];

        orchestrator
          ..wakeExecutor = (agentId, runKey, triggers, threadId) {
            executedAgentIds.add(agentId);
            if (agentId == 'slow-agent') return stuckCompleter.future;
            return Future.value();
          }
          ..addSubscription(
            makeSub(
              id: 'sub-slow',
              agentId: 'slow-agent',
              matchEntityIds: {'entity-slow'},
            ),
          )
          ..addSubscription(
            makeSub(
              id: 'sub-ok',
              agentId: 'ok-agent',
              matchEntityIds: {'entity-ok'},
            ),
          );

        final controller = StreamController<Set<String>>.broadcast();
        orchestrator.start(controller.stream);

        // Trigger slow-agent — drain starts, executor blocks.
        emitAndDrain(async, controller, {'entity-slow'});
        expect(executedAgentIds, contains('slow-agent'));

        // Advance past the 5-minute drain timeout.
        async
          ..elapse(const Duration(minutes: 6))
          ..flushMicrotasks();

        // Trigger ok-agent — force-resets stale drain (increments
        // generation) and starts a new drain.
        emitAndDrain(async, controller, {'entity-ok'});
        expect(executedAgentIds, contains('ok-agent'));

        // Complete the stuck executor — the old _drain resumes, loops
        // back to while(true), checks generation, and bails out via
        // `if (_drainGeneration != generation) return`.
        stuckCompleter.complete(null);
        async.flushMicrotasks();

        // Verify the orchestrator is in a clean state.
        executedAgentIds.clear();
        orchestrator.enqueueManualWake(
          agentId: 'ok-agent',
          reason: 'test',
        );
        async.flushMicrotasks();
        expect(executedAgentIds, contains('ok-agent'));

        controller.close();
      });
    });
  });

  group('domain logging integration', () {
    test('_logError delegates to domainLogger when present', () {
      fakeAsync((async) {
        final mockDomainLogger = MockDomainLogger();
        when(
          () => mockDomainLogger.error(
            any(),
            any(),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final loggedRepo = MockAgentRepository();
        final loggedQueue = WakeQueue();
        final loggedRunner = WakeRunner();

        when(
          () => loggedRepo.insertWakeRun(entry: any(named: 'entry')),
        ).thenAnswer((_) async => throw Exception('DB fail'));
        when(
          () => loggedRepo.updateWakeRunStatus(
            any(),
            any(),
            completedAt: any(named: 'completedAt'),
            errorMessage: any(named: 'errorMessage'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => loggedRepo.getAgentState(any()),
        ).thenAnswer((_) async => null);

        final loggedOrchestrator = WakeOrchestrator(
          repository: loggedRepo,
          queue: loggedQueue,
          runner: loggedRunner,
          domainLogger: mockDomainLogger,
        );

        loggedQueue.enqueue(
          makeJob(
            runKey: 'rk-err',
            agentId: 'agent-err',
            reason: 'manual',
            triggerTokens: {'tok'},
          ),
        );

        loggedOrchestrator.processNext();
        async.flushMicrotasks();

        verify(
          () => mockDomainLogger.error(
            LogDomains.agentRuntime,
            any(that: contains('insertWakeRun failed')),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);

        loggedOrchestrator.stop();
      });
    });

    group('content gating', () {
      test(
        'skips wake when agent is awaitingContent and task has no content',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-1'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg'),
            ).thenAnswer((_) async => state);

            var wakeExecuted = false;
            final cg =
                WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async => false,
                  wakeExecutor: (agentId, runKey, triggers, threadId) async {
                    wakeExecuted = true;
                    return null;
                  },
                )..enqueueManualWake(
                  agentId: 'agent-cg',
                  reason: 'creation',
                );
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(wakeExecuted, isFalse);

            cg.stop();
          });
        },
      );

      test('allows wake and clears flag when task has content', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg2',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-2'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg2'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => true,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg2',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          // Verify awaitingContent was cleared via raw repository (no
          // syncEntityWriter provided).
          verify(
            () => mockRepository.upsertEntity(
              any(
                that: isA<AgentStateEntity>().having(
                  (s) => s.awaitingContent,
                  'awaitingContent',
                  isFalse,
                ),
              ),
            ),
          ).called(1);

          cg.stop();
        });
      });

      test('uses syncEntityWriter instead of raw repository when provided', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg-sync',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-sync'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg-sync'),
          ).thenAnswer((_) async => state);

          AgentDomainEntity? writtenEntity;
          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => true,
                syncEntityWriter: (entity) async {
                  writtenEntity = entity;
                },
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg-sync',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          // syncEntityWriter was called with the cleared state.
          expect(writtenEntity, isA<AgentStateEntity>());
          final cleared = writtenEntity! as AgentStateEntity;
          expect(cleared.awaitingContent, isFalse);
          expect(cleared.agentId, 'agent-cg-sync');

          // Raw repository.upsertEntity should NOT have been called for the
          // content-gate clearing (it may be called for other purposes like
          // wake-run status updates, so we verify the specific entity was not
          // passed to it).
          verifyNever(
            () => mockRepository.upsertEntity(
              any(
                that: isA<AgentStateEntity>().having(
                  (s) => s.awaitingContent,
                  'awaitingContent',
                  isFalse,
                ),
              ),
            ),
          );

          cg.stop();
        });
      });

      test('proceeds normally when awaitingContent is false', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg3',
            slots: const AgentSlots(activeTaskId: 'task-3'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg3'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => false,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg3',
                reason: 'subscription',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test('proceeds when taskContentChecker is null', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg4',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-4'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg4'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                // taskContentChecker is null
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg4',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // No checker → cannot gate, so wake proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test('proceeds when content check throws (fail-open)', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg5',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-5'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg5'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async =>
                    throw Exception('DB error'),
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg5',
                reason: 'subscription',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Error → fail-open, wake proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test(
        'proceeds and logs completed run when taskContentChecker throws',
        () {
          fakeAsync((async) {
            final capturedEntries = stubInsertCapture(mockRepository);

            final state = makeTestState(
              agentId: 'agent-cg-throw',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-throw'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-throw'),
            ).thenAnswer((_) async => state);

            String? executedAgentId;
            final cg =
                WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async =>
                      throw StateError('unexpected DB failure'),
                  wakeExecutor: (agentId, runKey, triggers, threadId) async {
                    executedAgentId = agentId;
                    return null;
                  },
                )..enqueueManualWake(
                  agentId: 'agent-cg-throw',
                  reason: 'creation',
                );
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // The wake must execute despite the checker throwing.
            expect(executedAgentId, 'agent-cg-throw');

            // A wake run log entry was persisted for the agent.
            expect(capturedEntries, hasLength(1));
            expect(capturedEntries.first.agentId, 'agent-cg-throw');

            // The run completed successfully (not marked as failed).
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                'completed',
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).called(1);

            cg.stop();
          });
        },
      );

      test('proceeds when state has no activeTaskId', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg6',
            awaitingContent: true,
            // No activeTaskId
          );
          when(
            () => mockRepository.getAgentState('agent-cg6'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => false,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg6',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // No activeTaskId → cannot check content → proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test(
        'drops mirror when persisted state shows the agent is no longer '
        'awaiting content',
        () {
          fakeAsync((async) {
            // Simulate a divergence: the in-memory mirror still says
            // awaiting, but the persisted state has been cleared (e.g.,
            // by another device via sync). The gate must drop the mirror
            // so future notifications surface the normal countdown.
            final clearedState = makeTestState(
              agentId: 'agent-cg-stale',
              slots: const AgentSlots(activeTaskId: 'task-stale'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-stale'),
            ).thenAnswer((_) async => clearedState);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => true,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-stale', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-stale',
                    reason: 'subscription',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(cg.isAwaitingContent('agent-cg-stale'), isFalse);

            cg.stop();
          });
        },
      );

      test('drops mirror when no agent state is persisted', () {
        fakeAsync((async) {
          when(
            () => mockRepository.getAgentState('agent-cg-missing'),
          ).thenAnswer((_) async => null);

          final cg =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async => true,
                  wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                      null,
                )
                ..setAwaitingContent('agent-cg-missing', awaiting: true)
                ..enqueueManualWake(
                  agentId: 'agent-cg-missing',
                  reason: 'subscription',
                );

          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(cg.isAwaitingContent('agent-cg-missing'), isFalse);

          cg.stop();
        });
      });

      test(
        'drops mirror when awaiting flag is set but no activeTaskId can '
        'be gated on',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-no-task',
              awaitingContent: true,
            );
            when(
              () => mockRepository.getAgentState('agent-cg-no-task'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => false,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-no-task', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-no-task',
                    reason: 'creation',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(cg.isAwaitingContent('agent-cg-no-task'), isFalse);

            cg.stop();
          });
        },
      );

      test(
        'leaves mirror untouched when taskContentChecker is null (fail-open)',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-fail-open',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-fail-open'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-fail-open'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    // taskContentChecker is null
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-fail-open', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-fail-open',
                    reason: 'subscription',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // Indeterminate path — persisted flag still says awaiting, so
            // the mirror should remain so that countdown suppression keeps
            // matching the persisted truth.
            expect(cg.isAwaitingContent('agent-cg-fail-open'), isTrue);

            cg.stop();
          });
        },
      );
    });

    group('agent execution zone', () {
      test('executor runs inside agent execution zone '
          '(isAgentExecution is true)', () {
        fakeAsync((async) {
          bool? capturedIsAgentExecution;

          orchestrator
            ..addSubscription(
              makeSub(
                id: 'sub-zone',
                agentId: 'agent-zone',
                matchEntityIds: {'entity-zone'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              capturedIsAgentExecution = isAgentExecution;
              return null;
            };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-zone'});

          expect(
            capturedIsAgentExecution,
            isTrue,
            reason: 'The executor should run inside the agent execution zone',
          );

          controller.close();
        });
      });

      test('isAgentExecution is false outside of executor', () {
        // Verify that outside the executor context, the zone flag is false.
        expect(isAgentExecution, isFalse);
      });
    });

    group('abort and timeout', () {
      test(
        'abortRunningWake signals an in-flight executor and marks the run aborted',
        () {
          fakeAsync((async) {
            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) =>
                gate.future;

            queue.enqueue(makeJob());
            unawaited(orchestrator.processNext());
            async.flushMicrotasks();

            expect(runner.isRunning('agent-1'), isTrue);

            final aborted = orchestrator.abortRunningWake('agent-1');
            async.flushMicrotasks();

            expect(aborted, isTrue);
            expect(runner.isRunning('agent-1'), isFalse);

            // The wake-run row was finalised with status `aborted` and the
            // 'cancelled' error message (timeout would set 'timeout').
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                WakeRunStatus.aborted.name,
                completedAt: any(named: 'completedAt'),
                errorMessage: 'cancelled',
              ),
            ).called(1);

            // Reset the recorded interactions so we can assert that the
            // late-arriving executor result is fully ignored — no second
            // `updateWakeRunStatus` call (would re-classify as completed),
            // no fresh entity writes, no other repository activity.
            clearInteractions(mockRepository);

            // Even though we stopped awaiting it, the underlying future is
            // still pending — completing it now must not throw or re-mutate
            // suppression state.
            gate.complete(const {});
            async.flushMicrotasks();

            verifyNever(
              () => mockRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            );
            verifyNever(() => mockRepository.upsertEntity(any()));
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );
          });
        },
      );

      test(
        'wakeRunMaxDuration fires an automatic abort when the executor stalls',
        () {
          fakeAsync((async) {
            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) =>
                gate.future;

            queue.enqueue(makeJob());
            unawaited(orchestrator.processNext());
            async.flushMicrotasks();
            expect(runner.isRunning('agent-1'), isTrue);

            // Advance just under the cap — still running.
            async
              ..elapse(
                WakeOrchestrator.wakeRunMaxDuration -
                    const Duration(seconds: 1),
              )
              ..flushMicrotasks();
            expect(runner.isRunning('agent-1'), isTrue);

            // Cross the cap — timer fires the abort signal.
            async
              ..elapse(const Duration(seconds: 2))
              ..flushMicrotasks();

            expect(runner.isRunning('agent-1'), isFalse);
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                WakeRunStatus.aborted.name,
                completedAt: any(named: 'completedAt'),
                errorMessage: 'timeout',
              ),
            ).called(1);

            gate.complete(const {});
            async.flushMicrotasks();
          });
        },
      );

      test(
        'abortRunningWake on an idle agent returns false and does not '
        'persist a wake-run row',
        () {
          fakeAsync((async) {
            final aborted = orchestrator.abortRunningWake('agent-cold');
            async.flushMicrotasks();

            expect(aborted, isFalse);
            verifyNever(
              () => mockRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            );
          });
        },
      );
    });

    group('propagated subscription deferral (next 06:00)', () {
      test(
        'a propagated-only match defers nextWakeAt to the next 06:00 '
        'instead of the standard 120 s throttle window',
        () {
          // Pin the wall clock so the next-06:00 calculation is
          // deterministic regardless of when the test runs.
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-parent'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Only the propagated form is in the batch — the agent's
              // entity wasn't directly edited; a child of it was.
              emitTokens(async, controller, {
                propagatedNotification('task-parent'),
              });

              // The persisted nextWakeAt should be tomorrow 06:00 (since
              // the pinned clock is past 06:00 today), NOT now + 120 s.
              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                DateTime(2026, 5, 11, 6),
                reason: 'propagated-only match must defer to the next 06:00',
              );
            });
          });
        },
      );

      test(
        'a task-agent propagated match can opt out of the 06:00 deferral '
        'and use the standard 120 s throttle window',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(
                    matchEntityIds: {'task-child-update'},
                    deferPropagatedMatches: false,
                  ),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              emitTokens(async, controller, {
                propagatedNotification('task-child-update'),
              });

              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                now.add(const Duration(seconds: 120)),
                reason:
                    'task-agent child updates should refresh on the normal '
                    'coalesced wake path, not wait until 06:00',
              );
              expect(queue.hasDirectQueuedJobFor('agent-1'), isTrue);
            });
          });
        },
      );

      test(
        'a direct match keeps the existing 120 s throttle window even when '
        'an unrelated propagated token sits alongside it in the same batch',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-direct'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Direct token matches this subscription; the unrelated
              // propagated token must not switch deferral to morning mode
              // for the matched subscription.
              emitTokens(async, controller, {
                'task-direct',
                propagatedNotification('task-unrelated'),
              });

              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                now.add(const Duration(seconds: 120)),
              );
            });
          });
        },
      );

      test(
        'when the same id appears as both bare and propagated, the match '
        'is treated as propagated (the legacy bare emission accompanies '
        'the parent fan-out and must not collapse the deferral)',
        () {
          final now = DateTime(2026, 5, 10, 3, 15);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-mixed'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              emitTokens(async, controller, {
                'task-mixed',
                propagatedNotification('task-mixed'),
              });

              // Pinned clock is before 06:00 today, so morning deferral
              // resolves to today's 06:00 (not tomorrow's).
              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(state.nextWakeAt, DateTime(2026, 5, 10, 6));
            });
          });
        },
      );

      test(
        'a direct edit arriving on top of a propagated-only morning '
        'deferral escalates the throttle deadline back to now+120s — '
        "the user's edit must not sit waiting until 06:00",
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-escalate'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // 1. Propagated-only batch arms a morning-deferred deadline.
              emitTokens(async, controller, {
                propagatedNotification('task-escalate'),
              });

              final firstCapture =
                  verify(
                        () => mockRepository.upsertEntity(captureAny()),
                      ).captured.last
                      as AgentStateEntity;
              expect(firstCapture.nextWakeAt, DateTime(2026, 5, 11, 6));

              // 2. Direct edit arrives while still deferred — must
              //    escalate to now + 120 s.
              emitTokens(async, controller, {'task-escalate'});

              final escalated =
                  verify(
                        () => mockRepository.upsertEntity(captureAny()),
                      ).captured.last
                      as AgentStateEntity;
              expect(
                escalated.nextWakeAt,
                now.add(const Duration(seconds: 120)),
                reason:
                    'a direct match coalescing onto a morning-deferred '
                    'job must reset the throttle to the 120 s window',
              );

              // The queued job's provenance must also flip to direct so
              // the post-execution throttle and any later drain pick the
              // immediate path.
              expect(queue.hasDirectQueuedJobFor('agent-1'), isTrue);
            });
          });
        },
      );

      test(
        'post-execution throttle defers to next 06:00 when only '
        'propagated-only jobs are queued during the run — a fan-out that '
        'arrives mid-execution must not coast in on a 120 s drain',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              final gate = Completer<Map<String, VectorClock>?>();
              orchestrator
                ..wakeExecutor = ((agentId, runKey, triggers, threadId) =>
                    gate.future)
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-postexec'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          revision: 0,
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              // Drive the executor mid-flight by direct-enqueuing a job
              // (bypasses the _onBatch deferral) so the running flag is
              // set before our propagated batch arrives.
              queue.enqueue(
                makeJob(
                  triggerTokens: {'task-postexec'},
                  // ignore: avoid_redundant_argument_values
                  runKey: 'rk-1',
                ),
              );
              unawaited(orchestrator.processNext());
              async.flushMicrotasks();
              expect(runner.isRunning('agent-1'), isTrue);

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Propagated-only batch arrives during execution → queued
              // with hasDirectMatch=false.
              emitTokens(async, controller, {
                propagatedNotification('task-postexec'),
              });
              expect(queue.hasDirectQueuedJobFor('agent-1'), isFalse);

              // Finish execution. The post-execution throttle must use
              // morning, not 120 s.
              gate.complete(const {});
              async.flushMicrotasks();

              final captured =
                  verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.whereType<AgentStateEntity>().lastWhere(
                    (s) => s.nextWakeAt != null,
                  );
              expect(captured.nextWakeAt, DateTime(2026, 5, 11, 6));
            });
          });
        },
      );
    });
  });
}
