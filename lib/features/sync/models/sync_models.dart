enum SyncStep {
  tags,
  measurables,
  categories,
  dashboards,
  habits,
  aiSettings,
  complete,
}

class StepProgress {
  const StepProgress({
    required this.processed,
    required this.total,
  });

  final int processed;
  final int total;

  StepProgress copyWith({
    int? processed,
    int? total,
  }) {
    return StepProgress(
      processed: processed ?? this.processed,
      total: total ?? this.total,
    );
  }
}

class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress = 0,
    this.currentStep = SyncStep.tags,
    this.error,
    this.stepProgress = const {},
    this.selectedSteps = const {},
  });

  final bool isSyncing;
  final int progress;
  final SyncStep currentStep;
  final String? error;
  final Map<SyncStep, StepProgress> stepProgress;
  final Set<SyncStep> selectedSteps;

  SyncState copyWith({
    bool? isSyncing,
    int? progress,
    SyncStep? currentStep,
    String? error,
    Map<SyncStep, StepProgress>? stepProgress,
    Set<SyncStep>? selectedSteps,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      error: error,
      stepProgress: stepProgress ?? this.stepProgress,
      selectedSteps: selectedSteps ?? this.selectedSteps,
    );
  }
}
