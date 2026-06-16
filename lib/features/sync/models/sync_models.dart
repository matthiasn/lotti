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
  backfillAgentEntityClocks,
  backfillAgentLinkClocks,
  agentEntities,
  agentLinks,
  complete,
}

/// Per-step progress counters (`processed`/`total`) for the re-sync UI.
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

/// Immutable snapshot of a re-sync run: whether it is active, overall
/// [progress] percent, the [currentStep], any [error], the per-step counters,
/// and which [selectedSteps] the user opted into. Note [copyWith] intentionally
/// clears [error] when not supplied so a fresh state never carries a stale one.
class SyncState {
  const SyncState({
    this.isSyncing = false,
    this.progress = 0,
    this.currentStep = SyncStep.measurables,
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
