import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_context_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
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

  Task taskEntity({String id = 'task-1', String title = 'Book the venue'}) {
    return Task(
      meta: meta(id),
      data: TaskData(
        title: title,
        status: TaskStatus.done(
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
    test('exposes the narrate, observe, and follow-up tools', () {
      final tools = builder.buildToolDefinitions();

      expect(tools, hasLength(3));
      final names = tools.map((t) => t.function.name).toSet();
      expect(names, {
        EventAgentToolNames.updateReport,
        EventAgentToolNames.recordObservations,
        EventAgentToolNames.suggestFollowUpTask,
      });
    });
  });

  group('buildUserMessage', () {
    test('renders event metadata, linked block, recap, observations, '
        'triggers — and never the rating', () {
      final report = makeTestReport(content: '# Earlier recap\nNice night.');
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        contentEntryId: 'payload-1',
      );
      final payloads = {
        'payload-1': makeTestMessagePayload(
          id: 'payload-1',
          content: const {'text': 'send the album to the group'},
        ),
      };

      final message = builder.buildUserMessage(
        eventEntity: eventEntity(note: 'My note about the night.'),
        lastReport: report,
        observations: [observation],
        observationPayloads: payloads,
        linkedEntriesContext: '### Photos (3)\n- toast on the rooftop',
        triggerTokens: {'event-001', 'img-1'},
      );

      expect(message, contains("**Title**: Maya's 30th"));
      expect(message, contains('**Status**: ${EventStatus.completed.label}'));
      expect(message, contains('### Event note'));
      expect(message, contains('My note about the night.'));
      expect(message, contains('### Photos (3)'));
      expect(message, contains('## Previous Recap'));
      expect(message, contains('Nice night.'));
      expect(message, contains('send the album to the group'));
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
        observationPayloads: const {},
        linkedEntriesContext: '',
        triggerTokens: const {},
      );

      expect(message, isNot(contains('## Linked Entries')));
      expect(message, isNot(contains('## Previous Recap')));
      expect(message, isNot(contains('## Recent Observations')));
      expect(message, isNot(contains('## Trigger Tokens')));
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

  group('resolveObservationPayloads', () {
    test('batch-resolves payloads keyed by id', () async {
      final observation = makeTestMessage(
        kind: AgentMessageKind.observation,
        contentEntryId: 'payload-1',
      );
      final payload = makeTestMessagePayload(id: 'payload-1');
      when(
        () => agentRepository.getEntitiesByIds(any()),
      ).thenAnswer((_) async => {'payload-1': payload});

      final result = await builder.resolveObservationPayloads([observation]);

      expect(result.keys, ['payload-1']);
      expect(result['payload-1'], payload);
    });

    test('returns empty when there are no payload ids', () async {
      final result = await builder.resolveObservationPayloads([
        makeTestMessage(kind: AgentMessageKind.observation),
      ]);

      expect(result, isEmpty);
      verifyNever(() => agentRepository.getEntitiesByIds(any()));
    });
  });
}
