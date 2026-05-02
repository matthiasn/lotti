import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outbox_state_controller.g.dart';

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
@riverpod
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
@riverpod
Stream<int> outboxPendingCount(Ref ref) {
  final syncDb = ref.watch(syncDatabaseProvider);
  return syncDb.watchOutboxCount();
}

/// Number of days of outbox volume history to query and display.
const kOutboxVolumeDays = 30;

/// Future provider for daily outbox volume over the last [kOutboxVolumeDays].
/// Maps [OutboxDailyVolume] entries to [Observation]s with KB values.
@riverpod
Future<List<Observation>> outboxDailyVolume(Ref ref) async {
  final syncDb = ref.watch(syncDatabaseProvider);
  final volumes = await syncDb.getDailyOutboxVolume(days: kOutboxVolumeDays);
  return volumes.map((v) => Observation(v.date, v.totalBytes / 1024)).toList();
}

/// Looks up the global [SyncActivitySignaler]. Resolved through `getIt`
/// so tests that swap in a custom signaler do not need a parallel
/// override in every consumer.
@riverpod
SyncActivitySignaler syncActivitySignaler(Ref ref) =>
    getIt<SyncActivitySignaler>();

/// Per-packet TX pulses for the sidebar sync activity indicator. Emits
/// once per outbound event committed to the homeserver.
@riverpod
Stream<DateTime> syncActivityTxPulses(Ref ref) =>
    ref.watch(syncActivitySignalerProvider).txPulses;

/// Per-packet RX pulses for the sidebar sync activity indicator. Emits
/// once per inbound event applied locally.
@riverpod
Stream<DateTime> syncActivityRxPulses(Ref ref) =>
    ref.watch(syncActivitySignalerProvider).rxPulses;

/// Live depth of the inbound queue (active rows the worker can still
/// drain). Used by the sidebar sync activity indicator. Resolves the
/// queue lazily via `MatrixService.queueCoordinator` because the
/// coordinator is created during app boot, not during provider
/// construction.
@riverpod
Stream<int> inboundQueueDepth(Ref ref) {
  final matrixService = ref.watch(matrixServiceProvider);
  return _inboundQueueDepthStream(matrixService.queueCoordinator.queue);
}

Stream<int> _inboundQueueDepthStream(InboundQueue queue) async* {
  // Seed the stream with the current depth so the UI does not have to
  // wait for the next emission to render a non-zero count.
  try {
    final stats = await queue.stats();
    yield stats.total;
  } catch (_) {
    // Initial paint failures are non-fatal; the live signal will
    // provide a count on the next emission.
  }
  yield* queue.depthChanges.map((signal) => signal.total);
}
