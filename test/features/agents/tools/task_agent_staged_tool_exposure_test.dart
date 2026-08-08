import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/task_agent_staged_tool_exposure.dart';
import 'package:openai_dart/openai_dart.dart';

ChatCompletionTool _tool(String name) => ChatCompletionTool(
  type: ChatCompletionToolType.function,
  function: FunctionObject(name: name, parameters: const {}),
);

void main() {
  group('TaskAgentStagedToolExposure', () {
    final tools = [
      _tool(TaskAgentToolNames.updateReport),
      _tool(TaskAgentToolNames.setTaskStatus),
      _tool(TaskAgentToolNames.updateChecklistItems),
      _tool(TaskAgentToolNames.recordObservations),
    ];

    test('withholds update_report on the opening turn', () {
      final exposure = TaskAgentStagedToolExposure(allTools: tools);

      final names = exposure
          .toolsForTurn(0)
          .map((tool) => tool.function.name)
          .toList();

      expect(names, isNot(contains(TaskAgentToolNames.updateReport)));
      // The work tools must survive, or the opening turn can do nothing at all.
      expect(names, contains(TaskAgentToolNames.setTaskStatus));
      expect(names, contains(TaskAgentToolNames.updateChecklistItems));
    });

    test('keeps record_observations on the opening turn', () {
      final exposure = TaskAgentStagedToolExposure(allTools: tools);

      // Private notes for later wakes, not user-visible output — a model that
      // wants to note something before acting should be able to.
      expect(
        exposure.toolsForTurn(0).map((tool) => tool.function.name),
        contains(TaskAgentToolNames.recordObservations),
      );
    });

    test('restores the full surface from the second turn on', () {
      final exposure = TaskAgentStagedToolExposure(allTools: tools);

      for (final turn in [1, 2, 7]) {
        expect(
          exposure.toolsForTurn(turn).map((tool) => tool.function.name),
          containsAll(tools.map((tool) => tool.function.name)),
          reason: 'turn $turn must be able to publish the report',
        );
      }
    });

    test('never permanently hides a tool', () {
      final exposure = TaskAgentStagedToolExposure(allTools: tools);

      final everReachable = {
        ...exposure.toolsForTurn(0).map((tool) => tool.function.name),
        ...exposure.toolsForTurn(1).map((tool) => tool.function.name),
      };

      expect(
        everReachable,
        containsAll(tools.map((tool) => tool.function.name)),
        reason: 'a tool the wake needs must be reachable on some turn',
      );
    });

    test('an empty exclusion set leaves the opening turn unchanged', () {
      final exposure = TaskAgentStagedToolExposure(
        allTools: tools,
        openingTurnExclusions: const {},
      );

      expect(
        exposure.toolsForTurn(0).map((tool) => tool.function.name),
        containsAll(tools.map((tool) => tool.function.name)),
      );
    });
  });
}
