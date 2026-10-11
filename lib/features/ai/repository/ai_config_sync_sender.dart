import 'dart:async';

import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_sync_ledger.dart';

/// What this device holds for one AI configuration id, as a resend carries
/// it: the stored row (a tombstone included) with the stamp its version
/// holds, or, with no [config], the hard deletion that [stamp] alone records.
class AiConfigResend {
  const AiConfigResend({required this.id, this.config, this.stamp});

  final String id;
  final AiConfig? config;
  final int? stamp;

  /// The message carrying this state, stamped so a peer holding a newer
  /// version drops it (ADR 0094).
  SyncMessage toSyncMessage() {
    final config = this.config;
    if (config != null) {
      return SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.update,
        versionStamp: stamp,
      );
    }
    return SyncMessage.aiConfigDelete(
      id: id,
      hardDelete: true,
      versionStamp: stamp,
    );
  }
}

/// Sends AI configuration writes to the peers, owing each until the outbox
/// accepts it (ADR 0127).
///
/// A write commits before its message is staged, so [send] records the id
/// in the [AiConfigSyncLedger] first and settles it only once the outbox
/// has taken the row. A failure is logged, never thrown, and arms a retry;
/// [flush] then sends what the device holds for each owed id at that time,
/// as [resendOf] reports it, so a later write supersedes an older owed one.
/// Without settings storage there is no ledger, and a failed send is only
/// logged.
///
/// Sends and flushes run one at a time, in call order. The ledger's owe and
/// settle are read-modify-writes of one settings row, so two interleaved
/// would drop an owed id; and a flush that read an id's old version must not
/// settle it after a newer write of that id failed to enqueue.
class AiConfigSyncSender {
  AiConfigSyncSender({
    required SettingsDb? settingsDb,
    required this.enqueue,
    required this.resendOf,
    required this.onError,
    this.retryDelay = const Duration(minutes: 1),
  }) : _ledger = settingsDb == null ? null : AiConfigSyncLedger(settingsDb);

  final AiConfigSyncLedger? _ledger;

  /// Stages a message in the outbox, throwing when it is not accepted.
  final Future<void> Function(SyncMessage message) enqueue;

  /// Reports a failed send or flush, which is never thrown.
  final void Function(Object error, StackTrace stackTrace, String subDomain)
  onError;

  /// What the device holds for an owed id now; null when it holds nothing,
  /// and the id is forgotten.
  final Future<AiConfigResend?> Function(String id) resendOf;

  /// How long after a failed enqueue the owed ids are tried again.
  final Duration retryDelay;

  Timer? _retryTimer;
  bool _disposed = false;

  /// The tail of the queue every send and flush runs on.
  Future<void> _tail = Future<void>.value();

  /// Ids an [owing] write holds, counted per concurrent write: a flush
  /// leaves them owed rather than send the version before the write.
  final Map<String, int> _writing = {};

  /// Runs [operation] after every earlier send and flush has finished.
  /// Neither throws, so the queue never stalls on a failure.
  Future<void> _serially(Future<void> Function() operation) =>
      _tail = _tail.then((_) => operation());

  /// Stages [message], the latest write of [id], owing it until the outbox
  /// accepts the row.
  Future<void> send(String id, SyncMessage message) =>
      _serially(() => _send(id, message));

  Future<void> _send(String id, SyncMessage message) async {
    final ledger = _ledger;
    try {
      await ledger?.owe(id);
      await enqueue(message);
      await ledger?.settle(id);
    } catch (error, stackTrace) {
      onError(error, stackTrace, 'aiConfig.send');
      if (ledger != null) _scheduleRetry();
    }
  }

  /// Sends every write the ledger still owes, in id order. Called at
  /// startup, by the retry timer and by "Send settings". On the first
  /// failure the rest stay owed and a retry is scheduled.
  Future<void> flush() => _serially(_flush);

  Future<void> _flush() async {
    final ledger = _ledger;
    if (ledger == null) return;
    try {
      for (final id in (await ledger.load()).toList()..sort()) {
        if (_writing.containsKey(id)) continue;
        final resend = await resendOf(id);
        if (resend != null) {
          await enqueue(resend.toSyncMessage());
        }
        await ledger.settle(id);
      }
    } catch (error, stackTrace) {
      onError(error, stackTrace, 'aiConfig.flush');
      _scheduleRetry();
    }
  }

  /// Records [ids] as owed, then runs [write] — the local write and its
  /// sends — and returns its result. Owed before the write commits, a crash
  /// between the write and its send still leaves the debt for [flush] (ADR
  /// 0127); and while [write] runs a flush leaves [ids] owed, since it would
  /// send the version before the write and settle the debt the write still
  /// has. A failure to record is reported and the write goes ahead without
  /// the record, as before the ledger. Never call from inside a database
  /// transaction a flush reads: a running flush holds the sender.
  Future<T> owing<T>(Iterable<String> ids, Future<T> Function() write) async {
    final held = ids.toList(growable: false);
    await _serially(() => _owe(held));
    try {
      return await write();
    } finally {
      for (final id in held) {
        final count = _writing[id]! - 1;
        count == 0 ? _writing.remove(id) : _writing[id] = count;
      }
    }
  }

  Future<void> _owe(List<String> ids) async {
    for (final id in ids) {
      _writing.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    final ledger = _ledger;
    if (ledger == null) return;
    try {
      for (final id in ids) {
        await ledger.owe(id);
      }
    } catch (error, stackTrace) {
      onError(error, stackTrace, 'aiConfig.owe');
    }
  }

  /// Sends what the device holds for [id] now, owed like any write: to a
  /// peer on a build that applies AI configurations in arrival order, so
  /// the newest version is the last to reach it.
  Future<void> resendHeld(String id) async {
    final held = await resendOf(id);
    if (held != null) await send(id, held.toSyncMessage());
  }

  void _scheduleRetry() {
    if (_disposed) return;
    // The flush never throws: a failure is logged and re-armed inside it.
    _retryTimer ??= Timer(retryDelay, () async {
      _retryTimer = null;
      await flush();
    });
  }

  /// Stops the retry timer.
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
