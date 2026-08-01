import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';

void main() {
  group('task link tool definitions', () {
    group('link_task tool', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.linkTask,
        );
      });

      test('has correct name', () {
        expect(tool.name, equals(TaskAgentToolNames.linkTask));
        expect(tool.name, equals('link_task'));
      });

      test('requires relation and targetTaskId', () {
        final required = tool.parameters['required'] as List;
        expect(required, containsAll(['relation', 'targetTaskId']));
        expect(tool.parameters['additionalProperties'], isFalse);
      });

      test('relation is an enum of the directed wire vocabulary', () {
        final properties = tool.parameters['properties'] as Map;
        final relationProp = properties['relation'] as Map;
        expect(relationProp['type'], equals('string'));
        expect(relationProp['enum'], equals(taskRelationWireNames));
      });

      test('targetTaskId is a string property', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['targetTaskId'] as Map)['type'], equals('string'));
      });

      test('is in deferredTools', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.linkTask),
        );
      });

      test('is not a batch tool', () {
        expect(
          AgentToolRegistry.explodedBatchTools,
          isNot(contains(TaskAgentToolNames.linkTask)),
        );
      });

      test('is enabled', () {
        expect(tool.enabled, isTrue);
      });
    });

    group('taskRelationWireNames', () {
      test('restates the directed relation options exactly', () {
        // The schema list must be const, so it cannot derive from the model
        // at runtime — this pin is what keeps the two lists one vocabulary.
        expect(
          taskRelationWireNames,
          equals(
            relationshipDirectedOptions
                .map((option) => option.wireName)
                .toList(),
          ),
        );
      });

      test('every value parses back to a relation', () {
        for (final name in taskRelationWireNames) {
          expect(
            DirectedRelation.fromWireName(name),
            isNotNull,
            reason: '$name must parse',
          );
        }
      });
    });
  });
}
