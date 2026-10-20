/// Everything that crosses the sync isolate's ports (ADR 0142).
///
/// The worker is started with `Isolate.spawn`, so it shares the UI isolate's
/// isolate group and these immutable classes travel by value — no map
/// encoding, and the compiler checks both ends. Collections that cross are
/// lists, never sets (ADR 0046).
///
/// Three directions, one shape each:
///
/// * host → worker: a [SyncIsolateRequest] carrying a [SyncIsolateCommand]
///   and the id its reply must echo;
/// * worker → host, answering: a [SyncIsolateReply] with that id;
/// * worker → host, unprompted: a [SyncIsolateEvent].
///
/// The handshake is the one exception: the worker's first message is a
/// [SyncIsolateReady] holding the port commands go to.
library;

import 'dart:isolate';

import 'package:lotti/database/logging_types.dart';

/// The worker's first message: where the host sends commands from now on.
final class SyncIsolateReady {
  const SyncIsolateReady(this.commands);

  final SendPort commands;
}

/// Something the host asks the worker to do. Each command has exactly one
/// reply; the result type each one answers with is documented on it.
sealed class SyncIsolateCommand {
  const SyncIsolateCommand();
}

/// Asks the worker whether it is alive. Answered with [SyncIsolateHealth].
final class SyncIsolatePing extends SyncIsolateCommand {
  const SyncIsolatePing();
}

/// Asks the worker to finish what it holds and exit. Answered with `null`
/// just before its ports close.
final class SyncIsolateShutdown extends SyncIsolateCommand {
  const SyncIsolateShutdown();
}

/// A [command] on its way to the worker, numbered so its reply finds the
/// caller waiting for it.
final class SyncIsolateRequest {
  const SyncIsolateRequest({required this.requestId, required this.command});

  final int requestId;
  final SyncIsolateCommand command;
}

/// The worker's answer to the request numbered [requestId]: a [result] when
/// it succeeded, a [failure] when it did not.
final class SyncIsolateReply {
  const SyncIsolateReply.success(this.requestId, this.result) : failure = null;

  const SyncIsolateReply.failure(
    this.requestId,
    SyncIsolateFailure this.failure,
  ) : result = null;

  final int requestId;
  final Object? result;
  final SyncIsolateFailure? failure;
}

/// Why a request failed. The first three are decided by the host, [failed]
/// by the worker.
enum SyncIsolateErrorCode {
  /// The worker did not answer within the request timeout.
  timeout,

  /// The worker exited — crashed, or was killed — while the request was out.
  isolateExited,

  /// The host was disposed, or not running, when the request was made or
  /// before it was answered.
  notRunning,

  /// The worker answered, but could not carry the command out.
  failed,
}

/// A failed request, as the worker reports it and as the host throws it.
final class SyncIsolateFailure implements Exception {
  const SyncIsolateFailure(this.code, this.message);

  final SyncIsolateErrorCode code;
  final String message;

  @override
  String toString() => 'SyncIsolateFailure(${code.name}): $message';
}

/// The worker's answer to [SyncIsolatePing].
final class SyncIsolateHealth {
  const SyncIsolateHealth({required this.uptime, required this.handled});

  /// How long the worker has been running.
  final Duration uptime;

  /// Commands it has answered, this one included.
  final int handled;
}

/// Something the worker reports without being asked.
sealed class SyncIsolateEvent {
  const SyncIsolateEvent();
}

/// A log line from the worker. Logging lives in the UI isolate's getIt, so
/// the worker forwards its lines and the host writes them to the sync log.
final class SyncIsolateLog extends SyncIsolateEvent {
  const SyncIsolateLog(this.message, {this.level = InsightLevel.info});

  final String message;
  final InsightLevel level;
}
