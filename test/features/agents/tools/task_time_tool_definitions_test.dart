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

      test('steers work on the active timer to update_time_entry', () {
        expect(
          tool.description,
          contains('call update_time_entry with its entryId instead'),
        );
        expect(tool.description, isNot(contains('update_running_timer')));
      });

      test('separates creating from editing and asks for no id', () {
        expect(tool.description, contains('NEW time tracking entries'));
        expect(
          tool.description,
          contains('pass neither an entryId nor a taskId'),
        );
        expect(tool.description, contains('that is update_time_entry'));
        final entry =
            ((tool.parameters['properties'] as Map)['entries'] as Map)['items']
                as Map;
        expect(
          (entry['properties'] as Map).keys,
          unorderedEquals(['startTime', 'endTime', 'summary']),
        );
        expect(entry['additionalProperties'], isFalse);
      });

      test('takes every session of a dictation in one call', () {
        expect(tool.description, contains('ONE call through "entries"'));
        expect(tool.description, contains('its own suggestion'));
        expect(tool.parameters['required'], equals(['entries']));
        final entries =
            (tool.parameters['properties'] as Map)['entries'] as Map;
        expect(entries['type'], 'array');
        expect(entries['minItems'], 1);
      });

      test('requires startTime and summary on each entry', () {
        final entry =
            ((tool.parameters['properties'] as Map)['entries'] as Map)['items']
                as Map;
        final required = entry['required'] as List;
        expect(required, containsAll(['startTime', 'summary']));
        expect(required, isNot(contains('endTime')));
      });

      test('has correct parameter types', () {
        final properties =
            (((tool.parameters['properties'] as Map)['entries'] as Map)['items']
                    as Map)['properties']
                as Map;
        final startTimeProp = properties['startTime'] as Map;
        expect(startTimeProp['type'], equals('string'));
        final endTimeProp = properties['endTime'] as Map;
        expect(endTimeProp['type'], equals('string'));
        final summaryProp = properties['summary'] as Map;
        expect(summaryProp['type'], equals('string'));
        expect(summaryProp['maxLength'], equals(500));
      });

      test('is registered as a deferred, exploded, repeatable tool', () {
        expect(
          AgentToolRegistry.deferredTools,
          contains(TaskAgentToolNames.createTimeEntry),
        );
        expect(
          AgentToolRegistry.explodedBatchTools,
          containsPair(TaskAgentToolNames.createTimeEntry, 'entries'),
        );
        expect(
          AgentToolRegistry.repeatableDeferredTools,
          contains(TaskAgentToolNames.createTimeEntry),
        );
      });
    });

    group('wrapFlatCreateTimeEntryCall', () {
      const flat = {'startTime': '2026-03-17T14:00:00', 'summary': 'Work'};

      test('wraps a flat create_time_entry call into a one-entry batch', () {
        expect(
          wrapFlatCreateTimeEntryCall(TaskAgentToolNames.createTimeEntry, flat),
          {
            'entries': [flat],
          },
        );
      });

      test('leaves a batch call untouched', () {
        final batch = {
          'entries': [flat],
        };
        expect(
          wrapFlatCreateTimeEntryCall(
            TaskAgentToolNames.createTimeEntry,
            batch,
          ),
          same(batch),
        );
      });

      test('leaves other tools, and calls without a start, untouched', () {
        expect(
          wrapFlatCreateTimeEntryCall(TaskAgentToolNames.updateTimeEntry, flat),
          same(flat),
        );
        const noStart = {'summary': 'Work'};
        expect(
          wrapFlatCreateTimeEntryCall(
            TaskAgentToolNames.createTimeEntry,
            noStart,
          ),
          same(noStart),
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
      });

      test('covers the running timer, text only', () {
        expect(tool.description, contains('"Active Running Timer"'));
        expect(tool.description, contains('pass ONLY entryId and summary'));
        expect(tool.description, contains('never to record a new session'));
        expect(tool.description, isNot(contains('update_running_timer')));
        final entryId =
            (tool.parameters['properties'] as Map)['entryId'] as Map;
        expect(entryId['description'], contains('"Active Running Timer"'));
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
