import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/task_agent_tool_gate.dart';

void main() {
  group('visibleTaskAgentToolNames', () {
    test('permissive facts advertise exactly the enabled registry', () {
      final visible = visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive);

      expect(
        visible,
        {
          for (final definition in AgentToolRegistry.taskAgentTools)
            if (definition.enabled) definition.name,
        },
        reason: 'the migration default must not change what a wake advertises',
      );
    });

    test('hides the running-timer tool when no timer runs for this task', () {
      // The prompt exposes another task's timer only as an opaque range, so
      // there is no id to update and offering the tool invites inventing one.
      expect(
        visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(hasRunningTimerForTask: false),
        ),
        isNot(contains(TaskAgentToolNames.updateRunningTimer)),
      );
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive),
        contains(TaskAgentToolNames.updateRunningTimer),
      );
    });

    test('hides retraction and attention tools with nothing to act on', () {
      final visible = visibleTaskAgentToolNames(
        const TaskAgentWakeFacts(
          hasOpenProposals: false,
          hasActiveAttentionClaims: false,
        ),
      );

      expect(visible, isNot(contains(TaskAgentToolNames.retractSuggestions)));
      expect(
        visible,
        isNot(contains(TaskAgentToolNames.resolveAttentionRequest)),
      );
      // request_attention has no precondition — raising a new claim is always
      // available — so it must survive.
      expect(visible, contains(TaskAgentToolNames.requestAttention));
    });

    test('hides checklist and label tools when there is nothing to target', () {
      final visible = visibleTaskAgentToolNames(
        const TaskAgentWakeFacts(
          hasChecklistItems: false,
          hasLabelDefinitions: false,
        ),
      );

      expect(visible, isNot(contains(TaskAgentToolNames.updateChecklistItems)));
      expect(visible, isNot(contains(TaskAgentToolNames.assignTaskLabels)));
      // Adding items needs no existing item, so it is always available.
      expect(visible, contains(TaskAgentToolNames.addMultipleChecklistItems));
    });

    test('withholds update_report only when nothing is newer than it', () {
      expect(
        visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(hasNewerContentThanReport: false),
        ),
        isNot(contains(TaskAgentToolNames.updateReport)),
      );
      // A note that arrived saying nothing new is still newer, and materiality
      // is not something timestamps can judge — so the tool stays.
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive),
        contains(TaskAgentToolNames.updateReport),
      );
    });

    test('always offers the field tools that have no precondition', () {
      final visible = visibleTaskAgentToolNames(
        const TaskAgentWakeFacts(
          hasChecklistItems: false,
          hasTimeRecords: false,
          hasLabelDefinitions: false,
          hasNewerContentThanReport: false,
        ),
      );

      expect(
        visible,
        containsAll([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.setTaskStatus,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.createFollowUpTask,
          TaskAgentToolNames.linkTask,
        ]),
      );
    });
  });
}
