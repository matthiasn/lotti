import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

/// Reads the rows a wake of `agentId` would read, or `null` when the agent
/// does not take part in coordination (its kind has no inputs reader, or its
/// state cannot be resolved). A `null` result always proceeds.
typedef WakeInputsReader = Future<WakeInputs?> Function(String agentId);

/// Reads this device's watermark: per host, the highest counter up to which
/// it holds every one of that host's writes. It covers every host it knows
/// and at least [hosts].
typedef WakeWatermarkReader =
    Future<Map<String, int>> Function(Set<String> hosts);

/// Sends one coordination broadcast to every peer (the sync outbox).
typedef WakeCoordinationSender = Future<void> Function(SyncMessage message);

/// The rows a wake reads, keyed `<kind>:<id>` for the logs, with the vector
/// clock of each.
class WakeInputs {
  const WakeInputs({
    required this.clocks,
    required this.readsPrivate,
    required this.definitions,
  });

  final Map<String, VectorClock?> clocks;

  /// Whether this device's context includes private entries.
  final bool readsPrivate;

  /// Digest of the inputs no watermark can cover because their versions carry
  /// no host counter — label and category definitions. Only an equal digest
  /// covers them.
  final String definitions;

  /// The rows saved before their type carried a clock. No watermark covers
  /// them; a peer covers them by naming them ([WakeCoverage.clockless]).
  Set<String> get clockless => {
    for (final MapEntry(:key, :value) in clocks.entries)
      if (value == null) key,
  };

  /// Every host a write under these rows came from.
  Set<String> get hosts => {
    for (final clock in clocks.values) ...?clock?.vclock.keys,
  };
}

/// What a run reads: every write up to [watermark], per host, private
/// entries if [readsPrivate], and the definitions [definitions] digests.
/// Claims and completions carry it.
@immutable
class WakeCoverage {
  const WakeCoverage({
    required this.watermark,
    required this.readsPrivate,
    required this.definitions,
    this.clockless = const {},
  });

  final Map<String, int> watermark;
  final bool readsPrivate;
  final String definitions;

  /// The clockless rows the run read, by input key. Such a row has not
  /// changed since it was saved, so reading it is holding it — but a peer may
  /// never have received it, and no watermark says whether it did.
  final Set<String> clockless;

  /// Why a run over this coverage would not read everything in [inputs], or
  /// `null` when it reads all of it. This is the model's `Covers`: the run's
  /// state holds every write the inputs rest on.
  String? uncovered(WakeInputs inputs) {
    if (inputs.readsPrivate && !readsPrivate) return 'private entries';
    if (inputs.definitions != definitions) {
      return 'label or category definitions differ';
    }
    for (final MapEntry(:key, value: clock) in inputs.clocks.entries) {
      // A row without a clock was saved before its type carried one, and has
      // not been edited since — an edit stamps a clock. The run covers it if
      // it read it too. Refusing every such row made each task with one old
      // link uncoverable on every device.
      if (clock == null) {
        if (clockless.contains(key)) continue;
        return '${_describe(key)} predates clocks and the peer did not read '
            'it';
      }
      for (final MapEntry(key: host, value: counter) in clock.vclock.entries) {
        final held = watermark[host] ?? 0;
        if (counter > held) {
          return '${_describe(key)} needs '
              '${DomainLogger.sanitizeId(host)}:$counter, peer holds $held';
        }
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is WakeCoverage &&
      other.readsPrivate == readsPrivate &&
      other.definitions == definitions &&
      const SetEquality<String>().equals(other.clockless, clockless) &&
      const MapEquality<String, int>().equals(other.watermark, watermark);

  @override
  int get hashCode => Object.hash(
    readsPrivate,
    definitions,
    const SetEquality<String>().hash(clockless),
    const MapEquality<String, int>().hash(watermark),
  );
}

String _describe(String key) {
  final separator = key.indexOf(':');
  if (separator < 0) return DomainLogger.sanitizeId(key);
  return '${key.substring(0, separator)} '
      '${DomainLogger.sanitizeId(key.substring(separator + 1))}';
}

/// What the drain should do with a wake job, decided by
/// [AgentWakeCoordinator.evaluate].
sealed class WakeCoordinationDecision {
  const WakeCoordinationDecision();
}

/// Run the wake. [coverage] is what to claim, or `null` when the wake takes
/// no part in coordination.
final class WakeCoordinationProceed extends WakeCoordinationDecision {
  const WakeCoordinationProceed(this.coverage);

  final WakeCoverage? coverage;
}

/// A peer completed, or is running, a wake that reads everything this one
/// would: drop the job, its triggers are covered. A started run is trusted to
/// finish; if it does not, the dropped triggers stay visibly stale here.
final class WakeCoordinationCancel extends WakeCoordinationDecision {
  const WakeCoordinationCancel({
    required this.peerHostId,
    required this.completed,
    required this.reportUpdated,
  });

  final String peerHostId;

  /// Whether the covering run has completed — `false` while it runs.
  final bool completed;

  /// Whether the covering run refreshed the standing report, so this
  /// device's report is fresh too. `false` while it runs: that is only known
  /// from its `done`.
  final bool reportUpdated;
}

/// Cross-device coordination of agent wakes: of several devices about to run
/// the same agent, one runs and the others stand down when its run reads
/// everything theirs would.
///
/// The protocol, and the properties TLC checks for it, are
/// `specs/tla/AgentWakeCoordination.tla`; each method names the action it
/// implements. The model's state is a set of edits and its `Covers` is the
/// subset relation; here a run's state is a [WakeCoverage] — the watermark of
/// the device when the run started — and [WakeCoverage.uncovered] checks the
/// vector clock of every row another device's wake would read against it.
///
/// - [claim] (`Dispatch`) broadcasts that this device runs a wake with a
///   coverage, and repeats it every [heartbeatInterval] (`Beat`) while the run
///   is live, because a run may outlast [coordinationTimeout].
/// - [complete] (`Complete`) broadcasts `done`; [settle] (`Fail`) broadcasts
///   `release` for a run that ended any other way.
/// - [onMessage] (`Deliver`) records a peer's claim, re-arming its timer on
///   every message, and remembers the coverages of the peer's completed runs
///   apart from its live claim, so its next claim cannot erase them.
/// - [evaluate] returns cancel when a peer completed, or is running, a run
///   covering this wake's inputs (`Cancel`), and proceed otherwise — an input
///   the peer does not hold is new work. A started run is trusted to finish:
///   if it does not, the cancelled wake's inputs stay visibly stale.
///
/// All state is in memory and device-local: a process restart forgets the
/// peers' claims (`Crash`), which can only cost a duplicate run, never a lost
/// one.
class AgentWakeCoordinator with AgentErrorLogging {
  AgentWakeCoordinator({
    required this._readInputs,
    required this._readWatermark,
    required this._send,
    required this._localHostId,
    this.domainLogger,
  });

  /// How long a peer's claim cancels covered wakes after its last message.
  /// Any message from that peer about the agent re-arms it.
  static const coordinationTimeout = Duration(minutes: 2);

  /// How often a live run repeats its claim. The model requires
  /// `coordinationTimeout > heartbeatInterval + delivery delay`, so this
  /// leaves 75 seconds for a heartbeat to arrive.
  static const heartbeatInterval = Duration(seconds: 45);

  /// How many completed-run coverages are kept per peer and agent.
  static const doneHistoryLimit = 8;

  final WakeInputsReader _readInputs;
  final WakeWatermarkReader _readWatermark;
  final WakeCoordinationSender _send;
  final Future<String?> Function() _localHostId;

  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;

  /// Called with an agent id whenever a peer's claim for it starts, ends,
  /// lapses or changes its coverage — every event that can hold back, free or
  /// cover a queued job — so queued jobs are checked again. A heartbeat
  /// repeating the same claim is not an event. Set by the orchestrator.
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
  /// claims, so peers stand down for it).
  Future<WakeCoordinationDecision> evaluate(
    String agentId, {
    bool deferrable = true,
  }) async {
    final agent = DomainLogger.sanitizeId(agentId);
    final WakeInputs? inputs;
    final WakeCoverage coverage;
    try {
      inputs = await _readInputs(agentId);
      if (inputs == null) return const WakeCoordinationProceed(null);
      // Read after the inputs: a write the inputs hold is then under the
      // watermark, and the run, which reads later still, holds it too.
      coverage = WakeCoverage(
        watermark: await _readWatermark(inputs.hosts),
        readsPrivate: inputs.readsPrivate,
        definitions: inputs.definitions,
        clockless: inputs.clockless,
      );
    } catch (error, stackTrace) {
      // Coordination only ever saves work; failing open costs a duplicate.
      logError(
        'wake inputs unreadable; wake proceeds uncoordinated',
        error: error,
        stackTrace: stackTrace,
      );
      return const WakeCoordinationProceed(null);
    }
    if (!deferrable) {
      _log('proceed $agent: requested by the user');
      return WakeCoordinationProceed(coverage);
    }

    final peers = _peers[agentId] ?? const <String, _PeerView>{};
    final reasons = <String>[];
    for (final MapEntry(key: host, value: view) in peers.entries) {
      for (final done in view.done.reversed) {
        final reason = done.coverage.uncovered(inputs);
        if (reason == null) {
          _log(
            'cancel $agent: peer ${DomainLogger.sanitizeId(host)} completed '
            'a run covering ${inputs.clocks.length} inputs',
          );
          return WakeCoordinationCancel(
            peerHostId: host,
            completed: true,
            reportUpdated: done.reportUpdated,
          );
        }
        reasons.add('${DomainLogger.sanitizeId(host)} done: $reason');
      }
    }
    final now = clock.now();
    for (final MapEntry(key: host, value: view) in peers.entries) {
      final claim = view.claim;
      final expiresAt = view.claimExpiresAt;
      if (claim == null || expiresAt == null || !now.isBefore(expiresAt)) {
        continue;
      }
      final reason = claim.uncovered(inputs);
      if (reason == null) {
        _log(
          'cancel $agent: peer ${DomainLogger.sanitizeId(host)} is running '
          'a wake covering ${inputs.clocks.length} inputs',
        );
        return WakeCoordinationCancel(
          peerHostId: host,
          completed: false,
          reportUpdated: false,
        );
      }
      reasons.add('${DomainLogger.sanitizeId(host)} claim: $reason');
    }
    _log(
      'proceed $agent: ${inputs.clocks.length} inputs, '
      '${reasons.isEmpty ? 'no peer run known' : reasons.join('; ')}',
    );
    return WakeCoordinationProceed(coverage);
  }

  /// Announces that run [runKey] of [agentId] is starting with [coverage]
  /// and keeps announcing it until [complete] or [settle]. A `null` coverage
  /// announces nothing.
  void claim({
    required String agentId,
    required String runKey,
    required WakeCoverage? coverage,
  }) {
    if (coverage == null) return;
    _runs.remove(runKey)?.heartbeat.cancel();
    void announce() => _broadcast(
      agentId: agentId,
      runKey: runKey,
      coverage: coverage,
      kind: AgentWakeCoordinationKind.claim,
    );
    _runs[runKey] = _LocalRun(
      agentId: agentId,
      coverage: coverage,
      heartbeat: Timer.periodic(heartbeatInterval, (_) => announce()),
    );
    announce();
  }

  /// Announces that run [runKey] completed successfully, and whether it
  /// refreshed the agent's standing report.
  void complete(String runKey, {bool reportUpdated = true}) => _finish(
    runKey,
    AgentWakeCoordinationKind.done,
    reportUpdated: reportUpdated,
  );

  /// Ends run [runKey] however it ended. After [complete] this is a no-op;
  /// otherwise the run failed, was aborted or never reached its executor, and
  /// peers are released at once instead of waiting out the timer.
  void settle(String runKey) =>
      _finish(runKey, AgentWakeCoordinationKind.release);

  void _finish(
    String runKey,
    AgentWakeCoordinationKind kind, {
    bool reportUpdated = true,
  }) {
    final run = _runs.remove(runKey);
    if (run == null) return;
    run.heartbeat.cancel();
    _broadcast(
      agentId: run.agentId,
      runKey: runKey,
      coverage: run.coverage,
      kind: kind,
      reportUpdated: reportUpdated,
    );
  }

  void _broadcast({
    required String agentId,
    required String runKey,
    required WakeCoverage coverage,
    required AgentWakeCoordinationKind kind,
    bool reportUpdated = true,
  }) {
    final sentAt = clock.now();
    // Chained, so this device's messages reach the outbox in the order they
    // were issued: the model's channels are FIFO.
    _sendChain = _sendChain.then((_) async {
      try {
        final hostId = await _localHostId();
        if (hostId == null) {
          _log('${kind.name} not sent: no host id yet');
          return;
        }
        await _send(
          SyncMessage.agentWakeCoordination(
            agentId: agentId,
            kind: kind,
            watermark: coverage.watermark,
            readsPrivate: coverage.readsPrivate,
            definitionsDigest: coverage.definitions,
            clocklessInputs: coverage.clockless.toList()..sort(),
            runKey: runKey,
            hostId: hostId,
            sentAt: sentAt,
            reportUpdated: reportUpdated,
          ),
        );
        _log(
          'sent ${kind.name} for ${DomainLogger.sanitizeId(agentId)} '
          'run ${DomainLogger.sanitizeId(runKey)}',
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
  /// applied in the order they were sent — by that peer's own clock, so the
  /// comparison never mixes clocks; an older one is dropped.
  void onMessage(SyncAgentWakeCoordination message) {
    final peer = DomainLogger.sanitizeId(message.hostId);
    final agent = DomainLogger.sanitizeId(message.agentId);
    final view = (_peers[message.agentId] ??= {})[message.hostId] ??=
        _PeerView();
    final lastSentAt = view.lastSentAt;
    if (lastSentAt != null && message.sentAt.isBefore(lastSentAt)) {
      _log('dropped stale ${message.kind.name} from $peer for $agent');
      return;
    }
    view.lastSentAt = message.sentAt;
    _log(
      'received ${message.kind.name} from $peer for $agent '
      'run ${DomainLogger.sanitizeId(message.runKey)}',
    );

    final coverage = WakeCoverage(
      watermark: message.watermark,
      readsPrivate: message.readsPrivate,
      definitions: message.definitionsDigest,
      clockless: message.clocklessInputs.toSet(),
    );
    final now = clock.now();
    switch (message.kind) {
      case AgentWakeCoordinationKind.claim:
        final previous = view.claim;
        // The timer runs from receipt, on this device's clock: `sentAt` is
        // the peer's clock, and comparing the two would drop every claim
        // from a peer whose clock runs behind. A claim that arrives late
        // holds a covered wake back for at most one timeout.
        view
          ..claim = coverage
          ..claimExpiresAt = now.add(coordinationTimeout);
        view.expiry?.cancel();
        view.expiry = Timer(
          coordinationTimeout,
          () => _peerStateChanged(message.agentId),
        );
        // A new claim may cover a queued job, whose countdown then waits on
        // the peer; one that replaces another may free a job held back.
        if (previous != coverage) _peerStateChanged(message.agentId);
      case AgentWakeCoordinationKind.done:
        view
          ..clearClaim()
          ..addDone((coverage: coverage, reportUpdated: message.reportUpdated));
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
    required this.coverage,
    required this.heartbeat,
  });

  final String agentId;
  final WakeCoverage coverage;
  final Timer heartbeat;
}

/// What a peer's `done` announced: what the run read, and whether it
/// refreshed the standing report.
typedef _CompletedRun = ({WakeCoverage coverage, bool reportUpdated});

/// One device's view of one peer's wakes of one agent.
class _PeerView {
  WakeCoverage? claim;
  DateTime? claimExpiresAt;
  Timer? expiry;
  DateTime? lastSentAt;

  /// The peer's completed runs, oldest first.
  final done = <_CompletedRun>[];

  void clearClaim() {
    claim = null;
    claimExpiresAt = null;
    expiry?.cancel();
    expiry = null;
  }

  void addDone(_CompletedRun run) {
    done
      ..removeWhere((known) => known.coverage == run.coverage)
      ..add(run);
    while (done.length > AgentWakeCoordinator.doneHistoryLimit) {
      done.removeAt(0);
    }
  }
}
