import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  AgentToolDefinition toolNamed(String name) =>
      AgentToolRegistry.taskAgentTools.singleWhere((t) => t.name == name);

  group('get_category_projects', () {
    final tool = toolNamed(TaskAgentToolNames.getCategoryProjects);

    test('takes no arguments', () {
      expect(tool.name, 'get_category_projects');
      expect(tool.parameters['properties'], isEmpty);
      expect(tool.parameters['required'], isEmpty);
      expect(tool.parameters['additionalProperties'], isFalse);
    });

    test('is read-only: executed in the wake, never queued for the user', () {
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.getCategoryProjects)),
      );
      expect(tool.description, contains('Read-only'));
      expect(tool.description, contains('set_task_project'));
    });
  });

  group('set_task_project', () {
    final tool = toolNamed(TaskAgentToolNames.setTaskProject);

    test('requires exactly one string projectId', () {
      expect(tool.name, 'set_task_project');
      expect(tool.parameters['required'], ['projectId']);
      final properties = tool.parameters['properties'] as Map;
      expect(properties.keys, ['projectId']);
      expect((properties['projectId'] as Map)['type'], 'string');
      expect(tool.parameters['additionalProperties'], isFalse);
    });

    test('waits for the user as a single, non-batch proposal', () {
      expect(
        AgentToolRegistry.deferredTools,
        contains(TaskAgentToolNames.setTaskProject),
      );
      expect(
        AgentToolRegistry.explodedBatchTools,
        isNot(contains(TaskAgentToolNames.setTaskProject)),
      );
      expect(tool.description, contains('get_category_projects'));
    });
  });
}
