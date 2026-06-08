/// Data structures the mock day-agent surface returns to the UI.
///
/// These mirror the eventual real agent contract documented in
/// `docs/implementation_plans/2026-05-25_day_agent_layer.md` (§E).
/// When the real `DayAgentWorkflow` lands, these structures stay; only
/// the implementation behind `DayAgentInterface` changes.
///
/// The models are grouped by surface into sibling part files:
/// - [CaptureId] / [ParsedItem] / [PendingItem] — capture & triage
///   (`day_agent_capture_models.dart`).
/// - [TimeBlock] / [EnergyBand] — the Day timeline
///   (`day_agent_timeline_models.dart`).
/// - [DraftPlan] / [AgendaItem] — drafted plans & agenda
///   (`day_agent_plan_models.dart`).
/// - [LearningCard] / [PlanDiff] — learning cards & refine diffs
///   (`day_agent_learning_models.dart`).
/// - [CompletedItem] / [CarryoverItem] / [ShutdownMetrics] — shutdown &
///   corpus (`day_agent_shutdown_models.dart`).
library;

import 'package:flutter/foundation.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

// Re-exported so UI consumers can `import 'day_agent_models.dart'` and
// reach the canonical agent-side enums without a second import.
export 'package:lotti/features/agents/model/agent_enums.dart'
    show ParsedItemConfidence, ParsedItemKind;

part 'day_agent_capture_models.dart';
part 'day_agent_timeline_models.dart';
part 'day_agent_plan_models.dart';
part 'day_agent_learning_models.dart';
part 'day_agent_shutdown_models.dart';
