import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

void main() {
  group('DayAgentToolNames', () {
    const toolNames = <String>[
      DayAgentToolNames.recordObservations,
      DayAgentToolNames.setNextWake,
      DayAgentToolNames.submitCapture,
      DayAgentToolNames.parseCaptureToItems,
      DayAgentToolNames.matchToCorpus,
      DayAgentToolNames.linkCapturePhraseToTask,
      DayAgentToolNames.breakCaptureLink,
      DayAgentToolNames.surfacePendingDecisions,
      DayAgentToolNames.applyTriage,
      DayAgentToolNames.createTaskFromPhrase,
      DayAgentToolNames.draftDayPlan,
      DayAgentToolNames.summarizeRecentPatterns,
      DayAgentToolNames.proposePlanDiff,
      DayAgentToolNames.acceptDiff,
      DayAgentToolNames.revertDiff,
    ];

    test('uses the wire names expected by the day-agent prompt', () {
      expect(toolNames, [
        'record_observations',
        'set_next_wake',
        'submit_capture',
        'parse_capture_to_items',
        'match_to_corpus',
        'link_capture_phrase_to_task',
        'break_capture_link',
        'surface_pending_decisions',
        'apply_triage',
        'create_task_from_phrase',
        'draft_day_plan',
        'summarize_recent_patterns',
        'propose_plan_diff',
        'accept_diff',
        'revert_diff',
      ]);
    });

    test('keeps all wire names distinct', () {
      expect(toolNames.toSet(), hasLength(toolNames.length));
    });

    test('groups workflow-routed tools by implementation owner', () {
      expect(
        DayAgentToolNames.foundationHandlerTools,
        {DayAgentToolNames.setNextWake},
      );
      expect(
        DayAgentToolNames.captureReconcileTools,
        {
          DayAgentToolNames.submitCapture,
          DayAgentToolNames.parseCaptureToItems,
          DayAgentToolNames.matchToCorpus,
          DayAgentToolNames.linkCapturePhraseToTask,
          DayAgentToolNames.breakCaptureLink,
          DayAgentToolNames.surfacePendingDecisions,
          DayAgentToolNames.applyTriage,
          DayAgentToolNames.createTaskFromPhrase,
        },
      );
      expect(
        DayAgentToolNames.planTools,
        {
          DayAgentToolNames.draftDayPlan,
          DayAgentToolNames.summarizeRecentPatterns,
          DayAgentToolNames.proposePlanDiff,
          DayAgentToolNames.acceptDiff,
          DayAgentToolNames.revertDiff,
        },
      );
      expect(
        DayAgentToolNames.workflowHandlerTools,
        {
          DayAgentToolNames.setNextWake,
          ...DayAgentToolNames.captureReconcileTools,
          ...DayAgentToolNames.planTools,
        },
      );
    });

    test('classifies routed tools consistently', () {
      expect(
        DayAgentToolNames.isWorkflowHandlerTool(
          DayAgentToolNames.recordObservations,
        ),
        isFalse,
      );
      expect(
        DayAgentToolNames.isWorkflowHandlerTool(DayAgentToolNames.setNextWake),
        isTrue,
      );
      expect(
        DayAgentToolNames.isCaptureReconcileTool(
          DayAgentToolNames.submitCapture,
        ),
        isTrue,
      );
      expect(
        DayAgentToolNames.isCaptureReconcileTool(DayAgentToolNames.setNextWake),
        isFalse,
      );
      expect(
        DayAgentToolNames.isSetNextWakeTool(DayAgentToolNames.setNextWake),
        isTrue,
      );
      expect(
        DayAgentToolNames.isSetNextWakeTool(DayAgentToolNames.submitCapture),
        isFalse,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.draftDayPlan),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.proposePlanDiff),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.acceptDiff),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.revertDiff),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.submitCapture),
        isFalse,
      );
    });
  });
}
