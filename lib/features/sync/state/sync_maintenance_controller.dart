import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/lotti_logger.dart';

class SyncMaintenanceController extends StateNotifier<SyncState> {
  SyncMaintenanceController(this._repository) : super(const SyncState());

  final SyncMaintenanceRepository _repository;
  final LottiLogger _logger = getIt<LottiLogger>();

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, progress: 0);

    // Define all sync operations with their weight in the total progress
    final syncOperations = [
      (step: SyncStep.tags, operation: _repository.syncTags, weight: 0.2),
      (
        step: SyncStep.measurables,
        operation: _repository.syncMeasurables,
        weight: 0.2
      ),
      (
        step: SyncStep.categories,
        operation: _repository.syncCategories,
        weight: 0.2
      ),
      (
        step: SyncStep.dashboards,
        operation: _repository.syncDashboards,
        weight: 0.2
      ),
      (step: SyncStep.habits, operation: _repository.syncHabits, weight: 0.2),
    ];

    try {
      var totalProgress = 0.0;

      // Execute each sync operation
      for (var i = 0; i < syncOperations.length; i++) {
        final operation = syncOperations[i];
        state = state.copyWith(currentStep: operation.step);

        // Calculate the base progress for this operation
        final baseProgress = totalProgress;

        await operation.operation(
          onProgress: (progress) {
            // Calculate the weighted progress for this operation
            final weightedProgress =
                baseProgress + (progress * operation.weight);
            state = state.copyWith(progress: (weightedProgress * 100).round());
          },
        );

        // Update total progress after operation completes
        totalProgress += operation.weight;
        state = state.copyWith(progress: (totalProgress * 100).round());
      }

      // Mark as complete
      state = state.copyWith(
        currentStep: SyncStep.complete,
        isSyncing: false,
        progress: 100,
      );
    } catch (e, stackTrace) {
      final syncError = SyncError.fromException(
        e,
        stackTrace,
        _logger,
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
