import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/repository/sync_maintenance_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class SyncMaintenanceController extends Notifier<SyncState> {
  SyncMaintenanceController();

  late SyncMaintenanceRepository _repository;
  late LoggingService _loggingService;

  @override
  SyncState build() {
    _repository = ref.watch(syncMaintenanceRepositoryProvider);
    _loggingService = getIt<LoggingService>();
    return const SyncState();
  }

  Future<void> syncAll({required Set<SyncStep> selectedSteps}) async {
    final orderedSteps = <SyncStep>[
      SyncStep.tags,
      SyncStep.measurables,
      SyncStep.categories,
      SyncStep.dashboards,
      SyncStep.habits,
      SyncStep.aiSettings,
    ].where(selectedSteps.contains).toList();

    if (orderedSteps.isEmpty) {
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      progress: 0,
      currentStep: orderedSteps.first,
      selectedSteps: selectedSteps,
      stepProgress: {
        for (final step in orderedSteps)
          step: const StepProgress(processed: 0, total: 0),
      },
    );

    // Define all sync operations using equal weighting
    final allOperations = <SyncStep,
        Future<void> Function({
      void Function(double)? onProgress,
      void Function(int processed, int total)? onDetailedProgress,
    })>{
      SyncStep.tags: _repository.syncTags,
      SyncStep.measurables: _repository.syncMeasurables,
      SyncStep.categories: _repository.syncCategories,
      SyncStep.dashboards: _repository.syncDashboards,
      SyncStep.habits: _repository.syncHabits,
      SyncStep.aiSettings: _repository.syncAiSettings,
    };

    final syncOperations = orderedSteps
        .map(
          (step) => (
            step: step,
            operation: allOperations[step]!,
          ),
        )
        .toList();

    final operationWeight =
        syncOperations.isEmpty ? 0.0 : 1 / syncOperations.length;

    try {
      var totalProgress = 0.0;

      // Execute each sync operation
      for (final operation in syncOperations) {
        state = state.copyWith(currentStep: operation.step);

        // Calculate the base progress for this operation
        final baseProgress = totalProgress;

        await operation.operation(
          onProgress: (progress) {
            final weightedProgress =
                baseProgress + (progress * operationWeight);
            state = state.copyWith(progress: (weightedProgress * 100).round());
          },
          onDetailedProgress: (processed, total) {
            final updatedProgress =
                Map<SyncStep, StepProgress>.from(state.stepProgress)
                  ..[operation.step] =
                      StepProgress(processed: processed, total: total);
            state = state.copyWith(stepProgress: updatedProgress);
          },
        );

        // Update total progress after operation completes
        totalProgress += operationWeight;
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
    NotifierProvider<SyncMaintenanceController, SyncState>(
  SyncMaintenanceController.new,
);
