import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('task checklist & follow-up tool definitions', () {
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

    group('create_follow_up_task tool', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.createFollowUpTask,
        );
      });

      test('has correct name', () {
        expect(tool.name, equals(TaskAgentToolNames.createFollowUpTask));
        expect(tool.name, equals('create_follow_up_task'));
      });

      test('requires only title', () {
        final required = tool.parameters['required'] as List;
        expect(required, contains('title'));
        expect(required, isNot(contains('dueDate')));
        expect(required, isNot(contains('priority')));
        expect(required, isNot(contains('description')));
      });

      test('title property is a string', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['title'] as Map)['type'], equals('string'));
      });

      test('dueDate is an optional string property', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['dueDate'] as Map)['type'], equals('string'));
      });

      test('priority is an optional string property', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['priority'] as Map)['type'], equals('string'));
      });

      test('description is an optional string property', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['description'] as Map)['type'], equals('string'));
      });

      test('is in deferredTools', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.createFollowUpTask),
        );
      });

      test('is enabled', () {
        expect(tool.enabled, isTrue);
      });
    });

    group('migrate_checklist_items tool', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.migrateChecklistItems,
        );
      });

      test('has correct name', () {
        expect(tool.name, equals(TaskAgentToolNames.migrateChecklistItems));
        expect(tool.name, equals('migrate_checklist_items'));
      });

      test('requires items and targetTaskId', () {
        final required = tool.parameters['required'] as List;
        expect(required, containsAll(['items', 'targetTaskId']));
      });

      test('items array items require id and title', () {
        final properties = tool.parameters['properties'] as Map;
        final itemsProp = properties['items'] as Map;
        expect(itemsProp['type'], equals('array'));
        final itemSchema = itemsProp['items'] as Map;
        final itemRequired = itemSchema['required'] as List;
        expect(itemRequired, containsAll(['id', 'title']));
      });

      test('item id and title are string properties', () {
        final properties = tool.parameters['properties'] as Map;
        final itemsProp = properties['items'] as Map;
        final itemSchema = itemsProp['items'] as Map;
        final itemProps = itemSchema['properties'] as Map;
        expect((itemProps['id'] as Map)['type'], equals('string'));
        expect((itemProps['title'] as Map)['type'], equals('string'));
      });

      test('targetTaskId is a string property', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['targetTaskId'] as Map)['type'], equals('string'));
      });

      test('is in deferredTools', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.migrateChecklistItems),
        );
      });

      test('is in explodedBatchTools with items key', () {
        expect(
          AgentToolRegistry.explodedBatchTools,
          containsPair(TaskAgentToolNames.migrateChecklistItems, 'items'),
        );
      });

      test('is enabled', () {
        expect(tool.enabled, isTrue);
      });
    });
  });
}
