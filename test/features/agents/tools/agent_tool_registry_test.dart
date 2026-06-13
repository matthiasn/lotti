import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

// Per-tool schema assertions live alongside the source part files they cover:
//   * task_field_tool_definitions_test.dart
//   * task_checklist_tool_definitions_test.dart
//   * task_time_tool_definitions_test.dart
//   * task_planning_tool_definitions_test.dart
// This file covers registry-level invariants only.
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
    test('contains exactly 20 tool definitions', () {
      expect(AgentToolRegistry.taskAgentTools, hasLength(20));
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
  });

  group('AgentToolDefinition.enabled field', () {
    test('get_related_task_details is the only tool with enabled: false', () {
      final disabled = AgentToolRegistry.taskAgentTools
          .where((t) => !t.enabled)
          .toList();
      expect(disabled, hasLength(1));
      expect(
        disabled.first.name,
        equals(TaskAgentToolNames.getRelatedTaskDetails),
      );
    });

    test('all tools except get_related_task_details have enabled: true', () {
      for (final tool in AgentToolRegistry.taskAgentTools) {
        if (tool.name == TaskAgentToolNames.getRelatedTaskDetails) continue;
        expect(
          tool.enabled,
          isTrue,
          reason: '${tool.name} should be enabled',
        );
      }
    });
  });

  group('AgentToolRegistry.deferredTools', () {
    test('contains exactly 14 deferred tool names', () {
      expect(AgentToolRegistry.deferredTools, hasLength(14));
    });

    test('includes all expected deferred tool names', () {
      expect(
        AgentToolRegistry.deferredTools,
        containsAll(<String>[
          TaskAgentToolNames.assignTaskLabels,
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateTaskEstimate,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.updateTaskPriority,
          TaskAgentToolNames.setTaskStatus,
          TaskAgentToolNames.addMultipleChecklistItems,
          TaskAgentToolNames.updateChecklistItems,
          TaskAgentToolNames.setTaskLanguage,
          TaskAgentToolNames.createFollowUpTask,
          TaskAgentToolNames.migrateChecklistItems,
          TaskAgentToolNames.createTimeEntry,
          TaskAgentToolNames.updateTimeEntry,
          TaskAgentToolNames.updateRunningTimer,
        ]),
      );
    });

    test('does not include immediate tools', () {
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.updateReport)),
      );
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.recordObservations)),
      );
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.getRelatedTaskDetails)),
      );
      expect(
        AgentToolRegistry.deferredTools,
        isNot(contains(TaskAgentToolNames.requestAttention)),
      );
    });
  });

  group('AgentToolRegistry.explodedBatchTools', () {
    test('contains exactly 4 entries', () {
      expect(AgentToolRegistry.explodedBatchTools, hasLength(4));
    });

    test('addMultipleChecklistItems maps to items key', () {
      expect(
        AgentToolRegistry.explodedBatchTools,
        containsPair(TaskAgentToolNames.addMultipleChecklistItems, 'items'),
      );
    });

    test('updateChecklistItems maps to items key', () {
      expect(
        AgentToolRegistry.explodedBatchTools,
        containsPair(TaskAgentToolNames.updateChecklistItems, 'items'),
      );
    });

    test('assignTaskLabels maps to labels key', () {
      expect(
        AgentToolRegistry.explodedBatchTools,
        containsPair(TaskAgentToolNames.assignTaskLabels, 'labels'),
      );
    });

    test('migrateChecklistItems maps to items key', () {
      expect(
        AgentToolRegistry.explodedBatchTools,
        containsPair(TaskAgentToolNames.migrateChecklistItems, 'items'),
      );
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
