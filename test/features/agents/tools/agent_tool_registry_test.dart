import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('AgentToolDefinition', () {
    test('stores name, description, and parameters', () {
      const def = AgentToolDefinition(
        name: 'my_tool',
        description: 'Does something useful.',
        parameters: {
          'type': 'object',
          'properties': {
            'arg1': {'type': 'string'},
          },
          'required': ['arg1'],
        },
      );

      expect(def.name, equals('my_tool'));
      expect(def.description, equals('Does something useful.'));
      expect(def.parameters['type'], equals('object'));
      expect(
        (def.parameters['properties'] as Map)['arg1'],
        equals({'type': 'string'}),
      );
      expect(def.parameters['required'], equals(['arg1']));
    });
  });

  group('AgentToolRegistry.taskAgentTools', () {
    test('contains exactly 7 tool definitions', () {
      expect(AgentToolRegistry.taskAgentTools, hasLength(7));
    });

    test('all tools have non-empty name and description', () {
      for (final tool in AgentToolRegistry.taskAgentTools) {
        expect(tool.name, isNotEmpty, reason: 'Tool name must not be empty');
        expect(
          tool.description,
          isNotEmpty,
          reason: 'Tool description must not be empty for ${tool.name}',
        );
      }
    });

    test('all tools have object-type parameter schemas with required fields',
        () {
      for (final tool in AgentToolRegistry.taskAgentTools) {
        expect(
          tool.parameters['type'],
          equals('object'),
          reason: '${tool.name} parameters must be type=object',
        );
        expect(
          tool.parameters['properties'],
          isA<Map<String, dynamic>>(),
          reason: '${tool.name} must have properties',
        );
        expect(
          tool.parameters['required'],
          isA<List<dynamic>>(),
          reason: '${tool.name} must have required list',
        );
        final required = tool.parameters['required'] as List;
        expect(
          required,
          isNotEmpty,
          reason: '${tool.name} must require at least one parameter',
        );
      }
    });

    test('tool names are unique', () {
      final names =
          AgentToolRegistry.taskAgentTools.map((t) => t.name).toList();
      expect(names.toSet().length, equals(names.length));
    });

    group('set_task_title', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'set_task_title');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('set_task_title'));
        expect(
          tool.description,
          equals('Update the title of the task.'),
        );
      });

      test('requires a string title parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final titleProp = properties['title'] as Map;
        expect(titleProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('title'));
      });
    });

    group('update_task_estimate', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'update_task_estimate');
      });

      test('has correct name', () {
        expect(tool.name, equals('update_task_estimate'));
      });

      test('requires a string estimate parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final estimateProp = properties['estimate'] as Map;
        expect(estimateProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('estimate'));
      });
    });

    group('update_task_due_date', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'update_task_due_date');
      });

      test('has correct name', () {
        expect(tool.name, equals('update_task_due_date'));
      });

      test('requires a string dueDate parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final dueDateProp = properties['dueDate'] as Map;
        expect(dueDateProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('dueDate'));
      });
    });

    group('update_task_priority', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'update_task_priority');
      });

      test('has correct name', () {
        expect(tool.name, equals('update_task_priority'));
      });

      test('requires a string priority parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final priorityProp = properties['priority'] as Map;
        expect(priorityProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('priority'));
      });
    });

    group('add_multiple_checklist_items', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'add_multiple_checklist_items');
      });

      test('has correct name', () {
        expect(tool.name, equals('add_multiple_checklist_items'));
      });

      test('requires an array items parameter with string items', () {
        final properties = tool.parameters['properties'] as Map;
        final itemsProp = properties['items'] as Map;
        expect(itemsProp['type'], equals('array'));
        expect(
          (itemsProp['items'] as Map)['type'],
          equals('string'),
        );
        expect(tool.parameters['required'], contains('items'));
      });
    });

    group('update_checklist_items', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'update_checklist_items');
      });

      test('has correct name', () {
        expect(tool.name, equals('update_checklist_items'));
      });

      test('requires an array updates parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final updatesProp = properties['updates'] as Map;
        expect(updatesProp['type'], equals('array'));
        final itemsSchema = updatesProp['items'] as Map;
        expect(itemsSchema['type'], equals('object'));
        final itemProps = itemsSchema['properties'] as Map;
        expect((itemProps['id'] as Map)['type'], equals('string'));
        expect((itemProps['isChecked'] as Map)['type'], equals('boolean'));
        expect(tool.parameters['required'], contains('updates'));
      });
    });

    group('record_observations', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'record_observations');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('record_observations'));
        expect(tool.description, contains('observations'));
      });

      test('requires an array observations parameter with string items', () {
        final properties = tool.parameters['properties'] as Map;
        final obsProp = properties['observations'] as Map;
        expect(obsProp['type'], equals('array'));
        expect(
          (obsProp['items'] as Map)['type'],
          equals('string'),
        );
        expect(tool.parameters['required'], contains('observations'));
      });
    });
  });
}
