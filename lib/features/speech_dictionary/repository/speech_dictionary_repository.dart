import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';

final speechDictionaryRepositoryProvider = Provider<SpeechDictionaryRepository>(
  (ref) => SpeechDictionaryRepository(
    persistenceLogic: ref.read(persistenceLogicProvider),
    journalDb: ref.read(journalDbProvider),
    updateNotifications: ref.watch(updateNotificationsProvider),
  ),
);

/// What adding a single term (from the editor's selection menu) did.
enum SpeechDictionaryAddResult {
  /// A new entry was written.
  added,

  /// The term was already there, limited to other categories; the
  /// recording's category was added to them.
  scopeExtended,

  /// The term already reaches the recording's category.
  alreadyPresent,
  emptyTerm,
  termTooLong,
}

/// A correction a model made: `from`, what the transcript said, became `to`,
/// a dictionary term.
typedef TermCorrection = ({String from, String to});

/// Write boundary for the speech dictionary.
///
/// Every edit goes through `PersistenceLogic.upsertEntityDefinition`, which
/// stamps it past the stored copy and sends it to the other devices. An
/// entry's id is derived from its term, so writing a term that is already
/// there updates that entry instead of adding a second one.
class SpeechDictionaryRepository {
  SpeechDictionaryRepository({
    required this._persistenceLogic,
    required this._journalDb,
    required this._updateNotifications,
  });

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final UpdateNotifications _updateNotifications;

  /// Every live entry, ordered by term, again whenever the dictionary, the
  /// categories or the privacy toggle change, here or on another device.
  ///
  /// Without [includePrivate], an entry limited only to private categories
  /// is left out: its terms and misheard spellings belong to those
  /// categories, and are hidden with them.
  Stream<List<SpeechDictionaryEntry>> watchEntries({
    bool includePrivate = true,
  }) => notificationDrivenStream(
    notifications: _updateNotifications,
    notificationKeys: {
      speechDictionaryNotification,
      categoriesNotification,
      privateToggleNotification,
    },
    fetcher: () => _entries(includePrivate: includePrivate),
  );

  Future<List<SpeechDictionaryEntry>> _entries({
    required bool includePrivate,
  }) async {
    final entries = await _journalDb.getAllSpeechDictionaryEntries();
    if (includePrivate) return entries;
    final privateIds = {
      for (final category
          in await _journalDb.getAllCategoriesIncludingPrivate())
        if (category.private) category.id,
    };
    return [
      for (final entry in entries)
        if (entry.appliesToAllCategories ||
            !entry.categoryIds!.every(privateIds.contains))
          entry,
    ];
  }

  /// The live entries that reach a recording in [categoryId].
  Future<List<SpeechDictionaryEntry>> entriesReaching(
    String? categoryId,
  ) async => entriesForCategory(
    await _journalDb.getAllSpeechDictionaryEntries(),
    categoryId,
  );

  /// The live entry for [term], or null when the dictionary does not hold
  /// it.
  Future<SpeechDictionaryEntry?> entryForTerm(String term) async {
    final stored = await _journalDb.getSpeechDictionaryEntryById(
      speechDictionaryEntryId(term),
    );
    return stored?.deletedAt == null ? stored : null;
  }

  /// Writes [term] limited to [categoryIds] (none for every category) with
  /// the misheard spellings [misheardAs], replacing what the entry held.
  ///
  /// When [previous] is the entry of a different term — the user respelled
  /// it — that entry is deleted, so the old spelling stops being suggested.
  Future<SpeechDictionaryEntry> save({
    required String term,
    List<String>? categoryIds,
    List<String>? misheardAs,
    SpeechDictionaryEntry? previous,
  }) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty || trimmed.length > kMaxTermLength) {
      throw ArgumentError.value(term, 'term', 'empty or too long');
    }
    final id = speechDictionaryEntryId(trimmed);
    final stored = await _journalDb.getSpeechDictionaryEntryById(id);
    final now = clock.now();
    final entry = SpeechDictionaryEntry(
      id: id,
      createdAt: stored != null && stored.deletedAt == null
          ? stored.createdAt
          : now,
      updatedAt: now,
      term: trimmed,
      vectorClock: stored?.vectorClock,
      categoryIds: _normalizeCategoryIds(categoryIds),
      misheardAs: mergeMisheardForms(null, misheardAs ?? const [], term: term),
    );
    await _persistenceLogic.upsertEntityDefinition(entry);
    if (previous != null && previous.id != id) {
      await delete(previous.id);
    }
    return entry;
  }

  /// Soft-deletes the entry with [id]. The tombstone syncs, and keeps the
  /// migration from writing the term again.
  Future<void> delete(String id) async {
    final stored = await _journalDb.getSpeechDictionaryEntryById(id);
    if (stored == null || stored.deletedAt != null) return;
    final now = clock.now();
    await _persistenceLogic.upsertEntityDefinition(
      stored.copyWith(updatedAt: now, deletedAt: now),
    );
  }

  /// Adds [term] so it reaches recordings in [categoryId] — the editor's
  /// "Add to dictionary". A new term is limited to that category, since the
  /// word was picked in its context; without a category it applies to all.
  Future<SpeechDictionaryAddResult> addTerm(
    String term, {
    String? categoryId,
  }) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return SpeechDictionaryAddResult.emptyTerm;
    if (trimmed.length > kMaxTermLength) {
      return SpeechDictionaryAddResult.termTooLong;
    }
    final stored = await _journalDb.getSpeechDictionaryEntryById(
      speechDictionaryEntryId(trimmed),
    );
    if (stored != null && stored.deletedAt == null) {
      if (stored.appliesTo(categoryId)) {
        return SpeechDictionaryAddResult.alreadyPresent;
      }
      await _persistenceLogic.upsertEntityDefinition(
        stored.copyWith(
          updatedAt: clock.now(),
          categoryIds: categoryId == null
              ? null
              : _normalizeCategoryIds([...?stored.categoryIds, categoryId]),
        ),
      );
      return SpeechDictionaryAddResult.scopeExtended;
    }
    await save(
      term: trimmed,
      categoryIds: categoryId == null ? null : [categoryId],
    );
    return SpeechDictionaryAddResult.added;
  }

  /// Records each correction's `from` as a misheard spelling
  /// of the live entry whose term is `to`. Corrections to a
  /// word that is not a dictionary term are ignored. Returns how many
  /// entries changed.
  Future<int> learnMisheardForms(Iterable<TermCorrection> corrections) async {
    final formsByTermId = <String, List<String>>{};
    for (final correction in corrections) {
      formsByTermId
          .putIfAbsent(speechDictionaryEntryId(correction.to), () => [])
          .add(correction.from);
    }
    var changed = 0;
    for (final MapEntry(key: id, value: forms) in formsByTermId.entries) {
      final stored = await _journalDb.getSpeechDictionaryEntryById(id);
      if (stored == null || stored.deletedAt != null) continue;
      final merged = mergeMisheardForms(
        stored.misheardAs,
        forms,
        term: stored.term,
      );
      if (_sameList(merged, stored.misheardAs)) continue;
      await _persistenceLogic.upsertEntityDefinition(
        stored.copyWith(updatedAt: clock.now(), misheardAs: merged),
      );
      changed++;
    }
    return changed;
  }

  static List<String>? _normalizeCategoryIds(List<String>? categoryIds) {
    final unique = {...?categoryIds}.toList()..sort();
    return unique.isEmpty ? null : unique;
  }

  static bool _sameList(List<String>? a, List<String>? b) {
    final left = a ?? const <String>[];
    final right = b ?? const <String>[];
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
