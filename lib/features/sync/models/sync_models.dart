/// Ordered phases of a full re-sync run, as surfaced in the sync settings UI.
///
/// Each entity-type step (measurables…agentLinks) re-enqueues that category's
/// rows to the outbox; the two `backfill…Clocks` steps repair missing vector
/// clocks on agent rows before they are re-sent. [complete] is the terminal
/// marker.
enum SyncStep {
  measurables,
  labels,
  categories,
  dashboards,
  habits,
  aiSettings,
  savedTaskFilters,
  backfillAgentEntityClocks,
  backfillAgentLinkClocks,
  complete,
}

/// Per-step progress counters (`processed`/`total`) for the re-sync UI.
class StepProgress {
  const StepProgress({required this.processed, required this.total});

  final int processed;
  final int total;
}

/// Immutable snapshot of a re-sync run: whether it is active, overall
/// [progress] percent, the [currentStep], the per-step counters, and which
/// [selectedSteps] the user opted into.
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress = 0,
    this.currentStep = SyncStep.measurables,
    this.stepProgress = const {},
    this.selectedSteps = const {},
  });

  final bool isSyncing;
  final int progress;
  final SyncStep currentStep;
  final Map<SyncStep, StepProgress> stepProgress;
  final Set<SyncStep> selectedSteps;

  SyncState copyWith({
    bool? isSyncing,
    int? progress,
    SyncStep? currentStep,
    Map<SyncStep, StepProgress>? stepProgress,
    Set<SyncStep>? selectedSteps,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      stepProgress: stepProgress ?? this.stepProgress,
      selectedSteps: selectedSteps ?? this.selectedSteps,
    );
  }
}
