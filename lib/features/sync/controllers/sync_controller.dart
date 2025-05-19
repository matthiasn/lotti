import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/services/sync_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._syncService) : super(const SyncState());

  final SyncService _syncService;
  final LoggingService _loggingService = getIt<LoggingService>();

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, progress: 0);

    // Define all sync operations
    final syncOperations = [
      (step: SyncStep.tags, operation: _syncService.syncTags),
      (step: SyncStep.measurables, operation: _syncService.syncMeasurables),
      (step: SyncStep.categories, operation: _syncService.syncCategories),
      (step: SyncStep.dashboards, operation: _syncService.syncDashboards),
      (step: SyncStep.habits, operation: _syncService.syncHabits),
    ];

    try {
      // Execute each sync operation
      for (var i = 0; i < syncOperations.length; i++) {
        final operation = syncOperations[i];
        state = state.copyWith(currentStep: operation.step);
        await operation.operation();

        // Calculate progress based on completed operations
        final progress = ((i + 1) / syncOperations.length * 100).round();
        state = state.copyWith(progress: progress);
      }

      // Mark as complete
      state = state.copyWith(
        currentStep: SyncStep.complete,
        isSyncing: false,
      );
    } catch (e, stackTrace) {
      final syncError = SyncError.fromException(
        e,
        stackTrace,
        _loggingService,
      );

      state = state.copyWith(
        isSyncing: false,
        error: syncError.toString(),
      );
      rethrow;
    }
  }

  void reset() {
    state = const SyncState();
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncController(syncService);
});
