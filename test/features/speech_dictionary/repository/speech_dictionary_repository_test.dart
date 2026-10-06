import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerJournalDbTestFallbacks();
    registerAllFallbackValues();
  });

  final now = DateTime.utc(2026, 10, 6, 12);
  final earlier = DateTime.utc(2026, 9);

  late Directory directory;
  late JournalDb db;
  late MockPersistenceLogic persistence;
  late MockUpdateNotifications notifications;
  late StreamController<Set<String>> updates;
  late SpeechDictionaryRepository repository;

  setUp(() {
    directory = setupTestDirectory();
    notifications = MockUpdateNotifications();
    updates = StreamController<Set<String>>.broadcast();
    registerJournalDbTestServices(
      updateNotifications: notifications,
      loggingService: MockDomainLogger(),
      documentsDirectory: directory,
    );
    // After the shared setup, which stubs an empty update stream.
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    db = JournalDb(inMemoryDatabase: true);
    persistence = MockPersistenceLogic();
    // The edit path's re-stamping is PersistenceDefinitionOps' own concern;
    // here every edit is newer than what is stored, so the gate applies it.
    when(() => persistence.upsertEntityDefinition(any())).thenAnswer(
      (invocation) => db.upsertEntityDefinition(
        invocation.positionalArguments.single as EntityDefinition,
      ),
    );
    repository = SpeechDictionaryRepository(
      persistenceLogic: persistence,
      journalDb: db,
      updateNotifications: notifications,
    );
  });

  tearDown(() async {
    await updates.close();
    await db.close();
    unregisterJournalDbTestServices();
    directory.deleteSync(recursive: true);
  });

  Future<T> atNow<T>(Future<T> Function() action) =>
      withClock(Clock.fixed(now), action);

  Future<SpeechDictionaryEntry> stored(
    String term, {
    List<String>? categoryIds,
    List<String>? misheardAs,
    DateTime? deletedAt,
  }) async {
    final entry = SpeechDictionaryEntry(
      id: speechDictionaryEntryId(term),
      createdAt: earlier,
      updatedAt: earlier,
      term: term,
      vectorClock: null,
      categoryIds: categoryIds,
      misheardAs: misheardAs,
      deletedAt: deletedAt,
    );
    await db.upsertSpeechDictionaryEntry(entry);
    return entry;
  }

  Future<SpeechDictionaryEntry?> byTerm(String term) =>
      db.getSpeechDictionaryEntryById(speechDictionaryEntryId(term));

  group('save', () {
    test('writes a new term under the id its spelling derives', () async {
      final saved = await atNow(
        () => repository.save(
          term: '  Kubernetes ',
          categoryIds: ['work', 'home', 'work'],
          misheardAs: ['Cuban Eddies', 'kubernetes', 'Cuban Eddies'],
        ),
      );

      expect(saved.id, speechDictionaryEntryId('kubernetes'));
      expect(saved.term, 'Kubernetes');
      expect(saved.categoryIds, ['home', 'work']);
      expect(saved.misheardAs, ['Cuban Eddies']);
      expect((saved.createdAt, saved.updatedAt), (now, now));
      expect(await byTerm('Kubernetes'), saved);
    });

    test('an empty category list means every category', () async {
      final saved = await atNow(
        () => repository.save(term: 'Lotti', categoryIds: const []),
      );

      expect(saved.categoryIds, isNull);
      expect(saved.appliesToAllCategories, isTrue);
    });

    test('editing keeps when the term was added and replaces the rest', () {
      return atNow(() async {
        await stored(
          'Kubernetes',
          categoryIds: ['work'],
          misheardAs: ['Cuban Eddies'],
        );

        final saved = await repository.save(
          term: 'Kubernetes',
          misheardAs: ['Cooper Netties'],
        );

        expect(saved.createdAt, earlier);
        expect(saved.updatedAt, now);
        expect(saved.categoryIds, isNull);
        expect(saved.misheardAs, ['Cooper Netties']);
      });
    });

    test('adding a deleted term again starts it afresh', () async {
      await stored('Lottie', deletedAt: earlier);

      final saved = await atNow(() => repository.save(term: 'Lottie'));

      expect(saved.createdAt, now);
      expect((await byTerm('Lottie'))?.deletedAt, isNull);
    });

    test('respelling deletes the old spelling', () async {
      final previous = await stored('Cooper Netties');

      await atNow(
        () => repository.save(term: 'Kubernetes', previous: previous),
      );

      expect((await byTerm('Cooper Netties'))?.deletedAt, now);
      expect((await byTerm('Kubernetes'))?.deletedAt, isNull);
    });

    test('changing only the case keeps one entry', () async {
      final previous = await stored('kubernetes');

      await atNow(
        () => repository.save(term: 'Kubernetes', previous: previous),
      );

      final entry = await byTerm('Kubernetes');
      expect(entry?.term, 'Kubernetes');
      expect(entry?.deletedAt, isNull);
    });

    test('refuses an empty or over-long term', () async {
      expect(
        () => repository.save(term: '  '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.save(term: 'x' * (kMaxTermLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });
  });

  group('delete', () {
    test('leaves a tombstone stamped now', () async {
      await stored('Lottie');

      await atNow(() => repository.delete(speechDictionaryEntryId('Lottie')));

      final entry = await byTerm('Lottie');
      expect((entry?.deletedAt, entry?.updatedAt), (now, now));
      expect(await repository.entryForTerm('Lottie'), isNull);
    });

    test('writes nothing for an unknown or already deleted entry', () async {
      await stored('Lottie', deletedAt: earlier);

      await repository.delete(speechDictionaryEntryId('Lottie'));
      await repository.delete('missing');

      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });
  });

  group('addTerm', () {
    test('adds a new term limited to the category it was picked in', () async {
      expect(
        await atNow(() => repository.addTerm('Kubernetes', categoryId: 'work')),
        SpeechDictionaryAddResult.added,
      );
      expect((await byTerm('Kubernetes'))?.categoryIds, ['work']);
    });

    test('adds a term picked with no category for every category', () async {
      await atNow(() => repository.addTerm('Lotti'));

      expect((await byTerm('Lotti'))?.appliesToAllCategories, isTrue);
    });

    test('extends a term limited elsewhere to this category', () async {
      await stored('Kubernetes', categoryIds: ['work']);

      expect(
        await atNow(() => repository.addTerm('kubernetes', categoryId: 'home')),
        SpeechDictionaryAddResult.scopeExtended,
      );
      final entry = await byTerm('Kubernetes');
      expect(entry?.categoryIds, ['home', 'work']);
      // The spelling already stored is kept.
      expect(entry?.term, 'Kubernetes');
    });

    test('widens a limited term to all when picked without one', () async {
      await stored('Kubernetes', categoryIds: ['work']);

      expect(
        await atNow(() => repository.addTerm('Kubernetes')),
        SpeechDictionaryAddResult.scopeExtended,
      );
      expect((await byTerm('Kubernetes'))?.appliesToAllCategories, isTrue);
    });

    test('reports a term that already reaches the category', () async {
      await stored('Lotti');

      expect(
        await repository.addTerm('Lotti', categoryId: 'work'),
        SpeechDictionaryAddResult.alreadyPresent,
      );
      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });

    test('rejects an empty or over-long term', () async {
      expect(
        await repository.addTerm(' '),
        SpeechDictionaryAddResult.emptyTerm,
      );
      expect(
        await repository.addTerm('x' * (kMaxTermLength + 1)),
        SpeechDictionaryAddResult.termTooLong,
      );
    });
  });

  group('learnMisheardForms', () {
    test('records each correction on the term it corrected to', () async {
      await stored('Kubernetes', misheardAs: ['Cuban Eddies']);
      await stored('Lotti');

      final changed = await atNow(
        () => repository.learnMisheardForms([
          (from: 'Cooper Netties', to: 'kubernetes'),
          (from: 'Cuban Eddies', to: 'Kubernetes'),
          (from: 'Lottie', to: 'Lotti'),
          (from: 'Mars', to: 'not a term'),
        ]),
      );

      expect(changed, 2);
      expect((await byTerm('Kubernetes'))?.misheardAs, [
        'Cuban Eddies',
        'Cooper Netties',
      ]);
      expect((await byTerm('Lotti'))?.misheardAs, ['Lottie']);
      expect(await byTerm('not a term'), isNull);
    });

    test('leaves deleted terms and known forms untouched', () async {
      await stored('Lottie', deletedAt: earlier);
      await stored('Lotti', misheardAs: ['Lottie']);

      final changed = await repository.learnMisheardForms([
        (from: 'Lotty', to: 'Lottie'),
        (from: 'lottie', to: 'Lotti'),
      ]);

      expect(changed, 0);
      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });
  });

  group('reading', () {
    test('entriesReaching gives the global and the category terms', () async {
      await stored('Lotti');
      await stored('Kubernetes', categoryIds: ['work']);
      await stored('Lottie', deletedAt: earlier);

      expect(
        (await repository.entriesReaching('work')).map((e) => e.term),
        ['Kubernetes', 'Lotti'],
      );
      expect(
        (await repository.entriesReaching('home')).map((e) => e.term),
        ['Lotti'],
      );
    });

    test('watchEntries emits again when the dictionary changes', () async {
      final queue = StreamQueue(repository.watchEntries());
      addTearDown(queue.cancel);
      expect(await queue.next, isEmpty);

      await stored('Lotti');
      updates.add({speechDictionaryNotification});

      expect((await queue.next).map((e) => e.term), ['Lotti']);
    });
  });
}
