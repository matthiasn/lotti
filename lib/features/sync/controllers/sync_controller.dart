import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/services/sync_service.dart';

enum SyncStep {
  tags,
  measurables,
  categories,
  complete,
}

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.currentStep = SyncStep.tags,
    this.error,
    this.progress = 0,
  });

  final bool isSyncing;
  final SyncStep currentStep;
  final String? error;
  final int progress;

  SyncState copyWith({
    bool? isSyncing,
    SyncStep? currentStep,
    String? error,
    int? progress,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      currentStep: currentStep ?? this.currentStep,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._syncService) : super(const SyncState());

  final SyncService _syncService;

  Future<void> syncAll() async {
    state = state.copyWith(isSyncing: true, progress: 0);

    try {
      // Sync tags
      state = state.copyWith(currentStep: SyncStep.tags);
      await _syncService.syncTags();
      state = state.copyWith(progress: 33);

      // Sync measurables
      state = state.copyWith(currentStep: SyncStep.measurables);
      await _syncService.syncMeasurables();
      state = state.copyWith(progress: 66);

      // Sync categories
      state = state.copyWith(currentStep: SyncStep.categories);
      await _syncService.syncCategories();
      state = state.copyWith(progress: 100);

      // Mark as complete
      state = state.copyWith(
        currentStep: SyncStep.complete,
        isSyncing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
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
