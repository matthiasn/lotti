import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_policy.dart';

void main() {
  test('first publication is required even without material mutations', () {
    for (final tools in [
      <String>[],
      [TaskAgentToolNames.setTaskLanguage],
    ]) {
      expect(
        TaskAgentReportPolicy.requiresReport(
          hasExistingReport: false,
          successfulToolNames: tools,
        ),
        isTrue,
      );
    }
  });

  test(
    'housekeeping preserves an existing report but material work does not',
    () {
      const housekeeping = [
        TaskAgentToolNames.assignTaskLabel,
        TaskAgentToolNames.assignTaskLabels,
        TaskAgentToolNames.setTaskLanguage,
      ];
      expect(
        TaskAgentReportPolicy.requiresReport(
          hasExistingReport: true,
          successfulToolNames: housekeeping,
        ),
        isFalse,
      );
      for (final tool in [
        TaskAgentToolNames.addChecklistItem,
        TaskAgentToolNames.updateTaskDueDate,
        TaskAgentToolNames.updateTaskEstimate,
      ]) {
        expect(
          TaskAgentReportPolicy.requiresReport(
            hasExistingReport: true,
            successfulToolNames: [...housekeeping, tool],
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'changed IDs are stable and only follow-up wakes need restraint guidance',
    () {
      final followUp = TaskAgentReportPolicy.changedEntitiesContext(
        triggerTokens: ['note-b', 'note-a'],
        hasReport: true,
      );
      expect(followUp, contains('note-a, note-b'));
      expect(followUp, contains(TaskAgentReportPolicy.changedEntitiesRule));
      expect(
        TaskAgentReportPolicy.changedEntitiesContext(
          triggerTokens: ['note-a'],
          hasReport: false,
        ),
        isNot(contains(TaskAgentReportPolicy.changedEntitiesRule)),
      );
      expect(
        TaskAgentReportPolicy.changedEntitiesContext(
          triggerTokens: [],
          hasReport: true,
        ),
        isEmpty,
      );
    },
  );
}
