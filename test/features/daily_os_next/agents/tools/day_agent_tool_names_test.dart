import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

void main() {
  group('DayAgentToolNames', () {
    const toolNames = <String>[
      DayAgentToolNames.recordObservations,
      DayAgentToolNames.setNextWake,
      DayAgentToolNames.searchMemory,
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
      DayAgentToolNames.proposeKnowledge,
      DayAgentToolNames.writeDaySummary,
    ];

    test('uses the wire names expected by the day-agent prompt', () {
      expect(toolNames, [
        'record_observations',
        'set_next_wake',
        'search_memory',
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
        'propose_knowledge',
        'write_day_summary',
      ]);
    });

    test('keeps all wire names distinct', () {
      expect(toolNames.toSet(), hasLength(toolNames.length));
    });

    test('every wire name except recordObservations is workflow-routed', () {
      // recordObservations is the only strategy-local tool; everything else is
      // routed through the workflow handler. Pinning this relationship means a
      // newly added tool that is left out of workflowHandlerTools (or this
      // manual toolNames list) is caught instead of silently passing.
      expect(
        toolNames,
        hasLength(DayAgentToolNames.workflowHandlerTools.length + 1),
      );
      expect(
        toolNames.toSet().difference(DayAgentToolNames.workflowHandlerTools),
        {DayAgentToolNames.recordObservations},
      );
    });

    test('groups workflow-routed tools by implementation owner', () {
      expect(
        DayAgentToolNames.foundationHandlerTools,
        {DayAgentToolNames.setNextWake, DayAgentToolNames.searchMemory},
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
        },
      );
      expect(
        DayAgentToolNames.knowledgeTools,
        {DayAgentToolNames.proposeKnowledge},
      );
      expect(
        DayAgentToolNames.weekContextTools,
        {DayAgentToolNames.writeDaySummary},
      );
      expect(
        DayAgentToolNames.workflowHandlerTools,
        {
          DayAgentToolNames.setNextWake,
          DayAgentToolNames.searchMemory,
          ...DayAgentToolNames.captureReconcileTools,
          ...DayAgentToolNames.planTools,
          ...DayAgentToolNames.knowledgeTools,
          ...DayAgentToolNames.weekContextTools,
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
        DayAgentToolNames.isPlanTool(DayAgentToolNames.submitCapture),
        isFalse,
      );
      expect(
        DayAgentToolNames.isWeekContextTool(DayAgentToolNames.writeDaySummary),
        isTrue,
      );
      expect(
        DayAgentToolNames.isWeekContextTool(DayAgentToolNames.draftDayPlan),
        isFalse,
      );
    });

    test('routing membership is explicit for every tool name', () {
      // One row per tool: (capture/reconcile?, plan?, setNextWake?, search?).
      // An adversarial move of a name between sets fails here by name.
      const routing = <String, (bool, bool, bool, bool)>{
        DayAgentToolNames.recordObservations: (false, false, false, false),
        DayAgentToolNames.setNextWake: (false, false, true, false),
        DayAgentToolNames.searchMemory: (false, false, false, true),
        DayAgentToolNames.submitCapture: (true, false, false, false),
        DayAgentToolNames.parseCaptureToItems: (true, false, false, false),
        DayAgentToolNames.matchToCorpus: (true, false, false, false),
        DayAgentToolNames.linkCapturePhraseToTask: (true, false, false, false),
        DayAgentToolNames.breakCaptureLink: (true, false, false, false),
        DayAgentToolNames.surfacePendingDecisions: (true, false, false, false),
        DayAgentToolNames.applyTriage: (true, false, false, false),
        DayAgentToolNames.createTaskFromPhrase: (true, false, false, false),
        DayAgentToolNames.draftDayPlan: (false, true, false, false),
        DayAgentToolNames.summarizeRecentPatterns: (false, true, false, false),
        DayAgentToolNames.proposePlanDiff: (false, true, false, false),
      };
      // Knowledge + week-context tools are workflow-routed through their own
      // services; assert their routing separately from the 4-tuple table.
      expect(
        DayAgentToolNames.isWorkflowHandlerTool(
          DayAgentToolNames.proposeKnowledge,
        ),
        isTrue,
      );
      expect(
        DayAgentToolNames.isWorkflowHandlerTool(
          DayAgentToolNames.writeDaySummary,
        ),
        isTrue,
      );

      for (final MapEntry(key: name, value: (capture, plan, wake, search))
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
        expect(
          DayAgentToolNames.isSearchMemoryTool(name),
          search,
          reason: '$name searchMemory',
        );
        // The workflow handler covers all routed sets but not
        // strategy-local tools like recordObservations.
        expect(
          DayAgentToolNames.isWorkflowHandlerTool(name),
          capture || plan || wake || search,
          reason: '$name workflowHandler',
        );
      }
    });

    test('user-verdict tool names stay structurally unreachable from the model '
        '(ADR 0006)', () {
      // accept_diff / revert_diff / commit_day / uncommit_day are the user's
      // verdicts per ADR 0006: the UI invokes the corresponding
      // DayAgentPlanService methods directly, and the model must never see
      // them as tools. String literals are used deliberately — the constants
      // were removed, and this test guards against their reintroduction.
      const userVerdicts = <String>{
        'accept_diff',
        'revert_diff',
        'commit_day',
        'uncommit_day',
      };
      expect(
        DayAgentToolNames.planTools.intersection(userVerdicts),
        isEmpty,
      );
      expect(
        DayAgentToolNames.workflowHandlerTools.intersection(userVerdicts),
        isEmpty,
      );
    });
  });
}
