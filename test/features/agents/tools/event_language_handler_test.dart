import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/event_language_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockJournalRepository journalRepository;
  late MockDomainLogger domainLogger;
  late EventLanguageHandler handler;

  /// The event as stored; [changeEventData] writes through to it.
  late JournalEvent stored;
  late List<JournalEntity> linked;

  final at = DateTime(2026, 7, 16, 18, 30);
  Metadata meta(String id) =>
      Metadata(id: id, createdAt: at, updatedAt: at, dateFrom: at, dateTo: at);

  JournalEvent event({String? languageCode, ChangeSource? source}) =>
      JournalEntity.event(
            meta: meta('event-1'),
            data: EventData(
              title: 'Ice garden picnic',
              stars: 0,
              status: EventStatus.completed,
              languageCode: languageCode,
              languageSource: source ?? ChangeSource.user,
            ),
          )
          as JournalEvent;

  JournalEntity memo(String transcript, {DateTime? deletedAt}) =>
      JournalEntity.journalAudio(
        meta: meta('memo-1').copyWith(deletedAt: deletedAt),
        data: AudioData(
          dateFrom: at,
          dateTo: at,
          audioFile: 'memo.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 20),
        ),
        entryText: EntryText(plainText: transcript, markdown: transcript),
      );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    journalRepository = MockJournalRepository();
    domainLogger = MockDomainLogger();
    stored = event();
    linked = [memo('Wir haben am See gepicknickt.')];
    when(
      () => journalRepository.getJournalEntityById('event-1'),
    ).thenAnswer((_) async => stored);
    when(
      () => journalRepository.getLinkedEntities(linkedTo: 'event-1'),
    ).thenAnswer((_) async => linked);
    when(() => journalRepository.changeEventData('event-1', any())).thenAnswer((
      invocation,
    ) async {
      final change =
          invocation.positionalArguments[1]
              as EventData? Function(EventData stored);
      final next = change(stored.data);
      if (next != null) {
        stored = stored.copyWith(data: next);
      }
      return true;
    });
    handler = EventLanguageHandler(
      eventId: 'event-1',
      journalRepository: journalRepository,
      domainLogger: domainLogger,
    );
  });

  test('sets an empty language from a voice memo, as the agent', () async {
    final result = await handler.handle(' DE ');

    expect(result.success, isTrue);
    expect(result.didWrite, isTrue);
    expect(
      result.message,
      'Event language set to "de" (German). Write the recap and every '
      'suggestion in German.',
    );
    expect(stored.data.languageCode, 'de');
    expect(stored.data.languageSource, ChangeSource.agent);
  });

  test(
    'never changes a language the user set, and says which stands',
    () async {
      stored = event(languageCode: 'fr');

      final result = await handler.handle('de');

      expect(result.success, isTrue);
      expect(result.didWrite, isFalse);
      expect(
        result.message,
        'The event\'s language is already "fr" (French), set by the user; it '
        'is not changed. Write the recap and every suggestion in French.',
      );
      expect(stored.data.languageCode, 'fr');
      verifyNever(() => journalRepository.changeEventData(any(), any()));
    },
  );

  test('never changes its own earlier choice either', () async {
    stored = event(languageCode: 'de', source: ChangeSource.agent);

    final result = await handler.handle('en');

    expect(result.didWrite, isFalse);
    expect(result.message, contains('set by you, from a voice memo'));
    expect(stored.data.languageCode, 'de');
  });

  test('waits for a transcribed voice memo before setting anything', () async {
    linked = [
      memo('   '),
      memo('Gelöschte Aufnahme', deletedAt: at),
    ];

    final result = await handler.handle('de');

    expect(result.success, isFalse);
    expect(result.message, startsWith('Not set: the event has no transcribed'));
    expect(stored.data.languageCode, isNull);
    verifyNever(() => journalRepository.changeEventData(any(), any()));
  });

  test('keeps a language set between its read and its write', () async {
    // The user picks French while the agent's write is on its way: the
    // conditional write keeps French, and the model is told to write in it.
    var reads = 0;
    when(() => journalRepository.getJournalEntityById('event-1')).thenAnswer((
      _,
    ) async {
      reads++;
      return reads == 1 ? stored : event(languageCode: 'fr');
    });
    when(() => journalRepository.changeEventData('event-1', any())).thenAnswer((
      invocation,
    ) async {
      final change =
          invocation.positionalArguments[1]
              as EventData? Function(EventData stored);
      expect(change(event(languageCode: 'fr').data), isNull);
      return true;
    });

    final result = await handler.handle('de');

    expect(result.didWrite, isFalse);
    expect(result.message, contains('"fr" (French), set by the user'));
  });

  for (final (code, error) in [
    ('  ', 'Error: "languageCode" must not be empty.'),
    ('xx', 'Error: unsupported language code "xx".'),
  ]) {
    test('refuses "$code"', () async {
      final result = await handler.handle(code);

      expect(result.success, isFalse);
      expect(result.message, startsWith(error));
      verifyNever(() => journalRepository.changeEventData(any(), any()));
    });
  }

  test('refuses for an event that is gone', () async {
    when(
      () => journalRepository.getJournalEntityById('event-1'),
    ).thenAnswer((_) async => null);

    final result = await handler.handle('de');

    expect(result.success, isFalse);
    expect(result.message, 'Error: the event no longer exists.');
  });

  test('a write the store refused is an error, and is logged', () async {
    when(
      () => journalRepository.changeEventData('event-1', any()),
    ).thenAnswer((_) async => false);

    final result = await handler.handle('de');

    expect(result.success, isFalse);
    expect(result.message, "Error: the event's language could not be stored.");
    verify(
      () => domainLogger.log(
        any(),
        'event language write refused',
        subDomain: 'EventLanguageHandler',
        level: any(named: 'level'),
      ),
    ).called(1);
  });
}
