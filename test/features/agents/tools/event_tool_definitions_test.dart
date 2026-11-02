import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';

void main() {
  group('eventAgentTools', () {
    test('exposes exactly narrate + observe + the people read + the two '
        'proposals, and the deferred set is exactly the proposals', () {
      final names = eventAgentTools.map((t) => t.name).toSet();
      expect(names, {
        EventAgentToolNames.updateReport,
        EventAgentToolNames.recordObservations,
        EventAgentToolNames.listPeople,
        EventAgentToolNames.suggestPerson,
        EventAgentToolNames.suggestFollowUpTask,
      });
      // The people list is a read, run at once; suggesting someone is the
      // user's to confirm, as a follow-up is.
      expect(eventDeferredTools, {
        EventAgentToolNames.suggestFollowUpTask,
        EventAgentToolNames.suggestPerson,
      });
    });

    test('suggest_person takes a person id from list_people, and an '
        'optional mention', () {
      final tool = eventAgentTools.firstWhere(
        (t) => t.name == EventAgentToolNames.suggestPerson,
      );
      final properties = tool.parameters['properties'] as Map<String, Object?>;

      expect(properties.keys, {
        EventAgentPersonToolArgs.personId,
        EventAgentPersonToolArgs.mention,
      });
      expect(tool.parameters['required'], [EventAgentPersonToolArgs.personId]);
      // The name the row shows is the strategy's to add, never the model's.
      expect(properties, isNot(contains(EventAgentPersonToolArgs.personName)));
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
