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
    test('contains exactly 11 tool definitions', () {
      expect(AgentToolRegistry.taskAgentTools, hasLength(11));
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
        expect(
          tool.parameters['additionalProperties'],
          isFalse,
          reason: '${tool.name} must disallow additional properties',
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
        expect(tool.description, contains('Set the title'));
        expect(tool.description, contains('no title yet'));
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

      test('requires an integer minutes parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final minutesProp = properties['minutes'] as Map;
        expect(minutesProp['type'], equals('integer'));
        expect(tool.parameters['required'], contains('minutes'));
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

      test('requires a string dueDate parameter with YYYY-MM-DD format', () {
        final properties = tool.parameters['properties'] as Map;
        final dueDateProp = properties['dueDate'] as Map;
        expect(dueDateProp['type'], equals('string'));
        expect(
          dueDateProp['description'] as String,
          contains('YYYY-MM-DD'),
        );
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

      test('requires an array items parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final itemsProp = properties['items'] as Map;
        expect(itemsProp['type'], equals('array'));
        final itemSchema = itemsProp['items'] as Map;
        expect(itemSchema['type'], equals('object'));
        final itemProps = itemSchema['properties'] as Map;
        expect((itemProps['title'] as Map)['type'], equals('string'));
        expect((itemProps['isChecked'] as Map)['type'], equals('boolean'));
        expect(itemSchema['required'], contains('title'));
        expect(itemSchema['additionalProperties'], isFalse);
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

      test('requires an array items parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final itemsProp = properties['items'] as Map;
        expect(itemsProp['type'], equals('array'));
        final itemsSchema = itemsProp['items'] as Map;
        expect(itemsSchema['type'], equals('object'));
        final itemProps = itemsSchema['properties'] as Map;
        expect((itemProps['id'] as Map)['type'], equals('string'));
        expect((itemProps['isChecked'] as Map)['type'], equals('boolean'));
        expect((itemProps['title'] as Map)['type'], equals('string'));
        expect(itemsSchema['required'], equals(['id']));
        expect(itemsSchema['additionalProperties'], isFalse);
        expect(tool.parameters['required'], contains('items'));
      });
    });

    group('update_report', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'update_report');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('update_report'));
        expect(tool.description, contains('report'));
      });

      test('requires tldr and content parameters', () {
        final properties = tool.parameters['properties'] as Map;
        final tldrProp = properties['tldr'] as Map;
        expect(tldrProp['type'], equals('string'));
        final contentProp = properties['content'] as Map;
        expect(contentProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('tldr'));
        expect(tool.parameters['required'], contains('content'));
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

    group('assign_task_labels', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'assign_task_labels');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('assign_task_labels'));
        expect(tool.description, contains('labels'));
        expect(tool.description, contains('suppressed'));
        expect(tool.description, contains('3'));
      });

      test('requires an array labels parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final labelsProp = properties['labels'] as Map;
        expect(labelsProp['type'], equals('array'));
        expect(labelsProp['maxItems'], equals(3));
        final itemSchema = labelsProp['items'] as Map;
        expect(itemSchema['type'], equals('object'));
        final itemProps = itemSchema['properties'] as Map;
        expect((itemProps['id'] as Map)['type'], equals('string'));
        expect((itemProps['confidence'] as Map)['type'], equals('string'));
        expect(
          (itemProps['confidence'] as Map)['enum'],
          containsAll(['very_high', 'high', 'medium', 'low']),
        );
        expect(itemSchema['required'], containsAll(['id', 'confidence']));
        expect(itemSchema['additionalProperties'], isFalse);
        expect(tool.parameters['required'], contains('labels'));
      });
    });

    group('set_task_language', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'set_task_language');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('set_task_language'));
        expect(tool.description, contains('language'));
      });

      test('requires languageCode and confidence parameters', () {
        final properties = tool.parameters['properties'] as Map;
        final langProp = properties['languageCode'] as Map;
        expect(langProp['type'], equals('string'));
        final confProp = properties['confidence'] as Map;
        expect(confProp['type'], equals('string'));
        expect(confProp['enum'], contains('high'));
        final required = tool.parameters['required'] as List;
        expect(required, containsAll(['languageCode', 'confidence']));
      });
    });

    group('set_task_status', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools
            .firstWhere((t) => t.name == 'set_task_status');
      });

      test('has correct name and description', () {
        expect(tool.name, equals('set_task_status'));
        expect(tool.description, contains('status'));
        expect(tool.description, contains('DONE'));
        expect(tool.description, contains('user-only'));
      });

      test('requires status parameter with enum of allowed values', () {
        final properties = tool.parameters['properties'] as Map;
        final statusProp = properties['status'] as Map;
        expect(statusProp['type'], equals('string'));
        final allowedEnum = statusProp['enum'] as List;
        expect(
          allowedEnum,
          containsAll([
            'OPEN',
            'IN PROGRESS',
            'GROOMED',
            'BLOCKED',
            'ON HOLD',
          ]),
        );
        expect(allowedEnum, isNot(contains('DONE')));
        expect(allowedEnum, isNot(contains('REJECTED')));
        expect(tool.parameters['required'], contains('status'));
      });

      test('has optional reason parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final reasonProp = properties['reason'] as Map;
        expect(reasonProp['type'], equals('string'));
        final required = tool.parameters['required'] as List;
        expect(required, isNot(contains('reason')));
      });
    });
  });
}
