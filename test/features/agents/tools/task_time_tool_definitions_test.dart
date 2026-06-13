import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('task time tracking tool definitions', () {
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

    group('update_time_entry', () {
      late AgentToolDefinition tool;

      setUp(() {
        tool = AgentToolRegistry.taskAgentTools.firstWhere(
          (t) => t.name == TaskAgentToolNames.updateTimeEntry,
        );
      });

      test('has correct name and description', () {
        expect(tool.name, equals(TaskAgentToolNames.updateTimeEntry));
        expect(tool.description, contains('Editable Time Entries'));
        expect(tool.description, contains('update_running_timer'));
      });

      test('requires only entryId in the JSON schema', () {
        final required = tool.parameters['required'] as List;
        expect(required, equals(['entryId']));
      });

      test('has optional update fields with correct parameter types', () {
        final properties = tool.parameters['properties'] as Map;
        expect((properties['entryId'] as Map)['type'], equals('string'));
        expect((properties['startTime'] as Map)['type'], equals('string'));
        expect((properties['endTime'] as Map)['type'], equals('string'));
        final summaryProp = properties['summary'] as Map;
        expect(summaryProp['type'], equals('string'));
        expect(summaryProp['maxLength'], equals(500));
      });

      test('is registered as a deferred tool', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.updateTimeEntry),
        );
      });
    });
  });
}
