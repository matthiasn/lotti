import 'dart:io';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/matrix/sync_event_trust.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';

/// The function a sync isolate starts in, handed what it needs to reach the
/// host and open its database. Injectable on `SyncIsolateHost` so tests can
/// spawn workers that crash, hang or answer wrongly.
typedef SyncIsolateEntry = void Function(SyncIsolateBoot boot);

/// The `sync.sqlite` tables the queue owner writes when it leases and
/// settles entries; what the worker reports as changed.
const List<String> inboundQueueTables = [
  'inbound_event_queue',
  'queue_markers',
];

/// Production entry point of the sync isolate.
///
/// The worker opens its own connection to `sync.sqlite` — the SQLite work
/// runs on this isolate, not in a nested one — and shakes hands only once
/// the database answers, so a database that will not open fails the start,
/// which the host logs and retries. It then answers the host's commands one
/// at a time, in order: liveness, and the queue owner's half of the inbound
/// hand-off (ADR 0142) — leasing ready entries for the UI isolate to apply
/// and recording the outcomes it acknowledges, after which it names the
/// tables it wrote. The Matrix client, admission and sending move in behind
/// the same port in later steps. After answering [SyncIsolateShutdown] it
/// closes its database and its only port, which ends the isolate.
///
/// Runs without Flutter plugins: nothing here may reach a platform channel,
/// so whatever the worker needs from the platform the host passes in.
Future<void> syncIsolateEntry(SyncIsolateBoot boot) =>
    _SyncIsolateWorker(boot).run();

class _SyncIsolateWorker {
  _SyncIsolateWorker(this._boot)
    : _logger = HostForwardingDomainLogger(_boot.host);

  final SyncIsolateBoot _boot;
  final HostForwardingDomainLogger _logger;
  final DateTime _startedAt = clock.now();
  var _handled = 0;
  late final SyncDatabase _db;
  late final InboundQueue _queue;
  late final InboundQueueSettlement _settlement;

  SendPort get _host => _boot.host;

  Future<void> run() async {
    final config = _boot.config;
    _db = SyncDatabase(
      inMemoryDatabase: config.inMemoryDatabase,
      background: false,
      documentsDirectoryProvider: () async => Directory(config.documentsPath),
      tempDirectoryProvider: () async => Directory(config.temporaryPath),
    );
    // Opening is lazy; the probe makes a database that will not open fail
    // the start instead of the first lease.
    await _db.customSelect('SELECT 1').get();
    _queue = InboundQueue(
      db: _db,
      logging: _logger,
      trust: SyncEventTrust(syncDb: _db, logging: _logger),
    );
    _settlement = InboundQueueSettlement(queue: _queue);

    final commands = ReceivePort();
    _host
      ..send(SyncIsolateReady(commands.sendPort))
      ..send(const SyncIsolateLog('sync isolate started'));
    await for (final message in commands) {
      if (message is! SyncIsolateRequest) continue;
      _handled++;
      try {
        _host.send(
          SyncIsolateReply.success(
            message.requestId,
            await _handle(message.command),
          ),
        );
      } catch (error) {
        _host.send(
          SyncIsolateReply.failure(
            message.requestId,
            SyncIsolateFailure(
              SyncIsolateErrorCode.failed,
              '${message.command.runtimeType}: $error',
            ),
          ),
        );
      }
      if (message.command is SyncIsolateShutdown) {
        commands.close();
        break;
      }
    }
  }

  Future<Object?> _handle(SyncIsolateCommand command) async {
    switch (command) {
      case SyncIsolatePing():
        return SyncIsolateHealth(
          uptime: clock.now().difference(_startedAt),
          handled: _handled,
        );
      case SyncIsolateShutdown():
        await _queue.dispose();
        await _db.close();
        return null;
      case SyncIsolateLeaseEntries(:final maxBatch):
        final leased = await _queue.peekBatchReady(maxBatch: maxBatch);
        if (leased.isNotEmpty) _tablesChanged();
        return leased;
      case SyncIsolateSettleEntries(:final outcomes):
        final applied = await _settlement.settle(outcomes);
        _tablesChanged();
        return applied;
    }
  }

  void _tablesChanged() =>
      _host.send(const SyncIsolateTablesChanged(inboundQueueTables));
}

/// The worker's [DomainLogger]: every line goes to the host as a
/// [SyncIsolateLog], and the host's logger decides whether the sync domain
/// is on. Nothing is written here — the base class would reach for the
/// documents directory through getIt, which the worker has no part of.
///
/// Public for its test; the worker is the only production user.
class HostForwardingDomainLogger extends DomainLogger {
  HostForwardingDomainLogger(this._host)
    : super(loggingService: LoggingService());

  final SendPort _host;

  @override
  void log(
    LogDomain domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) => _host.send(
    SyncIsolateLog(message, level: level, subDomain: subDomain),
  );

  @override
  void logSampled(
    LogDomain domain,
    String message, {
    required String sampleKey,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    int every = 100,
    Duration maxInterval = const Duration(minutes: 5),
  }) => log(domain, message, subDomain: subDomain, level: level);

  @override
  void error(
    LogDomain domain,
    Object error, {
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
    Type? errorType,
  }) => _host.send(
    SyncIsolateLog(
      '${message ?? 'error'}: $error'
      '${stackTrace == null ? '' : '\n$stackTrace'}',
      level: InsightLevel.error,
      subDomain: subDomain,
    ),
  );

  @override
  void errorWithDiagnostics(
    LogDomain domain,
    Object error, {
    required String diagnostics,
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
  }) => this.error(
    domain,
    error,
    stackTrace: stackTrace,
    subDomain: subDomain,
    message: message,
  );
}
