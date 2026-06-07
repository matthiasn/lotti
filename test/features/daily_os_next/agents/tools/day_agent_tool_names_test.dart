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
      DayAgentToolNames.commitDay,
      DayAgentToolNames.uncommitDay,
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
        'commit_day',
        'uncommit_day',
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
          DayAgentToolNames.commitDay,
          DayAgentToolNames.uncommitDay,
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
        DayAgentToolNames.isPlanTool(DayAgentToolNames.commitDay),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.uncommitDay),
        isTrue,
      );
      expect(
        DayAgentToolNames.isPlanTool(DayAgentToolNames.submitCapture),
        isFalse,
      );
    });

    test('routing membership is explicit for every tool name', () {
      // One row per tool: (name, capture/reconcile?, plan?, setNextWake?).
      // An adversarial move of a name between sets fails here by name.
      const routing = <String, (bool, bool, bool)>{
        DayAgentToolNames.recordObservations: (false, false, false),
        DayAgentToolNames.setNextWake: (false, false, true),
        DayAgentToolNames.submitCapture: (true, false, false),
        DayAgentToolNames.parseCaptureToItems: (true, false, false),
        DayAgentToolNames.matchToCorpus: (true, false, false),
        DayAgentToolNames.linkCapturePhraseToTask: (true, false, false),
        DayAgentToolNames.breakCaptureLink: (true, false, false),
        DayAgentToolNames.surfacePendingDecisions: (true, false, false),
        DayAgentToolNames.applyTriage: (true, false, false),
        DayAgentToolNames.createTaskFromPhrase: (true, false, false),
        DayAgentToolNames.draftDayPlan: (false, true, false),
        DayAgentToolNames.summarizeRecentPatterns: (false, true, false),
        DayAgentToolNames.proposePlanDiff: (false, true, false),
        DayAgentToolNames.acceptDiff: (false, true, false),
        DayAgentToolNames.revertDiff: (false, true, false),
        DayAgentToolNames.commitDay: (false, true, false),
        DayAgentToolNames.uncommitDay: (false, true, false),
      };

      for (final MapEntry(key: name, value: (capture, plan, wake))
          in routing.entries) {
        expect(
          DayAgentToolNames.isCaptureReconcileTool(name),
          capture,
          reason: '$name capture/reconcile',
        );
        expect(
          DayAgentToolNames.isPlanTool(name),
          plan,
          reason: '$name plan',
        );
        expect(
          DayAgentToolNames.isSetNextWakeTool(name),
          wake,
          reason: '$name setNextWake',
        );
        // The workflow handler covers all routed sets but not
        // strategy-local tools like recordObservations.
        expect(
          DayAgentToolNames.isWorkflowHandlerTool(name),
          capture || plan || wake,
          reason: '$name workflowHandler',
        );
      }
    });
  });
}
