import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
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
  return db.watchConfigFlag(enableMatrixFlag).map(
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
