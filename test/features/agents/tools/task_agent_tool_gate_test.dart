import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/task_agent_tool_gate.dart';

void main() {
  group('visibleTaskAgentToolNames', () {
    test('permissive facts advertise exactly the registry', () {
      final visible = visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive);

      expect(
        visible,
        {
          for (final definition in AgentToolRegistry.taskAgentTools)
            definition.name,
        },
        reason: 'the migration default must not change what a wake advertises',
      );
    });

    test('hides update_time_entry when the task has no time records', () {
      // With no entry — running or completed — there is no id to update, and
      // offering the tool invites inventing one.
      expect(
        visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(hasTimeRecords: false),
        ),
        isNot(contains(TaskAgentToolNames.updateTimeEntry)),
      );
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive),
        contains(TaskAgentToolNames.updateTimeEntry),
      );
    });

    group('related-task tools', () {
      const drillDown = [
        TaskAgentToolNames.getTaskTldr,
        TaskAgentToolNames.getTaskReport,
      ];

      test('without search or linked tasks, none is offered', () {
        final visible = visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(
            hasRelatedTaskSearch: false,
            hasLinkedTasks: false,
          ),
        );

        expect(visible, isNot(contains(TaskAgentToolNames.findRelatedTasks)));
        for (final name in drillDown) {
          expect(visible, isNot(contains(name)));
        }
      });

      test('linked tasks alone offer the drill-down, not the search', () {
        final visible = visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(hasRelatedTaskSearch: false),
        );

        expect(visible, isNot(contains(TaskAgentToolNames.findRelatedTasks)));
        expect(visible, containsAll(drillDown));
      });

      test('search alone offers the search and the drill-down into its '
          'hits', () {
        final visible = visibleTaskAgentToolNames(
          const TaskAgentWakeFacts(hasLinkedTasks: false),
        );

        expect(
          visible,
          containsAll([TaskAgentToolNames.findRelatedTasks, ...drillDown]),
        );
      });
    });

    test('never offers the retired running-timer tool', () {
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive),
        isNot(contains(TaskAgentToolNames.updateRunningTimer)),
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
      // Nor does saying a request could not be met: any wake may hit it.
      expect(visible, contains(TaskAgentToolNames.flagUnmetRequest));
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

    test('hides both project tools when the category has no projects', () {
      final hidden = visibleTaskAgentToolNames(
        const TaskAgentWakeFacts(hasCategoryProjects: false),
      );
      expect(hidden, isNot(contains(TaskAgentToolNames.getCategoryProjects)));
      expect(hidden, isNot(contains(TaskAgentToolNames.setTaskProject)));
      // A category with no projects is where a project the user names is most
      // likely missing: creating one stays on offer.
      expect(hidden, contains(TaskAgentToolNames.createTaskProject));
      // Only those two: everything else the permissive wake offers remains.
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive).difference(
          hidden,
        ),
        {
          TaskAgentToolNames.getCategoryProjects,
          TaskAgentToolNames.setTaskProject,
        },
      );
    });

    test('hides exactly the list and link tools without a repository', () {
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive).difference(
          visibleTaskAgentToolNames(
            const TaskAgentWakeFacts(hasPullRequestRepository: false),
          ),
        ),
        {
          TaskAgentToolNames.getUnlinkedPullRequests,
          TaskAgentToolNames.linkPullRequest,
        },
      );
    });

    test('hides exactly the refresh tool without a linked pull request', () {
      expect(
        visibleTaskAgentToolNames(TaskAgentWakeFacts.permissive).difference(
          visibleTaskAgentToolNames(
            const TaskAgentWakeFacts(hasLinkedPullRequests: false),
          ),
        ),
        {TaskAgentToolNames.refreshPullRequests},
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
