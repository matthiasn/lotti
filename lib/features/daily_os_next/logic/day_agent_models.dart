/// Data structures the mock day-agent surface returns to the UI.
///
/// These mirror the eventual real agent contract documented in
/// `docs/implementation_plans/2026-05-25_day_agent_layer.md` (§E).
/// When the real `DayAgentWorkflow` lands, these structures stay; only
/// the implementation behind `DayAgentInterface` changes.
///
/// The models live in sibling libraries grouped by surface, all re-exported
/// here so UI consumers keep a single import:
/// - `CaptureId` / `ParsedItem` / `PendingItem` — capture & triage
///   (`day_agent_capture_models.dart`).
/// - `TimeBlock` / `EnergyBand` — the Day timeline
///   (`day_agent_timeline_models.dart`).
/// - `DraftPlan` / `AgendaItem` — drafted plans & agenda
///   (`day_agent_plan_models.dart`).
/// - `LearningCard` / `PlanDiff` — learning cards & refine diffs
///   (`day_agent_learning_models.dart`).
/// - `CompletedItem` / `CarryoverItem` / `ShutdownMetrics` — shutdown &
///   corpus (`day_agent_shutdown_models.dart`).
library;

// Re-exported so UI consumers can `import 'day_agent_models.dart'` and
// reach the canonical agent-side enums without a second import.
export 'package:lotti/features/agents/model/agent_enums.dart'
    show ParsedItemConfidence, ParsedItemKind;
export 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
export 'package:lotti/features/daily_os_next/logic/day_agent_learning_models.dart';
export 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';
export 'package:lotti/features/daily_os_next/logic/day_agent_shutdown_models.dart';
export 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';
