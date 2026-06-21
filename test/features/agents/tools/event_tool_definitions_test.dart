import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';

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

    // Pins the record_observations wire schema to the model enums, so the
    // priority/category enum strings can never drift from
    // ObservationPriority / ObservationCategory.
    test('record_observations enums stay in sync with the model enums', () {
      final tool = eventAgentTools.firstWhere(
        (t) => t.name == EventAgentToolNames.recordObservations,
      );
      final properties = tool.parameters['properties'] as Map<String, dynamic>;
      final observations = properties['observations'] as Map<String, dynamic>;
      final items = observations['items'] as Map<String, dynamic>;
      final oneOf = items['oneOf'] as List<dynamic>;
      final objectSchema = oneOf.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['type'] == 'object',
      );
      final props = objectSchema['properties'] as Map<String, dynamic>;
      final priorityEnum =
          ((props['priority'] as Map<String, dynamic>)['enum'] as List<dynamic>)
              .cast<String>()
              .toSet();
      final categoryEnum =
          ((props['category'] as Map<String, dynamic>)['enum'] as List<dynamic>)
              .cast<String>()
              .toSet();

      expect(
        priorityEnum,
        ObservationPriority.values.map((e) => e.name).toSet(),
      );
      expect(
        categoryEnum,
        ObservationCategory.values.map((e) => e.name).toSet(),
      );
    });
  });
}
