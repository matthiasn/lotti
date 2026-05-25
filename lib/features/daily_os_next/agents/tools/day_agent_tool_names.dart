/// Tool name constants used by the Daily OS day agent.
abstract final class DayAgentToolNames {
  /// Records private observations for later template evolution.
  static const recordObservations = 'record_observations';

  /// Schedules the next time-based wake for this day agent.
  static const setNextWake = 'set_next_wake';

  /// Persists a user capture transcript.
  static const submitCapture = 'submit_capture';

  /// Persists model-parsed capture items.
  static const parseCaptureToItems = 'parse_capture_to_items';

  /// Finds existing task candidates for a capture phrase.
  static const matchToCorpus = 'match_to_corpus';

  /// Links a parsed capture item to a task.
  static const linkCapturePhraseToTask = 'link_capture_phrase_to_task';

  /// Removes a parsed capture item's task link.
  static const breakCaptureLink = 'break_capture_link';

  /// Lists task decisions that need reconcile attention.
  static const surfacePendingDecisions = 'surface_pending_decisions';

  /// Applies a reconcile triage action to a task.
  static const applyTriage = 'apply_triage';

  /// Proposes a new task from a capture phrase.
  static const createTaskFromPhrase = 'create_task_from_phrase';

  /// Foundation tools implemented by the day-agent workflow itself.
  static const foundationHandlerTools = <String>{
    setNextWake,
  };

  /// Capture/reconcile tools delegated to the capture service.
  static const captureReconcileTools = <String>{
    submitCapture,
    parseCaptureToItems,
    matchToCorpus,
    linkCapturePhraseToTask,
    breakCaptureLink,
    surfacePendingDecisions,
    applyTriage,
    createTaskFromPhrase,
  };

  /// Tools that require workflow-level handling instead of local strategy state.
  static const workflowHandlerTools = <String>{
    ...foundationHandlerTools,
    ...captureReconcileTools,
  };

  /// Whether [name] should be routed through the workflow handler.
  static bool isWorkflowHandlerTool(String name) {
    return workflowHandlerTools.contains(name);
  }

  /// Whether [name] is handled by the capture/reconcile service.
  static bool isCaptureReconcileTool(String name) {
    return captureReconcileTools.contains(name);
  }

  /// Whether [name] is the foundation wake scheduling tool.
  static bool isSetNextWakeTool(String name) {
    return foundationHandlerTools.contains(name);
  }
}
