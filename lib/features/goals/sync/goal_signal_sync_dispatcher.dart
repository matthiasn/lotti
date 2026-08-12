import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Bridges the sync blind spot for goal signals (ADR 0054 Decision 4).
///
/// `WakeOrchestrator` deliberately listens to `localUpdateStream` only —
/// synced writes must not wake LLM tiers. Bounded observations run goal
/// *Phase A* directly because it is deterministic and idempotent (keyed
/// registers). High-frequency category-time mutations only advance the
/// receiving agent's report-stale watermark; cadence or Update now consumes
/// them later. Phase B is never triggered from here: if Phase A finds an
/// LLM-worthy transition it arms the escalation wake, and the scheduled-wake
/// manager's lease election picks exactly one device.
class GoalSignalSyncDispatcher {
  GoalSignalSyncDispatcher({
    required this._agentService,
    required this._repository,
    required this._phaseA,
    this._domainLogger,
    this._onAgentEvaluated,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final GoalAgentPhaseA _phaseA;
  final DomainLogger? _domainLogger;

  /// Phase A writes go through the sync service, which emits no UI
  /// notification — the health projections would otherwise show stale
  /// attainment until an unrelated event.
  final void Function(String agentId)? _onAgentEvaluated;

  /// Per-agent single flight: a burst of synced batches must not stack
  /// concurrent evaluations of the same goal.
  final _inFlight = <String>{};

  /// Applies every goal agent's matching synced-signal policy.
  ///
  /// Bounded signals run Phase A; category-time signals mark the report stale
  /// without a wake. Never throws: each agent is contained individually so one
  /// corrupt goal cannot suppress updates for unrelated goals.
  Future<void> dispatchBatch(Set<String> tokens) async {
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _agentService.listAgents(
        lifecycle: AgentLifecycle.active,
      );
    } catch (error, stackTrace) {
      _log('listing agents for a synced batch failed', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      if (identity.kind != AgentKinds.goalAgent) continue;
      if (_inFlight.contains(identity.agentId)) continue;
      _inFlight.add(identity.agentId);
      try {
        final matched = await _matchedTokens(identity.agentId, tokens);
        if (matched.immediate.isEmpty && matched.stale.isEmpty) continue;
        if (matched.stale.isNotEmpty) {
          await _agentService.markReportStale(identity.agentId);
        }
        if (matched.immediate.isNotEmpty) {
          final runKey =
              'goal-sync:${identity.agentId}:'
              '${clock.now().millisecondsSinceEpoch}';
          await _phaseA.execute(
            agentIdentity: identity,
            runKey: runKey,
            triggerTokens: matched.immediate,
            threadId: runKey,
          );
          _onAgentEvaluated?.call(identity.agentId);
        }
      } catch (error, stackTrace) {
        _log(
          'goal signal sync dispatch failed for one agent',
          error,
          stackTrace,
        );
      } finally {
        _inFlight.remove(identity.agentId);
      }
    }
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    _domainLogger?.error(
      LogDomain.sync,
      error,
      message: message,
      stackTrace: stackTrace,
    );
  }

  Future<_GoalSignalMatches> _matchedTokens(
    String agentId,
    Set<String> tokens,
  ) async {
    final head = await _repository.getEntity(goalSpecHeadId(agentId));
    if (head is! GoalSpecHeadEntity) return const _GoalSignalMatches();
    final version = await _repository.getEntity(head.versionId);
    if (version is! GoalSpecVersionEntity) {
      return const _GoalSignalMatches();
    }
    final immediate = {
      // A synced HEAD is itself a signal: after disconnected approvals
      // settle, the register may have resolved to the other version —
      // one immediate €0 recompute realigns health with the standing
      // spec instead of waiting for the next cadence tick.
      if (tokens.contains(goalSpecHeadId(agentId))) goalSpecHeadId(agentId),
      // The head-dominance path in the sync processor returns before
      // emitting the head id (only agent-level tokens arrive), so a
      // batch touching this agent also forces a recompute whenever the
      // freshest register disagrees with the standing head.
      if (tokens.contains(agentId) &&
          await _registerMisaligned(agentId, version.id))
        goalSpecHeadId(agentId),
      // Category-time mutations are high-frequency observations. They never
      // run Phase A here; the separate stale intersection below advances the
      // receiving device's watermark so late journal delivery cannot leave a
      // newly refreshed report looking current. Bounded signals remain
      // immediate on every device.
      ...goalImmediateSignalTriggerTokens(
        version.criteria,
      ).intersection(tokens),
    };
    final stale = goalStaleSignalTriggerTokens(
      version.criteria,
    ).intersection(tokens);
    return _GoalSignalMatches(immediate: immediate, stale: stale);
  }

  /// Whether the newest progress register was computed under a version
  /// other than the standing head — the split-brain residue one €0
  /// recompute repairs.
  Future<bool> _registerMisaligned(String agentId, String versionId) async {
    final registers =
        (await _repository.getEntitiesByAgentId(
              agentId,
              type: AgentEntityTypes.goalProgress,
            ))
            .whereType<GoalProgressEntity>()
            .where((row) => row.deletedAt == null)
            .toList()
          ..sort((a, b) => b.periodKey.compareTo(a.periodKey));
    final latest = registers.firstOrNull;
    return latest != null && latest.specVersionId != versionId;
  }
}

class _GoalSignalMatches {
  const _GoalSignalMatches({
    this.immediate = const {},
    this.stale = const {},
  });

  final Set<String> immediate;
  final Set<String> stale;
}

/// App-lifetime subscription pumping synced batches into the dispatcher
/// (the `SyncedAudioInferenceListener` pattern: `asyncMap` serializes
/// batches; the 1-second sync batching window is the debounce).
class GoalSignalSyncListener {
  GoalSignalSyncListener({
    required this._updateNotifications,
    required this._dispatcher,
    this._domainLogger,
  });

  final UpdateNotifications _updateNotifications;
  final GoalSignalSyncDispatcher _dispatcher;
  final DomainLogger? _domainLogger;
  StreamSubscription<void>? _subscription;

  void start() {
    _subscription ??= _updateNotifications.syncUpdateStream
        .asyncMap(_dispatcher.dispatchBatch)
        .listen(
          (_) {},
          // A stream error must be visible, not a silent end of synced
          // goal evaluation for the rest of the app lifetime.
          onError: (Object error, StackTrace stackTrace) =>
              _domainLogger?.error(
                LogDomain.sync,
                error,
                message: 'goal signal sync stream errored',
                stackTrace: stackTrace,
              ),
        );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
