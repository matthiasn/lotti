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
    test('contains exactly 16 tool definitions', () {
      expect(AgentToolRegistry.taskAgentTools, hasLength(16));
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

    test(
      'all tools have object-type parameter schemas with required fields',
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
      },
    );

    test('tool names are unique', () {
      final names = AgentToolRegistry.taskAgentTools
          .map((t) => t.name)
          .toList();
      expect(names.toSet().length, equals(names.length));
    });

    group('set_task_title', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'set_task_title',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_task_estimate',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_task_due_date',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_task_priority',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'add_multiple_checklist_items',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_checklist_items',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'update_report',
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals('update_report'));
        expect(tool.description, contains('report'));
      });

      test('requires oneLiner, tldr, and content parameters', () {
        final properties = tool.parameters['properties'] as Map;
        final oneLinerProp = properties['oneLiner'] as Map;
        expect(oneLinerProp['type'], equals('string'));
        final tldrProp = properties['tldr'] as Map;
        expect(tldrProp['type'], equals('string'));
        final contentProp = properties['content'] as Map;
        expect(contentProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('oneLiner'));
        expect(tool.parameters['required'], contains('tldr'));
        expect(tool.parameters['required'], contains('content'));
        expect(properties.containsKey('markdown'), isFalse);
      });
    });

    group('record_observations', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'record_observations',
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals('record_observations'));
        expect(tool.description, contains('observations'));
      });

      test('requires an array observations parameter with object items', () {
        final properties = tool.parameters['properties'] as Map;
        final obsProp = properties['observations'] as Map;
        expect(obsProp['type'], equals('array'));

        final items = obsProp['items'] as Map;
        expect(items['type'], equals('object'));
        expect(items['required'], contains('text'));

        final itemProps = items['properties'] as Map;
        expect((itemProps['text'] as Map)['type'], equals('string'));
        expect((itemProps['priority'] as Map)['type'], equals('string'));
        expect(
          (itemProps['priority'] as Map)['enum'],
          containsAll(['routine', 'notable', 'critical']),
        );
        expect((itemProps['category'] as Map)['type'], equals('string'));
        expect(
          (itemProps['category'] as Map)['enum'],
          containsAll([
            'grievance',
            'excellence',
            'template_improvement',
            'operational',
          ]),
        );

        expect(tool.parameters['required'], contains('observations'));
      });
    });

    group('assign_task_labels', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'assign_task_labels',
        );
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

    group('create_time_entry', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.createTimeEntry,
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals(TaskAgentToolNames.createTimeEntry));
        expect(tool.description, contains('time tracking'));
        expect(tool.description, contains('JUST NOW'));
        expect(tool.description, contains('running timer'));
      });

      test('requires startTime and summary parameters', () {
        final required = tool.parameters['required'] as List;
        expect(required, containsAll(['startTime', 'summary']));
        expect(required, isNot(contains('endTime')));
      });

      test('has correct parameter types', () {
        final properties = tool.parameters['properties'] as Map;
        final startTimeProp = properties['startTime'] as Map;
        expect(startTimeProp['type'], equals('string'));
        final endTimeProp = properties['endTime'] as Map;
        expect(endTimeProp['type'], equals('string'));
        final summaryProp = properties['summary'] as Map;
        expect(summaryProp['type'], equals('string'));
        expect(summaryProp['maxLength'], equals(500));
      });

      test('is registered as a deferred tool', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.createTimeEntry),
        );
      });
    });

    group('get_related_task_details', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.getRelatedTaskDetails,
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals(TaskAgentToolNames.getRelatedTaskDetails));
        expect(tool.description, contains('related task'));
        expect(tool.description, contains('same parent project'));
      });

      test('requires a string taskId parameter', () {
        final properties = tool.parameters['properties'] as Map;
        final taskIdProp = properties['taskId'] as Map;
        expect(taskIdProp['type'], equals('string'));
        expect(tool.parameters['required'], contains('taskId'));
      });
    });

    group('TaskAgentToolNames constants', () {
      test('assignTaskLabel singular alias exists', () {
        expect(
          TaskAgentToolNames.assignTaskLabel,
          equals('assign_task_label'),
        );
      });

      test('getRelatedTaskDetails constant exists', () {
        expect(
          TaskAgentToolNames.getRelatedTaskDetails,
          equals('get_related_task_details'),
        );
      });
    });

    group('explodedBatchTools', () {
      test('includes assign_task_labels with labels key', () {
        expect(
          AgentToolRegistry.explodedBatchTools,
          containsPair('assign_task_labels', 'labels'),
        );
      });
    });

    group('set_task_language', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'set_task_language',
        );
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
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == 'set_task_status',
        );
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

  group('soulEvolutionAgentTools', () {
    test('excludes propose_directives', () {
      final tools = AgentToolRegistry.soulEvolutionAgentTools;

      final names = tools.map((t) => t.name).toList();
      expect(names, isNot(contains('propose_directives')));
    });

    test('includes propose_soul_directives and other evolution tools', () {
      final tools = AgentToolRegistry.soulEvolutionAgentTools;
      final names = tools.map((t) => t.name).toSet();

      expect(names, contains('propose_soul_directives'));
      expect(names, contains('record_evolution_note'));
      expect(names, contains('publish_ritual_recap'));
    });

    test('has fewer tools than evolutionAgentTools', () {
      expect(
        AgentToolRegistry.soulEvolutionAgentTools.length,
        lessThan(AgentToolRegistry.evolutionAgentTools.length),
      );
    });
  });
}
