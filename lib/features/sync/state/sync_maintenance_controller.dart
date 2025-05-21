import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class SyncMaintenanceController extends StateNotifier<SyncState> {
  SyncMaintenanceController(this._repository) : super(const SyncState());

  final SyncMaintenanceRepository _repository;
  final LoggingService _loggingService = getIt<LoggingService>();

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, progress: 0);

    // Define all sync operations
    final syncOperations = [
      (step: SyncStep.tags, operation: _repository.syncTags),
      (step: SyncStep.measurables, operation: _repository.syncMeasurables),
      (step: SyncStep.categories, operation: _repository.syncCategories),
      (step: SyncStep.dashboards, operation: _repository.syncDashboards),
      (step: SyncStep.habits, operation: _repository.syncHabits),
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
    StateNotifierProvider<SyncMaintenanceController, SyncState>((ref) {
  final repository = ref.watch(syncMaintenanceRepositoryProvider);
  return SyncMaintenanceController(repository);
});
