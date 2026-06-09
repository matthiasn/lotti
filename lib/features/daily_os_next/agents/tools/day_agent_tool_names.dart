/// Tool name constants used by the Daily OS day agent.
abstract final class DayAgentToolNames {
  /// Records private observations for later template evolution.
  static const recordObservations = 'record_observations';

  /// Schedules the next time-based wake for this day agent.
  static const setNextWake = 'set_next_wake';

  /// Recalls raw memory-log detail folded out of the compacted summary.
  static const searchMemory = 'search_memory';

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

  /// Persists a drafted day plan emitted by the model.
  static const draftDayPlan = 'draft_day_plan';

  /// Builds transient learning cards from recent day-agent history.
  static const summarizeRecentPatterns = 'summarize_recent_patterns';

  /// Proposes a structured plan diff (`moved`/`added`/`dropped` blocks).
  static const proposePlanDiff = 'propose_plan_diff';

  /// Proposes a durable planner-knowledge entry ("memorize what I tell you").
  static const proposeKnowledge = 'propose_knowledge';

  /// Foundation tools implemented by the day-agent workflow itself.
  static const foundationHandlerTools = <String>{
    setNextWake,
    searchMemory,
  };

  /// Durable-knowledge tools delegated to the knowledge service.
  static const knowledgeTools = <String>{
    proposeKnowledge,
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

  /// Plan-mutation tools delegated to the plan service (draft + refine).
  ///
  /// Deliberately excludes the user-verdict actions (accept/revert diff,
  /// commit/uncommit day): those are the user's decisions per ADR 0006 and
  /// must stay structurally unreachable from the model. The UI invokes the
  /// corresponding `DayAgentPlanService` methods directly.
  static const planTools = <String>{
    draftDayPlan,
    summarizeRecentPatterns,
    proposePlanDiff,
  };

  /// Tools that require workflow-level handling instead of local strategy state.
  static const workflowHandlerTools = <String>{
    ...foundationHandlerTools,
    ...captureReconcileTools,
    ...planTools,
    ...knowledgeTools,
  };

  /// Whether [name] should be routed through the workflow handler.
  static bool isWorkflowHandlerTool(String name) {
    return workflowHandlerTools.contains(name);
  }

  /// Whether [name] is handled by the capture/reconcile service.
  static bool isCaptureReconcileTool(String name) {
    return captureReconcileTools.contains(name);
  }

  /// Whether [name] is handled by the day-plan service.
  static bool isPlanTool(String name) {
    return planTools.contains(name);
  }

  /// Whether [name] is handled by the durable-knowledge service.
  static bool isKnowledgeTool(String name) {
    return knowledgeTools.contains(name);
  }

  /// Whether [name] is the foundation wake scheduling tool.
  static bool isSetNextWakeTool(String name) {
    return name == setNextWake;
  }

  /// Whether [name] is the memory-recall tool.
  static bool isSearchMemoryTool(String name) {
    return name == searchMemory;
  }
}
