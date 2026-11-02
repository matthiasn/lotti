import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_context_builder.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../relationships/helpers/test_people.dart';
import '../test_utils.dart';

void main() {
  late MockAgentRepository agentRepository;
  late MockJournalRepository journalRepository;
  late List<({String message, Object? error})> loggedErrors;
  late EventAgentContextBuilder builder;

  final eventTime = DateTime(2026, 6, 20, 19, 30);

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: eventTime,
    updatedAt: eventTime,
    dateFrom: eventTime,
    dateTo: eventTime.add(const Duration(hours: 4)),
  );

  JournalEntity eventEntity({
    String title = "Maya's 30th",
    EventStatus status = EventStatus.completed,
    double stars = 4.5,
    String? note,
  }) {
    return JournalEntity.event(
      meta: meta('event-001'),
      data: EventData(title: title, stars: stars, status: status),
      entryText: note == null
          ? null
          : EntryText(plainText: note, markdown: note),
    );
  }

  JournalEntity image({String id = 'img-1', String? caption}) {
    return JournalEntity.journalImage(
      meta: meta(id),
      data: ImageData(
        capturedAt: eventTime,
        imageId: id,
        imageFile: '$id.jpg',
        imageDirectory: '/images/',
      ),
      entryText: caption == null
          ? null
          : EntryText(plainText: caption, markdown: caption),
    );
  }

  JournalEntity audio({required String transcript, String id = 'aud-1'}) {
    return JournalEntity.journalAudio(
      meta: meta(id),
      data: AudioData(
        dateFrom: eventTime,
        dateTo: eventTime,
        audioFile: '$id.m4a',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 30),
      ),
      entryText: EntryText(plainText: transcript, markdown: transcript),
    );
  }

  JournalEntity note({required String text, String id = 'note-1'}) {
    return JournalEntity.journalEntry(
      meta: meta(id),
      entryText: EntryText(plainText: text, markdown: text),
    );
  }

  Task taskEntity({
    String id = 'task-1',
    String title = 'Book the venue',
    TaskStatus? status,
  }) {
    return Task(
      meta: meta(id),
      data: TaskData(
        title: title,
        status:
            status ??
            TaskStatus.done(
              id: 's',
              createdAt: eventTime,
              utcOffset: 0,
            ),
        dateFrom: eventTime,
        dateTo: eventTime,
        statusHistory: const [],
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  setUp(() {
    agentRepository = MockAgentRepository();
    journalRepository = MockJournalRepository();
    loggedErrors = [];
    // No photo carries an analysis unless a test says so.
    when(
      () => journalRepository.getBulkLinkedEntities(any()),
    ).thenAnswer((_) async => {});
    // …and no one is linked to the event unless a test says so.
    when(
      () => journalRepository.getTypedLinksForTaskIds(
        any(),
        linkTypes: any(named: 'linkTypes'),
      ),
    ).thenAnswer((_) async => const []);
    builder = EventAgentContextBuilder(
      agentRepository: agentRepository,
      journalRepository: journalRepository,
      logError: (message, {error, stackTrace}) =>
          loggedErrors.add((message: message, error: error)),
    );
  });

  group('buildSystemPrompt', () {
    test('returns the event scaffold only when version is null', () {
      final prompt = builder.buildSystemPrompt(
        version: null,
        soulVersion: null,
      );

      expect(prompt, contains('You are an Event Agent'));
      expect(prompt, contains('## User Sovereignty'));
      expect(prompt, contains('Never comment on them'));
      // How it finds the people the event names and suggests them.
      expect(prompt, contains('## People'));
      expect(prompt, contains('call\n`list_people`'));
      expect(prompt, contains('call `suggest_person`'));
      expect(prompt, isNot(contains('## Report Directive')));
      expect(prompt, isNot(contains('## Your Personality')));
    });

    test(
      'appends the legacy combined heading for a directives-only version',
      () {
        final prompt = builder.buildSystemPrompt(
          version: makeTestTemplateVersion(directives: 'Be warm and brief.'),
          soulVersion: null,
        );

        expect(prompt, contains('## Your Personality & Directives'));
        expect(prompt, contains('Be warm and brief.'));
      },
    );

    test('renders report + general directive sections', () {
      final prompt = builder.buildSystemPrompt(
        version: makeTestTemplateVersion(
          reportDirective: 'Lead with the highlight.',
          generalDirective: 'Stay grounded in the photos.',
        ),
        soulVersion: null,
      );

      expect(prompt, contains('## Report Directive'));
      expect(prompt, contains('Lead with the highlight.'));
      expect(prompt, contains('## Your Personality & Directives'));
      expect(prompt, contains('Stay grounded in the photos.'));
    });
  });

  group('buildToolDefinitions', () {
    test('exposes the narrate, observe, people and follow-up tools', () {
      final tools = builder.buildToolDefinitions();

      expect(tools, hasLength(5));
      final names = tools.map((t) => t.function.name).toSet();
      expect(names, {
        EventAgentToolNames.updateReport,
        EventAgentToolNames.recordObservations,
        EventAgentToolNames.listPeople,
        EventAgentToolNames.suggestPerson,
        EventAgentToolNames.suggestFollowUpTask,
      });
      // The person suggestion is the user's to confirm, as follow-ups are;
      // the list is a read and runs at once.
      expect(eventDeferredTools, {
        EventAgentToolNames.suggestFollowUpTask,
        EventAgentToolNames.suggestPerson,
      });
    });
  });

  group('buildUserMessage', () {
    test('renders event metadata, linked block, recap, observations, '
        'triggers — and never the rating', () {
      final report = makeTestReport(content: '# Earlier recap\nNice night.');
      final observation = makeTestRecalledObservation(
        'send the album to the group',
        at: DateTime(2026, 9, 1, 21),
      );

      final message = builder.buildUserMessage(
        eventEntity: eventEntity(note: 'My note about the night.'),
        lastReport: report,
        observations: [observation],
        linkedEntriesContext: '### Photos (3)\n- toast on the rooftop',
        triggerTokens: {'event-001', 'img-1'},
      );

      expect(message, contains("**Title**: Maya's 30th"));
      expect(message, contains('**Status**: ${EventStatus.completed.name}'));
      expect(message, contains('### Event note'));
      expect(message, contains('My note about the night.'));
      expect(message, contains('### Photos (3)'));
      expect(message, contains('## Previous Recap'));
      expect(message, contains('Nice night.'));
      expect(
        message,
        contains('- [2026-09-01T21:00:00.000] send the album to the group'),
      );
      expect(message, contains('## Trigger Tokens'));
      // Rating/cover are deliberately never surfaced to the model.
      expect(message, isNot(contains('4.5')));
      expect(message.toLowerCase(), isNot(contains('star')));
      expect(message.toLowerCase(), isNot(contains('cover')));
    });

    test('omits empty sections', () {
      final message = builder.buildUserMessage(
        eventEntity: eventEntity(),
        lastReport: null,
        observations: const [],
        linkedEntriesContext: '',
        triggerTokens: const {},
      );

      expect(message, isNot(contains('## Linked Entries')));
      expect(message, isNot(contains('## Previous Recap')));
      expect(message, isNot(contains('## Recent Observations')));
      expect(message, isNot(contains('## Trigger Tokens')));
    });

    test('falls back to a bare entity line for a non-event entity', () {
      // Defensive: the slot should always point at an event, but if it ever
      // resolves to a different journal entity the builder must not blow up.
      final message = builder.buildUserMessage(
        eventEntity: note(text: 'not an event', id: 'note-x'),
        lastReport: null,
        observations: const [],
        linkedEntriesContext: '',
        triggerTokens: const {},
      );

      expect(message, contains('Event entity: note-x'));
      expect(message, isNot(contains('**Title**')));
    });
  });

  group('buildLinkedEntriesContext', () {
    test(
      'summarizes photos (with captions), notes, audio, and tasks',
      () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
        ).thenAnswer(
          (_) async => [
            image(caption: 'toast on the rooftop'),
            image(id: 'img-2'), // no caption → only counted
            note(text: 'best night in months'),
            audio(transcript: 'we sang happy birthday twice'),
            taskEntity(),
          ],
        );

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context, contains('### Photos (2)'));
        expect(context, contains('- toast on the rooftop'));
        expect(context, contains('### Notes'));
        expect(context, contains('- best night in months'));
        expect(context, contains('### Voice memos'));
        expect(context, contains('- we sang happy birthday twice'));
        expect(context, contains('### Linked tasks'));
        expect(context, contains('- Book the venue (done)'));
      },
    );

    group('photo analyses', () {
      AiResponseEntry analysis({
        required String id,
        String? oneLiner,
        String? tldr,
        AiResponseType type = AiResponseType.imageAnalysis,
        DateTime? at,
      }) {
        final response = TestAiResponseFactory.create(
          id: id,
          response: 'The full analysis text, never rendered in the digest.',
          type: type,
          dateFrom: at ?? eventTime,
        );
        return response.copyWith(
          data: response.data.copyWith(oneLiner: oneLiner, tldr: tldr),
        );
      }

      void linkPhotos(List<JournalEntity> photos) => when(
        () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
      ).thenAnswer((_) async => photos);

      test("renders what each photo's analysis saw beside its caption", () async {
        linkPhotos([
          image(caption: 'toast on the rooftop'),
          image(id: 'img-2'),
          image(id: 'img-3'),
        ]);
        when(
          () => journalRepository.getBulkLinkedEntities({
            'img-1',
            'img-2',
            'img-3',
          }),
        ).thenAnswer(
          (_) async => {
            'img-1': [
              analysis(id: 'a-1', oneLiner: 'Four friends raising glasses'),
            ],
            'img-2': [
              analysis(id: 'a-2', oneLiner: 'A cake with thirty candles'),
            ],
          },
        );

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context, contains('### Photos (3)'));
        expect(
          context,
          contains(
            '- toast on the rooftop (photo shows: Four friends raising glasses)',
          ),
        );
        expect(context, contains('- Photo shows: A cake with thirty candles'));
        // The full analysis is the photo's own record; the digest stays short.
        expect(context, isNot(contains('never rendered in the digest')));
        // img-3 has neither caption nor analysis: counted, not listed.
        expect('- '.allMatches(context).length, 2);
        expect(loggedErrors, isEmpty);
      });

      test('uses the newest image analysis, and its TLDR when it has no '
          'one-liner', () async {
        linkPhotos([image()]);
        when(
          () => journalRepository.getBulkLinkedEntities({'img-1'}),
        ).thenAnswer(
          (_) async => {
            'img-1': [
              analysis(
                id: 'old',
                oneLiner: 'An earlier reading',
                at: eventTime,
              ),
              analysis(
                id: 'new',
                tldr: 'Guests dancing under string lights.',
                at: eventTime.add(const Duration(hours: 1)),
              ),
            ],
          },
        );

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(
          context,
          contains('- Photo shows: Guests dancing under string lights.'),
        );
        expect(context, isNot(contains('An earlier reading')));
      });

      test('ignores responses that are not image analyses', () async {
        linkPhotos([image(caption: 'the cake')]);
        when(
          () => journalRepository.getBulkLinkedEntities({'img-1'}),
        ).thenAnswer(
          (_) async => {
            'img-1': [
              analysis(
                id: 'prompt',
                oneLiner: 'A generated prompt',
                type: AiResponseType.promptGeneration,
              ),
            ],
          },
        );

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context, contains('- the cake\n'));
        expect(context, isNot(contains('A generated prompt')));
      });

      test('an analysis lookup failure keeps the captions and logs', () async {
        linkPhotos([
          image(caption: 'toast on the rooftop'),
          note(text: 'kept'),
        ]);
        when(
          () => journalRepository.getBulkLinkedEntities(any()),
        ).thenThrow(Exception('db down'));

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context, contains('### Photos (1)'));
        expect(context, contains('- toast on the rooftop'));
        expect(context, contains('- kept'));
        expect(loggedErrors.single.message, contains('image analyses'));
      });

      test('reads no analyses when no photo is linked', () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
        ).thenAnswer((_) async => [note(text: 'just words')]);

        await builder.buildLinkedEntriesContext('event-001');

        verifyNever(() => journalRepository.getBulkLinkedEntities(any()));
      });
    });

    group('people', () {
      JournalEntity person(String id, String title, {String? nickname}) =>
          makeTestPerson(id: id, title: title, nickname: nickname);

      EntryLink relationshipLink(
        String personId, {
        String toId = 'event-001',
        bool hidden = false,
        DateTime? deletedAt,
      }) => EntryLink.relationship(
        id: 'link-$personId',
        fromId: personId,
        toId: toId,
        createdAt: eventTime,
        updatedAt: eventTime,
        vectorClock: null,
        hidden: hidden,
        deletedAt: deletedAt,
      );

      void linkPeople(List<EntryLink> links) => when(
        () => journalRepository.getTypedLinksForTaskIds(
          {'event-001'},
          linkTypes: {'RelationshipLink'},
        ),
      ).thenAnswer((_) async => links);

      test('lists who was there first, by name, with a differing '
          'nickname', () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
        ).thenAnswer((_) async => [note(text: 'best night in months')]);
        linkPeople([
          relationshipLink('p-rocko'),
          relationshipLink('p-pip'),
          relationshipLink('p-gone', deletedAt: eventTime),
          relationshipLink('p-hidden', hidden: true),
          // A link from the event to someone else is not this event's people.
          relationshipLink('p-other', toId: 'other-event'),
        ]);
        when(
          () => journalRepository.getJournalEntitiesByIds({'p-rocko', 'p-pip'}),
        ).thenAnswer(
          (_) async => [
            person('p-rocko', 'Rocko', nickname: 'Rocko'),
            person('p-pip', 'Pip Penguin', nickname: 'Pip'),
          ],
        );

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(
          context,
          startsWith('### People\n- Pip Penguin (Pip)\n- Rocko\n'),
        );
        expect(context, contains('### Notes'));
        expect(loggedErrors, isEmpty);
      });

      test('people alone are worth a context block', () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
        ).thenAnswer((_) async => []);
        linkPeople([relationshipLink('p-pip')]);
        when(
          () => journalRepository.getJournalEntitiesByIds({'p-pip'}),
        ).thenAnswer((_) async => [person('p-pip', 'Pip Penguin')]);

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context.trim(), '### People\n- Pip Penguin');
      });

      test('a failed people lookup keeps the rest and logs', () async {
        when(
          () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
        ).thenAnswer((_) async => [note(text: 'kept')]);
        when(
          () => journalRepository.getTypedLinksForTaskIds(
            any(),
            linkTypes: any(named: 'linkTypes'),
          ),
        ).thenThrow(Exception('db down'));

        final context = await builder.buildLinkedEntriesContext('event-001');

        expect(context, isNot(contains('### People')));
        expect(context, contains('- kept'));
        expect(loggedErrors.single.message, contains('people'));
      });
    });

    test('labels a linked task by its status (rejected)', () async {
      when(
        () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
      ).thenAnswer(
        (_) async => [
          taskEntity(
            title: 'Cancel the caterer',
            status: TaskStatus.rejected(
              id: 's',
              createdAt: eventTime,
              utcOffset: 0,
            ),
          ),
        ],
      );

      final context = await builder.buildLinkedEntriesContext('event-001');

      expect(context, contains('- Cancel the caterer (rejected)'));
    });

    test('excludes soft-deleted linked entries', () async {
      final deletedNote = JournalEntity.journalEntry(
        meta: meta('note-del').copyWith(deletedAt: eventTime),
        entryText: const EntryText(plainText: 'gone', markdown: 'gone'),
      );
      when(
        () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
      ).thenAnswer((_) async => [deletedNote, note(text: 'kept')]);

      final context = await builder.buildLinkedEntriesContext('event-001');

      expect(context, contains('- kept'));
      expect(context, isNot(contains('gone')));
    });

    test('returns empty string and logs on repository failure', () async {
      when(
        () => journalRepository.getLinkedEntities(linkedTo: 'event-001'),
      ).thenThrow(Exception('db down'));

      final context = await builder.buildLinkedEntriesContext('event-001');

      expect(context, isEmpty);
      expect(loggedErrors, hasLength(1));
    });
  });
}
