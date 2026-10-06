import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/services/speech_dictionary_migration.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

CategoryDefinition _category(
  String id, {
  List<String>? dictionary,
  DateTime? deletedAt,
}) => CategoryDefinition(
  id: id,
  name: 'Category $id',
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
  vectorClock: null,
  private: false,
  active: true,
  speechDictionary: dictionary,
  deletedAt: deletedAt,
);

/// A device: its own journal, migrating through a persistence layer that
/// seeds straight through that journal's recency gate, as the real one does.
class _Device {
  _Device(this.logger)
    : db = JournalDb(inMemoryDatabase: true),
      persistence = MockPersistenceLogic() {
    when(() => persistence.seedEntityDefinition(any())).thenAnswer(
      (invocation) => db.upsertEntityDefinition(
        invocation.positionalArguments.single as EntityDefinition,
      ),
    );
  }

  final DomainLogger logger;
  final JournalDb db;
  final MockPersistenceLogic persistence;

  late final migration = SpeechDictionaryMigration(
    journalDb: db,
    persistenceLogic: persistence,
    domainLogger: logger,
  );

  Future<void> hold(List<CategoryDefinition> categories) async {
    for (final category in categories) {
      await db.upsertCategoryDefinition(category);
    }
  }

  /// The user's edit, which is stamped at the time it is made.
  Future<SpeechDictionaryEntry> edit(SpeechDictionaryEntry entry) async {
    await db.upsertSpeechDictionaryEntry(entry);
    return entry;
  }

  /// Sync: every entry this device holds, applied on [other].
  Future<void> sendTo(_Device other) async {
    for (final entry in await db.getSpeechDictionaryEntriesIncludingDeleted()) {
      await other.db.upsertSpeechDictionaryEntry(entry);
    }
  }

  Future<SpeechDictionaryEntry?> entry(String term) =>
      db.getSpeechDictionaryEntryById(speechDictionaryEntryId(term));
}

void main() {
  setUpAll(() {
    registerJournalDbTestFallbacks();
    registerAllFallbackValues();
  });

  group('legacySpeechDictionaryEntries', () {
    test('makes one entry per term, limited to every category holding it', () {
      final entries = legacySpeechDictionaryEntries([
        _category('b-work', dictionary: ['Kubernetes', 'Lotti']),
        _category('a-home', dictionary: ['lotti ', 'Kirkjubæjarklaustur']),
      ]);

      expect(
        {for (final entry in entries) entry.term: entry.categoryIds},
        {
          // The spelling of the category with the smallest id wins.
          'lotti': ['a-home', 'b-work'],
          'Kirkjubæjarklaustur': ['a-home'],
          'Kubernetes': ['b-work'],
        },
      );
      expect(
        entries.map((entry) => (entry.createdAt, entry.updatedAt)).toSet(),
        {(kMigratedEntryStamp, kMigratedEntryStamp)},
      );
    });

    test('is the same for the same categories in any order', () {
      final categories = [
        _category('b', dictionary: ['Lotti']),
        _category('a', dictionary: ['LOTTI']),
      ];

      expect(
        legacySpeechDictionaryEntries(categories),
        legacySpeechDictionaryEntries(categories.reversed),
      );
    });

    test('skips deleted categories, blank and over-long terms', () {
      expect(
        legacySpeechDictionaryEntries([
          _category('gone', dictionary: ['Lotti'], deletedAt: DateTime(2025)),
          _category('a', dictionary: ['  ', 'x' * (kMaxTermLength + 1)]),
          _category('none'),
        ]),
        isEmpty,
      );
    });
  });

  group('SpeechDictionaryMigration.run', () {
    late Directory directory;
    late MockDomainLogger logger;
    final devices = <_Device>[];

    _Device device() {
      final created = _Device(logger);
      devices.add(created);
      return created;
    }

    setUp(() {
      directory = setupTestDirectory();
      logger = MockDomainLogger();
      registerJournalDbTestServices(
        updateNotifications: MockUpdateNotifications(),
        loggingService: logger,
        documentsDirectory: directory,
      );
    });

    tearDown(() async {
      for (final created in devices) {
        await created.db.close();
      }
      devices.clear();
      unregisterJournalDbTestServices();
      directory.deleteSync(recursive: true);
    });

    test('writes each legacy term once, and nothing on a later run', () async {
      final phone = device();
      await phone.hold([
        _category('work', dictionary: ['Kubernetes', 'Lotti']),
      ]);

      expect(await phone.migration.run(), 2);
      expect(await phone.migration.run(), 0);

      // The second run found both held and asked to write neither.
      verify(() => phone.persistence.seedEntityDefinition(any())).called(2);
      expect((await phone.entry('Kubernetes'))?.categoryIds, ['work']);
      verify(
        () => logger.log(
          LogDomain.ai,
          'Migrated 2 speech dictionary terms from categories',
          subDomain: 'speechDictionaryMigration',
        ),
      ).called(1);
    });

    test(
      'migrates private categories while private entries are hidden',
      () async {
        final phone = device();
        await phone.hold([
          _category('work', dictionary: ['Kubernetes']),
          _category(
            'secret',
            dictionary: ['Kubernetes'],
          ).copyWith(private: true),
        ]);
        // Private entries are hidden: the visible category list lacks it.
        expect(
          (await phone.db.getAllCategories()).map((c) => c.id),
          ['work'],
        );

        await phone.migration.run();

        expect((await phone.entry('Kubernetes'))?.categoryIds, [
          'secret',
          'work',
        ]);
      },
    );

    // SpeechDictionarySync.tla, AbsentOnly: a later run must not bring back
    // a term the user deleted, nor widen one the user limited.
    test('leaves a term the device holds an entry for alone', () async {
      final phone = device();
      await phone.hold([
        _category('work', dictionary: ['Kubernetes', 'Lottie']),
        _category('home', dictionary: ['Kubernetes']),
      ]);
      final now = DateTime.utc(2026, 10);
      await phone.edit(
        SpeechDictionaryEntry(
          id: speechDictionaryEntryId('Lottie'),
          createdAt: now,
          updatedAt: now,
          term: 'Lottie',
          vectorClock: null,
          deletedAt: now,
        ),
      );
      await phone.edit(
        SpeechDictionaryEntry(
          id: speechDictionaryEntryId('Kubernetes'),
          createdAt: now,
          updatedAt: now,
          term: 'Kubernetes',
          vectorClock: null,
          categoryIds: const ['work'],
        ),
      );

      expect(await phone.migration.run(), 0);
      verifyNever(() => phone.persistence.seedEntityDefinition(any()));
      expect((await phone.entry('Lottie'))?.deletedAt, now);
      expect((await phone.entry('Kubernetes'))?.categoryIds, ['work']);
    });

    // SpeechDictionarySync.tla, MinimalStamp: a device that migrates after
    // the user edited the term elsewhere must not override the edit, in
    // either delivery order.
    test('a late migration never outranks the edit made elsewhere', () async {
      final laptop = device();
      final phone = device();
      final legacy = [
        _category('work', dictionary: ['Kubernetes']),
      ];
      await laptop.hold(legacy);
      await phone.hold(legacy);

      await laptop.migration.run();
      final now = DateTime.utc(2026, 10);
      final edited = await laptop.edit(
        (await laptop.entry('Kubernetes'))!.copyWith(
          updatedAt: now,
          categoryIds: const ['work', 'home'],
          misheardAs: const ['Cuban Eddies'],
        ),
      );
      // The phone has not heard of the edit yet when it migrates.
      await phone.migration.run();

      await phone.sendTo(laptop);
      await laptop.sendTo(phone);

      expect(await laptop.entry('Kubernetes'), edited);
      expect(await phone.entry('Kubernetes'), edited);
    });

    // SpeechDictionarySync.tla, LegacyKept with TotalOrder: devices holding
    // different legacy lists write different entries at the same stamp, and
    // still agree once each has the other's.
    test('devices migrating different lists end on one entry', () async {
      final laptop = device();
      final phone = device();
      await laptop.hold([
        _category('work', dictionary: ['Kubernetes']),
      ]);
      await phone.hold([
        _category('work', dictionary: ['Kubernetes']),
        _category('home', dictionary: ['Kubernetes']),
      ]);

      await laptop.migration.run();
      await phone.migration.run();
      await laptop.sendTo(phone);
      await phone.sendTo(laptop);

      final onLaptop = await laptop.entry('Kubernetes');
      expect(onLaptop, await phone.entry('Kubernetes'));
      expect(onLaptop?.deletedAt, isNull);
      expect(
        onLaptop?.categoryIds,
        anyOf(equals(['work']), equals(['home', 'work'])),
      );
    });

    test('logs a failure and reports nothing written', () async {
      final journalDb = MockJournalDb();
      when(
        journalDb.getSpeechDictionaryEntriesIncludingDeleted,
      ).thenThrow(StateError('closed'));

      final written = await SpeechDictionaryMigration(
        journalDb: journalDb,
        persistenceLogic: MockPersistenceLogic(),
        domainLogger: logger,
      ).run();

      expect(written, 0);
      verify(
        () => logger.error(
          LogDomain.ai,
          any<Object>(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'speechDictionaryMigration',
        ),
      ).called(1);
    });
  });
}
