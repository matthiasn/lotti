import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';

void main() {
  group('eventAgentTools', () {
    test('exposes exactly narrate + observe + follow-up, and the deferred set '
        'is exactly the follow-up tool', () {
      final names = eventAgentTools.map((t) => t.name).toSet();
      expect(names, {
        EventAgentToolNames.updateReport,
        EventAgentToolNames.recordObservations,
        EventAgentToolNames.suggestFollowUpTask,
      });
      expect(eventDeferredTools, {EventAgentToolNames.suggestFollowUpTask});
    });

    // The strongest layer of the human-only invariant: there is no tool whose
    // name implies it could set the event's rating or cover. (Descriptions may
    // mention them — the update_report directive forbids touching them.) If a
    // future change adds such a tool, this fails CI rather than silently
    // breaking the invariant.
    test('no event tool name implies a rating/cover mutation', () {
      for (final tool in eventAgentTools) {
        expect(
          tool.name.toLowerCase(),
          isNot(anyOf(contains('rating'), contains('cover'), contains('star'))),
          reason: 'no event tool may set rating/cover: ${tool.name}',
        );
      }
    });

    // The event agent records observations through the shared contract,
    // whose priority/category enums are taken from the model enums.
    test('record_observations uses the shared observations schema', () {
      final tool = eventAgentTools.firstWhere(
        (t) => t.name == EventAgentToolNames.recordObservations,
      );

      expect(
        tool.parameters,
        recordObservationsParameters(textDescription: 'Observation content.'),
      );
    });
  });
}
