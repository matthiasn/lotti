import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// The stamp of a migrated entry: before any edit a user can make, so every
/// edit of the term outranks it (SpeechDictionarySync.tla, `MinimalStamp`),
/// and the same on every device, so two devices migrating the same lists
/// write the same entry.
final DateTime kMigratedEntryStamp = DateTime.fromMillisecondsSinceEpoch(
  0,
  isUtc: true,
);

/// Carries the categories' legacy `speechDictionary` lists into dictionary
/// entries, on every device, at every start.
///
/// Each term becomes one entry limited to every category whose list holds
/// it. A term this device already holds an entry for — live or deleted — is
/// left alone (`AbsentOnly`): migration is a one-time carry-over, never a
/// merge, so it cannot undo an edit or bring back a deletion, whenever it
/// runs. It writes through `PersistenceLogic.seedEntityDefinition`, not the
/// local edit path, which would re-stamp a refused copy past what is stored:
/// an entry that arrived from another device in between must win.
///
/// The legacy lists are read, never cleared, so a device that migrates later
/// still finds them.
class SpeechDictionaryMigration {
  SpeechDictionaryMigration({
    required this._journalDb,
    required this._persistenceLogic,
    required this._domainLogger,
  });

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final DomainLogger _domainLogger;

  /// Writes the entries this device does not hold yet and returns how many.
  Future<int> run() async {
    try {
      final held = {
        for (final entry
            in await _journalDb.getSpeechDictionaryEntriesIncludingDeleted())
          entry.id,
      };
      // Private categories too, whatever the privacy toggle shows now: a
      // term migrated without one of its categories never gains it later.
      final pending = legacySpeechDictionaryEntries(
        await _journalDb.getAllCategoriesIncludingPrivate(),
      ).where((entry) => !held.contains(entry.id));

      var written = 0;
      for (final entry in pending) {
        if (await _persistenceLogic.seedEntityDefinition(entry) > 0) {
          written++;
        }
      }
      if (written > 0) {
        _domainLogger.log(
          LogDomain.ai,
          'Migrated $written speech dictionary terms from categories',
          subDomain: 'speechDictionaryMigration',
        );
      }
      return written;
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'speechDictionaryMigration',
      );
      return 0;
    }
  }
}

/// The entries the legacy lists of [categories] describe: one per term,
/// limited to every category whose list holds it, at the migrated stamp.
///
/// Deterministic for the same categories in any order: a term's first
/// spelling is taken from the category with the smallest id, and the
/// category ids are sorted.
List<SpeechDictionaryEntry> legacySpeechDictionaryEntries(
  Iterable<CategoryDefinition> categories,
) {
  final sorted = categories.where((c) => c.deletedAt == null).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final terms = <String, String>{};
  final scopes = <String, Set<String>>{};
  for (final category in sorted) {
    for (final term in category.speechDictionary ?? const <String>[]) {
      final trimmed = term.trim();
      if (trimmed.isEmpty || trimmed.length > kMaxTermLength) continue;
      final id = speechDictionaryEntryId(trimmed);
      terms.putIfAbsent(id, () => trimmed);
      scopes.putIfAbsent(id, () => {}).add(category.id);
    }
  }
  return [
    for (final MapEntry(key: id, value: term) in terms.entries)
      SpeechDictionaryEntry(
        id: id,
        createdAt: kMigratedEntryStamp,
        updatedAt: kMigratedEntryStamp,
        term: term,
        vectorClock: null,
        categoryIds: scopes[id]!.toList()..sort(),
      ),
  ];
}
