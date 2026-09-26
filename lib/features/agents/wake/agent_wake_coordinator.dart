import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/domain_logging.dart';

/// Computes the digest of the state a wake of `agentId` would read, or `null`
/// when the agent does not take part in coordination (its kind has no state
/// digest, or the state cannot be resolved). A `null` digest always proceeds.
typedef WakeStateDigester = Future<String?> Function(String agentId);

/// Sends one coordination broadcast to every peer (the sync outbox).
typedef WakeCoordinationSender = Future<void> Function(SyncMessage message);

/// What the drain should do with a wake job, decided by
/// [AgentWakeCoordinator.evaluate].
sealed class WakeCoordinationDecision {
  const WakeCoordinationDecision();
}

/// Run the wake. [stateHash] is the digest to claim, or `null` when the wake
/// takes no part in coordination.
final class WakeCoordinationProceed extends WakeCoordinationDecision {
  const WakeCoordinationProceed(this.stateHash);

  final String? stateHash;
}

/// A peer is running a wake over the same state: keep the job queued. The
/// coordinator asks for a drain when the claim ends or lapses.
final class WakeCoordinationDefer extends WakeCoordinationDecision {
  const WakeCoordinationDefer({required this.peerHostId, required this.until});

  final String peerHostId;

  /// When the peer's claim lapses unless another message re-arms it.
  final DateTime until;
}

/// A peer already completed a wake over exactly this state: drop the job, its
/// triggers are covered.
final class WakeCoordinationCancel extends WakeCoordinationDecision {
  const WakeCoordinationCancel({
    required this.peerHostId,
    required this.stateHash,
  });

  final String peerHostId;
  final String stateHash;
}

/// Cross-device coordination of agent wakes: of several devices about to run
/// the same agent over the same state, one runs and the others stand down.
///
/// The protocol, and the properties TLC checks for it, are
/// `specs/tla/AgentWakeCoordination.tla`; each method names the action it
/// implements.
///
/// - [claim] (`Dispatch`) broadcasts that this device runs a wake over a state
///   digest, and repeats it every [heartbeatInterval] (`Beat`) while the run
///   is live, because a run may outlast [coordinationTimeout].
/// - [complete] (`Complete`) broadcasts `done`; [settle] (`Fail`) broadcasts
///   `release` for a run that ended any other way.
/// - [onMessage] (`Deliver`) records a peer's claim, re-arming its timer on
///   every message, and remembers the digests of the peer's completed runs
///   apart from its live claim, so its next claim cannot erase them.
/// - [evaluate] returns cancel when a peer completed a run over this state
///   (`Cancel`), defer while a live peer claim matches it, and proceed
///   otherwise — a digest mismatch is new work.
///
/// All state is in memory and device-local: a process restart forgets the
/// peers' claims (`Crash`), which can only cost a duplicate run, never a lost
/// one.
class AgentWakeCoordinator with AgentErrorLogging {
  AgentWakeCoordinator({
    required this._digestState,
    required this._send,
    required this._localHostId,
    this.domainLogger,
  });

  /// How long a peer's claim holds a matching wake back after its last
  /// message. Any message from that peer about the agent re-arms it.
  static const coordinationTimeout = Duration(minutes: 2);

  /// How often a live run repeats its claim. The model requires
  /// `coordinationTimeout > heartbeatInterval + delivery delay`, so this
  /// leaves 75 seconds for a heartbeat to arrive.
  static const heartbeatInterval = Duration(seconds: 45);

  /// How many completed-run digests are kept per peer and agent. A device
  /// behind its peer may still match an older one.
  static const doneHistoryLimit = 8;

  final WakeStateDigester _digestState;
  final WakeCoordinationSender _send;
  final Future<String?> Function() _localHostId;

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;

  /// Called with an agent id whenever a peer's claim for it ends, lapses or
  /// is replaced by a claim over another digest — every event that can free
  /// a deferred job — so deferred jobs are drained again. Set by the
  /// orchestrator.
  void Function(String agentId)? onPeerStateChanged;

  final _peers = <String, Map<String, _PeerView>>{};
  final _runs = <String, _LocalRun>{};
  Future<void> _sendChain = Future<void>.value();

  void _log(String message) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      message,
      subDomain: 'coordination',
    );
  }

  /// Decides whether a wake of [agentId] may run now. [deferrable] is false
  /// for a wake the user asked for explicitly, which always runs (it still
  /// claims, so peers defer to it).
  Future<WakeCoordinationDecision> evaluate(
    String agentId, {
    bool deferrable = true,
  }) async {
    String? stateHash;
    try {
      stateHash = await _digestState(agentId);
    } catch (error, stackTrace) {
      // Coordination only ever saves work; failing open costs a duplicate.
      logError(
        'state digest failed; wake proceeds uncoordinated',
        error: error,
        stackTrace: stackTrace,
      );
      return const WakeCoordinationProceed(null);
    }
    if (stateHash == null || !deferrable) {
      return WakeCoordinationProceed(stateHash);
    }

    final peers = _peers[agentId] ?? const <String, _PeerView>{};
    for (final MapEntry(key: host, value: view) in peers.entries) {
      if (view.done.contains(stateHash)) {
        _log(
          'cancel ${DomainLogger.sanitizeId(agentId)}: '
          'peer ${DomainLogger.sanitizeId(host)} completed this state',
        );
        return WakeCoordinationCancel(peerHostId: host, stateHash: stateHash);
      }
    }
    final now = clock.now();
    for (final MapEntry(key: host, value: view) in peers.entries) {
      final expiresAt = view.claimExpiresAt;
      if (view.claimHash == stateHash &&
          expiresAt != null &&
          now.isBefore(expiresAt)) {
        _log(
          'defer ${DomainLogger.sanitizeId(agentId)}: '
          'peer ${DomainLogger.sanitizeId(host)} is running this state',
        );
        return WakeCoordinationDefer(peerHostId: host, until: expiresAt);
      }
    }
    return WakeCoordinationProceed(stateHash);
  }

  /// Announces that run [runKey] of [agentId] is starting over [stateHash]
  /// and keeps announcing it until [complete] or [settle]. A `null` digest
  /// announces nothing.
  void claim({
    required String agentId,
    required String runKey,
    required String? stateHash,
  }) {
    if (stateHash == null) return;
    _runs.remove(runKey)?.heartbeat.cancel();
    void announce() => _broadcast(
      agentId: agentId,
      runKey: runKey,
      stateHash: stateHash,
      kind: AgentWakeCoordinationKind.claim,
    );
    _runs[runKey] = _LocalRun(
      agentId: agentId,
      stateHash: stateHash,
      heartbeat: Timer.periodic(heartbeatInterval, (_) => announce()),
    );
    announce();
  }

  /// Announces that run [runKey] completed successfully.
  void complete(String runKey) =>
      _finish(runKey, AgentWakeCoordinationKind.done);

  /// Ends run [runKey] however it ended. After [complete] this is a no-op;
  /// otherwise the run failed, was aborted or never reached its executor, and
  /// peers are released at once instead of waiting out the timer.
  void settle(String runKey) =>
      _finish(runKey, AgentWakeCoordinationKind.release);

  void _finish(String runKey, AgentWakeCoordinationKind kind) {
    final run = _runs.remove(runKey);
    if (run == null) return;
    run.heartbeat.cancel();
    _broadcast(
      agentId: run.agentId,
      runKey: runKey,
      stateHash: run.stateHash,
      kind: kind,
    );
  }

  void _broadcast({
    required String agentId,
    required String runKey,
    required String stateHash,
    required AgentWakeCoordinationKind kind,
  }) {
    final sentAt = clock.now();
    // Chained, so this device's messages reach the outbox in the order they
    // were issued: the model's channels are FIFO.
    _sendChain = _sendChain.then((_) async {
      try {
        final hostId = await _localHostId();
        if (hostId == null) return;
        await _send(
          SyncMessage.agentWakeCoordination(
            agentId: agentId,
            kind: kind,
            stateHash: stateHash,
            runKey: runKey,
            hostId: hostId,
            sentAt: sentAt,
          ),
        );
      } catch (error, stackTrace) {
        logError(
          'failed to broadcast wake ${kind.name}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
  }

  /// Applies a peer's broadcast. Messages from one peer about one agent are
  /// applied in the order they were sent; an older one is dropped.
  void onMessage(SyncAgentWakeCoordination message) {
    final view = (_peers[message.agentId] ??= {})[message.hostId] ??=
        _PeerView();
    final lastSentAt = view.lastSentAt;
    if (lastSentAt != null && message.sentAt.isBefore(lastSentAt)) return;
    view.lastSentAt = message.sentAt;

    final now = clock.now();
    switch (message.kind) {
      case AgentWakeCoordinationKind.claim:
        final previous = view.claimHash;
        // A claim that arrives after it would have lapsed says nothing about
        // a live run: the device was offline, or the queue was backed up. It
        // is still newer than the claim held, which it supersedes.
        if (now.difference(message.sentAt) >= coordinationTimeout) {
          if (previous != null) {
            view.clearClaim();
            _peerStateChanged(message.agentId);
          }
          return;
        }
        view
          ..claimHash = message.stateHash
          ..claimExpiresAt = now.add(coordinationTimeout);
        view.expiry?.cancel();
        view.expiry = Timer(
          coordinationTimeout,
          () => _peerStateChanged(message.agentId),
        );
        // A job held back by the claim this one replaces may run now.
        if (previous != null && previous != message.stateHash) {
          _peerStateChanged(message.agentId);
        }
      case AgentWakeCoordinationKind.done:
        view
          ..clearClaim()
          ..addDone(message.stateHash);
        _peerStateChanged(message.agentId);
      case AgentWakeCoordinationKind.release:
        view.clearClaim();
        _peerStateChanged(message.agentId);
    }
  }

  void _peerStateChanged(String agentId) {
    final callback = onPeerStateChanged;
    if (callback == null) return;
    try {
      callback(agentId);
    } catch (error, stackTrace) {
      logError(
        'peer state change callback failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops every timer. Live runs are not released: the process is going
  /// away, and peers wait out the timer as after a crash.
  void dispose() {
    for (final run in _runs.values) {
      run.heartbeat.cancel();
    }
    _runs.clear();
    for (final views in _peers.values) {
      for (final view in views.values) {
        view.expiry?.cancel();
      }
    }
    _peers.clear();
  }
}

class _LocalRun {
  _LocalRun({
    required this.agentId,
    required this.stateHash,
    required this.heartbeat,
  });

  final String agentId;
  final String stateHash;
  final Timer heartbeat;
}

/// One device's view of one peer's wakes of one agent.
class _PeerView {
  String? claimHash;
  DateTime? claimExpiresAt;
  Timer? expiry;
  DateTime? lastSentAt;

  /// Digests of the peer's completed runs, oldest first.
  final done = <String>{};

  void clearClaim() {
    claimHash = null;
    claimExpiresAt = null;
    expiry?.cancel();
    expiry = null;
  }

  void addDone(String stateHash) {
    done
      ..remove(stateHash)
      ..add(stateHash);
    while (done.length > AgentWakeCoordinator.doneHistoryLimit) {
      done.remove(done.first);
    }
  }
}
