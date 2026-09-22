import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/retired_tool_calls.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

void main() {
  group('upgradeRetiredTaskAgentToolCall', () {
    test('rewrites update_running_timer into an update_time_entry', () {
      final call = upgradeRetiredTaskAgentToolCall(
        TaskAgentToolNames.updateRunningTimer,
        const {'timerId': 'timer-1', 'summary': 'Drafted the plan'},
      );

      expect(call.toolName, TaskAgentToolNames.updateTimeEntry);
      expect(call.args, {'entryId': 'timer-1', 'summary': 'Drafted the plan'});
    });

    test('keeps an explicit entryId over the timer id', () {
      final call = upgradeRetiredTaskAgentToolCall(
        TaskAgentToolNames.updateRunningTimer,
        const {'timerId': 'timer-1', 'entryId': 'entry-1', 'summary': 'x'},
      );

      expect(call.args, {'entryId': 'entry-1', 'summary': 'x'});
    });

    test('adds no entryId when the retired call named no timer', () {
      // The handler then refuses it for the missing id, as it would have.
      final call = upgradeRetiredTaskAgentToolCall(
        TaskAgentToolNames.updateRunningTimer,
        const {'summary': 'x'},
      );

      expect(call.toolName, TaskAgentToolNames.updateTimeEntry);
      expect(call.args, {'summary': 'x'});
    });

    test('returns every other call unchanged, arguments included', () {
      const args = {'entryId': 'entry-1', 'summary': 'x'};
      final call = upgradeRetiredTaskAgentToolCall(
        TaskAgentToolNames.updateTimeEntry,
        args,
      );

      expect(call.toolName, TaskAgentToolNames.updateTimeEntry);
      expect(call.args, same(args));
    });

    test('its target is a live, deferred tool', () {
      // The model layer spells the names itself rather than importing the
      // registry; this is what keeps the two spellings from drifting apart.
      final target = upgradeRetiredTaskAgentToolCall(
        TaskAgentToolNames.updateRunningTimer,
        const {},
      ).toolName;

      expect(
        AgentToolRegistry.taskAgentTools.map((t) => t.name),
        contains(target),
      );
      expect(AgentToolRegistry.deferredTools, contains(target));
    });
  });
}
