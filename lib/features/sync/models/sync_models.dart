enum SyncStep {
  tags,
  measurables,
  categories,
  dashboards,
  habits,
  complete,
}

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress = 0,
    this.currentStep = SyncStep.tags,
    this.error,
  });

  final bool isSyncing;
  final int progress;
  final SyncStep currentStep;
  final String? error;

  SyncState copyWith({
    bool? isSyncing,
    int? progress,
    SyncStep? currentStep,
    String? error,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      error: error,
    );
  }
}
