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
/// Two exceptions: the worker is spawned with a [SyncIsolateBoot], and its
/// first message is a [SyncIsolateReady] holding the port commands go to.
library;

import 'dart:isolate';

import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';

/// What the worker needs from the platform, handed over at spawn because the
/// worker uses no Flutter plugins: the database opener would otherwise ask
/// one for these directories.
final class SyncIsolateConfig {
  const SyncIsolateConfig({
    required this.documentsPath,
    required this.temporaryPath,
    this.inMemoryDatabase = false,
  });

  /// The active profile's documents directory, where `sync.sqlite` lives.
  final String documentsPath;

  /// Where SQLite may put its temporary files.
  final String temporaryPath;

  /// Tests only: an in-memory `sync.sqlite` instead of the file.
  final bool inMemoryDatabase;
}

/// The message a worker is spawned with: where to reach the host, and what
/// it needs to open its database.
final class SyncIsolateBoot {
  const SyncIsolateBoot({required this.host, required this.config});

  final SendPort host;
  final SyncIsolateConfig config;
}

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

/// Asks the worker, as the queue's owner, to lease up to [maxBatch] ready
/// inbound entries for the UI isolate to apply (ADR 0142). Answered with a
/// `List<InboundQueueEntry>`, oldest first; the rows turn `leased`.
final class SyncIsolateLeaseEntries extends SyncIsolateCommand {
  const SyncIsolateLeaseEntries({required this.maxBatch});

  final int maxBatch;
}

/// Acknowledges applied entries: the worker records each outcome as the
/// row's next state, in one transaction. Answered with the `int` count of
/// entries that were applied. An entry never acknowledged is leased again
/// once its lease expires — the invariant behind the hand-off.
final class SyncIsolateSettleEntries extends SyncIsolateCommand {
  const SyncIsolateSettleEntries(this.outcomes);

  final List<InboundEntryOutcome> outcomes;
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
/// the worker forwards its lines and the host writes them to the sync log,
/// under the `isolate` sub-domain or `isolate.<subDomain>`.
final class SyncIsolateLog extends SyncIsolateEvent {
  const SyncIsolateLog(
    this.message, {
    this.level = InsightLevel.info,
    this.subDomain,
  });

  final String message;
  final InsightLevel level;
  final String? subDomain;
}

/// Tables of `sync.sqlite` the worker just wrote. A Drift `watch()` sees
/// only its own connection's writes, so the host replays this into the UI
/// isolate's connection (`notifyUpdates`) and its streams fire as if the
/// write had been local (ADR 0142).
final class SyncIsolateTablesChanged extends SyncIsolateEvent {
  const SyncIsolateTablesChanged(this.tables);

  /// Table names, as Drift knows them.
  final List<String> tables;
}
