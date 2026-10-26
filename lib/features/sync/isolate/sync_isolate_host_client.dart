import 'dart:async';
import 'dart:isolate';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/sync_key_value_store.dart';
import 'package:lotti/database/sync_payload_source.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// The worker's side of the request channel to the host (ADR 0142, step 4b):
/// numbers each [SyncIsolateHostQuery], sends it, and completes the waiting
/// future when the host's [SyncIsolateHostReply] arrives on the worker's
/// command port.
///
/// The UI-owned databases the Matrix stack reads are reached through the
/// adapters below, which implement the stack's narrow store interfaces over
/// this client; the stack itself does not know it is talking across a port.
class SyncIsolateHostClient {
  SyncIsolateHostClient(
    this._host, {
    this.timeout = const Duration(seconds: 30),
  });

  final SendPort _host;

  /// How long a query may go unanswered before it fails.
  final Duration timeout;

  final _pending = <int, Completer<Object?>>{};
  var _nextRequestId = 0;

  /// Sends [query] and returns the host's answer, cast to [T].
  Future<T> ask<T>(SyncIsolateHostQuery query) async {
    final requestId = _nextRequestId++;
    final reply = Completer<Object?>();
    _pending[requestId] = reply;
    _host.send(SyncIsolateHostRequest(requestId: requestId, query: query));
    final result = await reply.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw SyncIsolateFailure(
          SyncIsolateErrorCode.timeout,
          '${query.runtimeType} unanswered by the host after $timeout',
        );
      },
    );
    return result as T;
  }

  /// Routes a reply from the host to the query waiting for it; a reply to
  /// nothing — one that arrived after its timeout — is dropped.
  void onReply(SyncIsolateHostReply reply) {
    final waiting = _pending.remove(reply.requestId);
    if (waiting == null) return;
    final failure = reply.failure;
    if (failure != null) {
      waiting.completeError(failure);
    } else {
      waiting.complete(reply.result);
    }
  }

  /// Fails every query still waiting, when the worker shuts down.
  void dispose() {
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final reply in waiting) {
      reply.completeError(
        const SyncIsolateFailure(
          SyncIsolateErrorCode.notRunning,
          'sync isolate shutting down',
        ),
      );
    }
  }
}

/// The settings keys the stack reads and writes, answered by the host.
class HostKeyValueStore implements SyncKeyValueStore {
  const HostKeyValueStore(this._host);

  final SyncIsolateHostClient _host;

  @override
  Future<String?> itemByKey(String key) =>
      _host.ask<String?>(SyncIsolateHostSettingsGet(key));

  @override
  Future<int> saveSettingsItem(String key, String value) =>
      _host.ask<int>(SyncIsolateHostSettingsSet(key, value));

  @override
  Future<void> removeSettingsItem(String key) async {
    await _host.ask<Object?>(SyncIsolateHostSettingsRemove(key));
  }
}

/// The journal rows the sender reads, answered by the host.
class HostPayloadSource implements SyncPayloadSource {
  const HostPayloadSource(this._host);

  final SyncIsolateHostClient _host;

  @override
  Future<Map<String, JournalEntity>> journalEntityMapForIdsIncludingDeleted(
    Iterable<String> ids,
  ) => _host.ask<Map<String, JournalEntity>>(
    SyncIsolateHostJournalEntities(ids.toList()),
  );

  @override
  Future<JournalEntity?> openConflictVersion(
    String id,
    VectorClock vectorClock,
  ) => _host.ask<JournalEntity?>(
    SyncIsolateHostOpenConflictVersion(id: id, vectorClock: vectorClock),
  );

  @override
  Future<bool> getConfigFlag(String flagName) =>
      _host.ask<bool>(SyncIsolateHostConfigFlag(flagName));
}

/// This device's vector-clock host id, answered by the host.
class HostIdSource implements SyncHostIdSource {
  const HostIdSource(this._host);

  final SyncIsolateHostClient _host;

  @override
  Future<String?> getHost() =>
      _host.ask<String?>(const SyncIsolateHostVectorClockHost());
}
