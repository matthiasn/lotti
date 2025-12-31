import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outbox_state_controller.g.dart';

/// Status of individual outbox items in the sync queue.
/// Used by SyncDatabase and outbox-related components.
enum OutboxStatus {
  pending,
  sent,
  error,
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
