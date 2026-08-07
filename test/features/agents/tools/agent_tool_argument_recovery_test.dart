import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('resolveTaskAgentToolAlias', () {
    test('accepts the prefix a model guesses, in both directions', () {
      // Both were invented by DeepSeek V4 Flash 0731 on 2026-08-07, which then
      // ignored the "unknown tool" error and reported the task as configured.
      expect(
        resolveTaskAgentToolAlias('set_task_estimate'),
        TaskAgentToolNames.updateTaskEstimate,
      );
      expect(
        resolveTaskAgentToolAlias('update_task_status'),
        TaskAgentToolNames.setTaskStatus,
      );
    });

    test('leaves real tool names untouched', () {
      for (final name in [
        TaskAgentToolNames.updateTaskEstimate,
        TaskAgentToolNames.setTaskStatus,
        TaskAgentToolNames.updateReport,
        TaskAgentToolNames.addMultipleChecklistItems,
      ]) {
        expect(resolveTaskAgentToolAlias(name), name);
      }
    });

    test('does not invent a target for an unrelated name', () {
      expect(
        resolveTaskAgentToolAlias('delete_everything'),
        'delete_everything',
      );
    });

    test('every alias points at a name the dispatcher handles', () {
      final known = {
        for (final definition in AgentToolRegistry.taskAgentTools)
          definition.name,
      };
      for (final target in taskAgentToolAliases.values) {
        expect(known, contains(target));
      }
      // An alias that collides with a real tool name would shadow it.
      for (final alias in taskAgentToolAliases.keys) {
        expect(known, isNot(contains(alias)));
      }
    });
  });

  group('decodeStringifiedJsonArguments', () {
    test('recovers a double-encoded items array', () {
      // Verbatim shape from the Qwen3.6 35B A3B run: the contents were
      // correct, including reasons citing the log, but the array arrived as a
      // string and the handler rejected it on `items is! List`.
      final args = decodeStringifiedJsonArguments({
        'items':
            '[{"id": "item-interviews", "isChecked": true, '
            '"reason": "Log from 2026-07-10 states interviews are complete"}]',
      });

      final items = args['items'];
      expect(items, isA<List<dynamic>>());
      final first = (items! as List<dynamic>).first as Map<String, dynamic>;
      expect(first['id'], 'item-interviews');
      expect(first['isChecked'], isTrue);
      expect(first['reason'], contains('2026-07-10'));
    });

    test('recovers a double-encoded object argument', () {
      final args = decodeStringifiedJsonArguments({
        'observations': '{"text": "note", "priority": "routine"}',
      });
      expect(args['observations'], isA<Map<String, dynamic>>());
    });

    test('leaves genuine string arguments alone', () {
      // These must keep their type: the handlers require strings and a
      // date or title is not JSON.
      final args = decodeStringifiedJsonArguments({
        'dueDate': '2026-10-15',
        'priority': 'P1',
        'title': 'Rotate production signing certificate',
        'minutes': '150',
      });
      expect(args['dueDate'], '2026-10-15');
      expect(args['priority'], 'P1');
      expect(args['title'], 'Rotate production signing certificate');
      // parseMinutes already coerces a numeric string, so it stays a string.
      expect(args['minutes'], '150');
    });

    test('leaves malformed JSON for the handler to reject', () {
      final args = decodeStringifiedJsonArguments({'items': '[{"id": broken'});
      expect(args['items'], '[{"id": broken');
    });

    test('returns the original map when nothing needed decoding', () {
      final original = <String, dynamic>{'priority': 'P2'};
      expect(
        identical(decodeStringifiedJsonArguments(original), original),
        isTrue,
      );
    });
  });
}
