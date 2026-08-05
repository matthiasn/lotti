import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:meta/meta.dart';

/// Status of individual outbox items in the sync queue.
/// Used by SyncDatabase and outbox-related components.
enum OutboxStatus {
  pending,
  sent,
  error,
  sending,
}

/// Priority levels for outbox entries. Lower index = higher priority.
/// Stored as integer in the database for natural ORDER BY ASC.
enum OutboxPriority {
  /// User-created actions (journal entries, entry links).
  high, // index=0
  /// Agent actions, backfill, theming.
  normal, // index=1
  /// Bulk resync, entity definitions, tags, AI config.
  low, // index=2
}

/// Enum representing the outbox connectivity state.
/// The loading state is handled by Riverpod's AsyncValue.loading.
enum OutboxConnectionState {
  online,
  disabled,
}

/// Stream provider watching the Matrix sync enable flag.
/// Replaces OutboxCubit's config flag watching.
final StreamProvider<OutboxConnectionState> outboxConnectionStateProvider =
    StreamProvider.autoDispose<OutboxConnectionState>(
      outboxConnectionState,
      name: 'outboxConnectionStateProvider',
    );
Stream<OutboxConnectionState> outboxConnectionState(Ref ref) {
  final db = ref.watch(journalDbProvider);
  return db
      .watchConfigFlag(enableMatrixFlag)
      .map(
        (enabled) => enabled
            ? OutboxConnectionState.online
            : OutboxConnectionState.disabled,
      );
}

/// Stream provider for outbox pending count (for badge display).
final StreamProvider<int> outboxPendingCountProvider =
    StreamProvider.autoDispose<int>(
      outboxPendingCount,
      name: 'outboxPendingCountProvider',
    );
Stream<int> outboxPendingCount(Ref ref) {
  final syncDb = ref.watch(syncDatabaseProvider);
  return syncDb.watchOutboxCount();
}

/// Live depth of the inbound queue (active rows the worker can still
/// drain). Used by the incoming Settings badge. Resolves the
/// queue lazily via `MatrixService.queueCoordinator` because the
/// coordinator is created during app boot, not during provider
/// construction.
final StreamProvider<int> inboundQueueDepthProvider =
    StreamProvider.autoDispose<int>(
      inboundQueueDepth,
      name: 'inboundQueueDepthProvider',
    );
Stream<int> inboundQueueDepth(Ref ref) {
  final matrixService = ref.watch(matrixServiceProvider);
  return inboundQueueDepthStream(matrixService.queueCoordinator.queue);
}

@visibleForTesting
Stream<int> inboundQueueDepthStream(InboundQueue queue) async* {
  // Two ordering hazards must be handled together:
  //
  // (1) `depthChanges` is a broadcast stream with no buffering, so we
  //     must subscribe BEFORE awaiting `stats()` — otherwise a signal
  //     that fires during the snapshot computation is dropped and the
  //     UI shows a stale count until the next packet.
  //
  // (2) The depth snapshot we just awaited is older than any live
  //     signal that arrived during the await, so emitting `snapshot.total`
  //     unconditionally and then replaying buffered live values would
  //     step the consumer backwards (e.g. `2 → 1 → 2`). The fix: buffer
  //     live values until the snapshot resolves, emit the snapshot ONLY
  //     when the buffer is still empty, otherwise drop the stale
  //     snapshot and emit the buffered live sequence in arrival order
  //     before switching to forwarding the live tail.
  final buffered = <int>[];
  final relay = StreamController<int>.broadcast();
  final sub = queue.depthChanges
      .map((signal) => signal.total)
      .listen(
        (value) {
          if (relay.hasListener) {
            relay.add(value);
          } else {
            buffered.add(value);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (relay.hasListener) relay.addError(error, stack);
        },
      );
  try {
    int? snapshot;
    try {
      final stats = await queue.depthSnapshot();
      snapshot = stats.total;
    } catch (_) {
      // Initial paint failures are non-fatal; the live signal below
      // will provide a count on the next emission.
    }

    if (buffered.isEmpty && snapshot != null) {
      yield snapshot;
    } else {
      // A live signal beat the snapshot to the queue; trust the live
      // sequence over the now-stale `stats()` result and replay every
      // buffered value in arrival order before draining the tail.
      for (final value in buffered) {
        yield value;
      }
      buffered.clear();
    }

    yield* relay.stream;
  } finally {
    await sub.cancel();
    if (!relay.isClosed) await relay.close();
  }
}
