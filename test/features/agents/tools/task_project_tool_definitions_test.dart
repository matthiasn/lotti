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

  group('create_task_project', () {
    final tool = toolNamed(TaskAgentToolNames.createTaskProject);

    test('requires exactly one string title', () {
      expect(tool.name, 'create_task_project');
      expect(tool.parameters['required'], ['title']);
      final properties = tool.parameters['properties'] as Map;
      expect(properties.keys, ['title']);
      expect((properties['title'] as Map)['type'], 'string');
      expect(
        (properties['title'] as Map)['description'],
        contains('exactly as the user wrote or said it'),
      );
      expect(tool.parameters['additionalProperties'], isFalse);
    });

    test(
      'waits for the user as a single, non-batch proposal, for a project the '
      'user named, pointing at set_task_project for one that exists',
      () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.createTaskProject),
        );
        expect(
          AgentToolRegistry.explodedBatchTools,
          isNot(contains(TaskAgentToolNames.createTaskProject)),
        );
        expect(tool.description, contains('user must confirm'));
        expect(tool.description, contains('explicitly names a project'));
        expect(tool.description, contains('use set_task_project instead'));
        expect(tool.description, contains('Never invent a project'));
      },
    );
  });
}
