import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';

void main() {
  group('eventAgentTools', () {
    test('exposes exactly narrate + observe + the people read + the '
        'language + the three proposals, and the deferred set is exactly '
        'the proposals', () {
      final names = eventAgentTools.map((t) => t.name).toSet();
      expect(names, {
        EventAgentToolNames.updateReport,
        EventAgentToolNames.recordObservations,
        EventAgentToolNames.listPeople,
        EventAgentToolNames.setEventLanguage,
        EventAgentToolNames.suggestPerson,
        EventAgentToolNames.suggestFollowUpTask,
        EventAgentToolNames.suggestNote,
      });
      // The people list is a read and the language fills an empty field,
      // both run at once; suggesting someone or a note is the user's to
      // confirm, as a follow-up is.
      expect(eventDeferredTools, {
        EventAgentToolNames.suggestFollowUpTask,
        EventAgentToolNames.suggestPerson,
        EventAgentToolNames.suggestNote,
      });
    });

    for (final (name, argument) in [
      (
        EventAgentToolNames.setEventLanguage,
        EventAgentLanguageToolArgs.languageCode,
      ),
      (EventAgentToolNames.suggestNote, EventAgentNoteToolArgs.text),
    ]) {
      test('$name takes exactly its one required argument', () {
        final tool = eventAgentTools.firstWhere((t) => t.name == name);
        final properties =
            tool.parameters['properties'] as Map<String, Object?>;

        expect(properties.keys, [argument]);
        expect(tool.parameters['required'], [argument]);
        expect(tool.parameters['additionalProperties'], isFalse);
      });
    }

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
