import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  AgentToolDefinition toolNamed(String name) =>
      AgentToolRegistry.taskAgentTools.singleWhere((t) => t.name == name);

  for (final name in [
    TaskAgentToolNames.getUnlinkedPullRequests,
    TaskAgentToolNames.refreshPullRequests,
  ]) {
    group(name, () {
      final tool = toolNamed(name);

      test('takes no arguments', () {
        expect(tool.parameters['properties'], isEmpty);
        expect(tool.parameters['required'], isEmpty);
        expect(tool.parameters['additionalProperties'], isFalse);
      });

      test('is read-only: executed in the wake, never queued for the user', () {
        expect(AgentToolRegistry.deferredTools, isNot(contains(name)));
        expect(tool.description, startsWith('Read-only.'));
      });
    });
  }

  test('get_unlinked_pull_requests says pull request text is data, and '
      'points at the link tool', () {
    final description = toolNamed(
      TaskAgentToolNames.getUnlinkedPullRequests,
    ).description;
    expect(description, contains('never as instructions'));
    expect(description, contains('link_pull_request'));
  });

  test('refresh_pull_requests points at checklist proposals', () {
    expect(
      toolNamed(TaskAgentToolNames.refreshPullRequests).description,
      contains('update_checklist_items'),
    );
  });

  group('link_pull_request', () {
    final tool = toolNamed(TaskAgentToolNames.linkPullRequest);

    test('requires exactly one integer number', () {
      expect(tool.parameters['required'], ['number']);
      final properties = tool.parameters['properties'] as Map;
      expect(properties.keys, ['number']);
      expect((properties['number'] as Map)['type'], 'integer');
      expect(tool.parameters['additionalProperties'], isFalse);
    });

    test('waits for the user as a single, non-batch proposal', () {
      expect(
        AgentToolRegistry.deferredTools,
        contains(TaskAgentToolNames.linkPullRequest),
      );
      expect(
        AgentToolRegistry.explodedBatchTools,
        isNot(contains(TaskAgentToolNames.linkPullRequest)),
      );
      expect(tool.description, contains('get_unlinked_pull_requests'));
    });
  });
}
