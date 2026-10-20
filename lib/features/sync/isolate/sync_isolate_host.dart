import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';

/// Where the sync isolate is in its life, as the host sees it.
enum SyncIsolateState {
  /// Constructed, not started.
  stopped,

  /// [SyncIsolateHost.start] is spawning the first worker.
  starting,

  /// A worker is up and answering.
  running,

  /// The worker exited unexpectedly, or could not be started; a
  /// replacement is waiting out its backoff or being spawned.
  restarting,

  /// Shut down for good.
  disposed,
}

/// Owns the sync isolate from the UI isolate's side (ADR 0142): spawns it,
/// numbers each request and matches its reply, and supervises it.
///
/// Supervision is what the removed actor lacked (ADR 0046): a worker that
/// exits without being asked to is logged, every request still out to it
/// fails with [SyncIsolateErrorCode.isolateExited] instead of waiting out its
/// timeout, and a replacement is spawned after a backoff that grows with
/// each consecutive crash. A worker that cannot be started at all counts as
/// a crash too — sync does not give up on its worker. A worker that ran for
/// [_stableUptime] before exiting restarts the streak, so a rare crash is
/// answered in a second rather than in a minute.
///
/// One worker at a time; requests made while none is running fail at once
/// with [SyncIsolateErrorCode.notRunning].
class SyncIsolateHost {
  SyncIsolateHost({
    required this._logger,
    this._entry = syncIsolateEntry,
    this._startTimeout = SyncTuning.syncIsolateStartTimeout,
    this._requestTimeout = SyncTuning.syncIsolateRequestTimeout,
    this._respawnBackoff = SyncTuning.syncIsolateRespawnBackoff,
    this._stableUptime = SyncTuning.syncIsolateStableUptime,
    this._createTimer = Timer.new,
  }) : assert(_respawnBackoff.isNotEmpty, 'respawnBackoff needs a step');

  static const _subDomain = 'isolate';

  final DomainLogger _logger;
  final SyncIsolateEntry _entry;
  final Duration _startTimeout;
  final Duration _requestTimeout;
  final List<Duration> _respawnBackoff;
  final Duration _stableUptime;

  /// Schedules each respawn. Injectable so tests decide when a respawn
  /// fires and can read the backoff it was given.
  final Timer Function(Duration delay, void Function() callback) _createTimer;

  final _states = StreamController<SyncIsolateState>.broadcast();
  final _pending = <int, Completer<Object?>>{};
  var _nextRequestId = 0;
  SyncIsolateState _state = SyncIsolateState.stopped;
  var _crashStreak = 0;
  _Worker? _worker;
  Timer? _respawnTimer;

  SyncIsolateState get state => _state;

  /// Every state change, as it happens.
  Stream<SyncIsolateState> get states => _states.stream;

  /// Starts spawning the first worker and returns at once: nothing waits on
  /// a spawn, startup least of all. Watch [states] for
  /// [SyncIsolateState.running]. A worker that cannot be started is logged
  /// and retried like one that crashed.
  void start() {
    if (_state != SyncIsolateState.stopped) {
      throw StateError('SyncIsolateHost.start() while ${_state.name}');
    }
    _setState(SyncIsolateState.starting);
    _launch();
  }

  /// Asks the worker whether it is alive.
  Future<SyncIsolateHealth> ping() async =>
      (await _request(const SyncIsolatePing()))! as SyncIsolateHealth;

  /// Shuts the worker down and fails whatever is still waiting on it.
  ///
  /// The worker is asked to exit, which lets it finish the command it holds;
  /// one that has not exited within the request timeout is killed.
  Future<void> dispose() async {
    if (_state == SyncIsolateState.disposed) return;
    _setState(SyncIsolateState.disposed);
    _respawnTimer?.cancel();
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      worker.commands.send(
        SyncIsolateRequest(
          requestId: _nextRequestId++,
          command: const SyncIsolateShutdown(),
        ),
      );
      await worker.exited.future.timeout(
        _requestTimeout,
        onTimeout: worker.kill,
      );
      worker.close();
    }
    _failPending(SyncIsolateErrorCode.notRunning, 'host disposed');
    await _states.close();
  }

  Future<Object?> _request(SyncIsolateCommand command) {
    final worker = _worker;
    if (_state != SyncIsolateState.running || worker == null) {
      return Future.error(
        SyncIsolateFailure(
          SyncIsolateErrorCode.notRunning,
          'sync isolate is ${_state.name}',
        ),
      );
    }
    final requestId = _nextRequestId++;
    final reply = Completer<Object?>();
    _pending[requestId] = reply;
    worker.commands.send(
      SyncIsolateRequest(requestId: requestId, command: command),
    );
    return reply.future.timeout(
      _requestTimeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw SyncIsolateFailure(
          SyncIsolateErrorCode.timeout,
          '${command.runtimeType} unanswered after $_requestTimeout',
        );
      },
    );
  }

  /// Spawns a worker and waits for its [SyncIsolateReady]. On any failure
  /// the half-started worker is killed and its port closed before the error
  /// propagates.
  ///
  /// Everything the worker produces arrives on **one** port: its own
  /// messages, the VM's report of an uncaught error (`onError`, an
  /// `[error, stackTrace]` list) and its exit (`onExit`, `null`). One port
  /// keeps their order — an error always before the exit it caused, a reply
  /// or log line sent just before dying before the exit too. Separate ports
  /// do not, and a crash would lose its trace whenever the exit won the
  /// race. The worker only sends protocol objects, so the list and the null
  /// cannot be mistaken for anything it said.
  Future<_Worker> _spawn() async {
    final port = ReceivePort();
    final ready = Completer<SendPort>();
    final exited = Completer<void>();
    _Worker? worker;

    port.listen((message) {
      switch (message) {
        case SyncIsolateReady(:final commands):
          if (!ready.isCompleted) ready.complete(commands);
        case SyncIsolateReply():
          _onReply(message);
        case SyncIsolateLog(:final message, :final level):
          _log(message, level: level);
        case [final Object? error, final Object? stackTrace]:
          _logger.error(
            LogDomain.sync,
            '$error',
            stackTrace: stackTrace is String
                ? StackTrace.fromString(stackTrace)
                : null,
            subDomain: _subDomain,
            message: 'uncaught error in sync isolate',
          );
        case null:
          exited.complete();
          if (!ready.isCompleted) {
            ready.completeError(
              const SyncIsolateFailure(
                SyncIsolateErrorCode.isolateExited,
                'sync isolate exited before its handshake',
              ),
            );
          }
          final current = worker;
          if (current != null) _onExit(current);
      }
    });

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _entry,
        port.sendPort,
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: 'sync',
      );
      final commands = await ready.future.timeout(
        _startTimeout,
        onTimeout: () => throw SyncIsolateFailure(
          SyncIsolateErrorCode.timeout,
          'no handshake from the sync isolate after $_startTimeout',
        ),
      );
      return worker = _Worker(
        isolate: isolate,
        commands: commands,
        port: port,
        exited: exited,
        startedAt: clock.now(),
      );
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      port.close();
      rethrow;
    }
  }

  void _onReply(SyncIsolateReply reply) {
    final waiting = _pending.remove(reply.requestId);
    if (waiting == null) return;
    final failure = reply.failure;
    if (failure != null) {
      waiting.completeError(failure);
    } else {
      waiting.complete(reply.result);
    }
  }

  /// Handles a worker that exited. Only the current worker matters, and
  /// only an exit nobody asked for is a crash.
  void _onExit(_Worker worker) {
    if (!identical(worker, _worker)) return;
    _worker = null;
    worker.close();
    _failPending(SyncIsolateErrorCode.isolateExited, 'sync isolate exited');
    if (_state != SyncIsolateState.running) return;

    final uptime = clock.now().difference(worker.startedAt);
    if (uptime >= _stableUptime) _crashStreak = 0;
    _logger.error(
      LogDomain.sync,
      'sync isolate exited unexpectedly after $uptime',
      subDomain: _subDomain,
    );
    _scheduleRespawn();
  }

  void _scheduleRespawn() {
    final delay =
        _respawnBackoff[math.min(_crashStreak, _respawnBackoff.length - 1)];
    _crashStreak++;
    _setState(SyncIsolateState.restarting);
    _log('respawning sync isolate in $delay (crash streak $_crashStreak)');
    _respawnTimer = _createTimer(delay, () {
      if (_state == SyncIsolateState.restarting) _launch();
    });
  }

  /// Spawns a worker for the first start or a respawn. Both outcomes are
  /// handled here — the worker adopted, or the failure logged and retried —
  /// so the spawn's future has nobody left to report to.
  void _launch() {
    final requestedAt = clock.now();
    _spawn().then(
      (worker) {
        if (_state != SyncIsolateState.starting &&
            _state != SyncIsolateState.restarting) {
          // Disposed while the worker was starting up.
          worker.kill();
          _log('sync isolate finished starting after dispose; killed it');
          return;
        }
        _worker = worker;
        _setState(SyncIsolateState.running);
        _log(
          'sync isolate handshake after '
          '${clock.now().difference(requestedAt).inMilliseconds} ms',
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_state == SyncIsolateState.disposed) return;
        _logger.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: _subDomain,
          message: 'starting the sync isolate failed',
        );
        _scheduleRespawn();
      },
    );
  }

  void _failPending(SyncIsolateErrorCode code, String message) {
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final reply in waiting) {
      reply.completeError(SyncIsolateFailure(code, message));
    }
  }

  void _setState(SyncIsolateState state) {
    if (_state == state) return;
    _state = state;
    if (!_states.isClosed) _states.add(state);
    _log('sync isolate ${state.name}');
  }

  void _log(String message, {InsightLevel level = InsightLevel.info}) =>
      _logger.log(LogDomain.sync, message, subDomain: _subDomain, level: level);
}

/// One spawned worker and the host-side port that listens to it.
class _Worker {
  _Worker({
    required this.isolate,
    required this.commands,
    required this.port,
    required this.exited,
    required this.startedAt,
  });

  final Isolate isolate;
  final SendPort commands;
  final ReceivePort port;
  final Completer<void> exited;
  final DateTime startedAt;

  void kill() {
    isolate.kill(priority: Isolate.immediate);
    close();
  }

  void close() => port.close();
}
