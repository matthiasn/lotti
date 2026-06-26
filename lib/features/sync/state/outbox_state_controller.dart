import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/charts/utils.dart';
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

/// Number of days of outbox volume history to query and display.
const kOutboxVolumeDays = 30;

/// Future provider for daily outbox volume over the last [kOutboxVolumeDays].
/// Maps [OutboxDailyVolume] entries to [Observation]s with KB values.
final FutureProvider<List<Observation>> outboxDailyVolumeProvider =
    FutureProvider.autoDispose<List<Observation>>(
      outboxDailyVolume,
      name: 'outboxDailyVolumeProvider',
    );
Future<List<Observation>> outboxDailyVolume(Ref ref) async {
  final syncDb = ref.watch(syncDatabaseProvider);
  final volumes = await syncDb.getDailyOutboxVolume(days: kOutboxVolumeDays);
  return volumes.map((v) => Observation(v.date, v.totalBytes / 1024)).toList();
}

/// Looks up the global [SyncActivitySignaler]. Resolved through `getIt`
/// so tests that swap in a custom signaler do not need a parallel
/// override in every consumer.
final Provider<SyncActivitySignaler> syncActivitySignalerProvider =
    Provider.autoDispose<SyncActivitySignaler>(
      syncActivitySignaler,
      name: 'syncActivitySignalerProvider',
    );
SyncActivitySignaler syncActivitySignaler(Ref ref) =>
    getIt<SyncActivitySignaler>();

/// Per-packet TX pulses for the sidebar sync activity indicator. Emits
/// once per outbound event committed to the homeserver.
final StreamProvider<DateTime> syncActivityTxPulsesProvider =
    StreamProvider.autoDispose<DateTime>(
      syncActivityTxPulses,
      name: 'syncActivityTxPulsesProvider',
    );
Stream<DateTime> syncActivityTxPulses(Ref ref) =>
    ref.watch(syncActivitySignalerProvider).txPulses;

/// Per-packet RX pulses for the sidebar sync activity indicator. Emits
/// once per inbound event applied locally.
final StreamProvider<DateTime> syncActivityRxPulsesProvider =
    StreamProvider.autoDispose<DateTime>(
      syncActivityRxPulses,
      name: 'syncActivityRxPulsesProvider',
    );
Stream<DateTime> syncActivityRxPulses(Ref ref) =>
    ref.watch(syncActivitySignalerProvider).rxPulses;

/// Live depth of the inbound queue (active rows the worker can still
/// drain). Used by the sidebar sync activity indicator. Resolves the
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
  // (2) The `stats()` snapshot we just awaited is older than any live
  //     signal that arrived during the await, so emitting `stats.total`
  //     unconditionally and then replaying buffered live values would
  //     step the consumer backwards (e.g. `2 → 1 → 2`). The fix: buffer
  //     live values until `stats()` resolves, emit the snapshot ONLY
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
      final stats = await queue.stats();
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
