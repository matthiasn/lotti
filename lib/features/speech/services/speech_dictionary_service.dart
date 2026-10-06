import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';

/// Adds terms to the speech dictionary from an entry's context — the
/// editor's "Add to Dictionary" on a text selection.
final speechDictionaryServiceProvider = Provider<SpeechDictionaryService>((
  ref,
) {
  return SpeechDictionaryService(
    dictionaryRepository: ref.watch(speechDictionaryRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
  );
});

class SpeechDictionaryService {
  SpeechDictionaryService({
    required this.dictionaryRepository,
    required this.journalRepository,
  });

  final SpeechDictionaryRepository dictionaryRepository;
  final JournalRepository journalRepository;

  /// Adds [term] to the dictionary for recordings in the category of the
  /// entry [entryId]: the entry's own, else its linked task's. A term the
  /// dictionary already holds for other categories gains this one; with no
  /// category to go by, a new term applies to every category.
  Future<SpeechDictionaryResult> addTermForEntry({
    required String entryId,
    required String term,
  }) async {
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return SpeechDictionaryResult.emptyTerm;
    }
    if (trimmedTerm.length > kMaxTermLength) {
      return SpeechDictionaryResult.termTooLong;
    }

    final entry = await journalRepository.getJournalEntityById(entryId);
    if (entry == null) {
      return SpeechDictionaryResult.entryNotFound;
    }

    final SpeechDictionaryAddResult added;
    try {
      added = await dictionaryRepository.addTerm(
        trimmedTerm,
        categoryId: await _getCategoryIdForEntry(entry),
      );
    } on Exception {
      return SpeechDictionaryResult.saveFailed;
    }

    return switch (added) {
      SpeechDictionaryAddResult.added ||
      SpeechDictionaryAddResult.scopeExtended => SpeechDictionaryResult.success,
      SpeechDictionaryAddResult.alreadyPresent =>
        SpeechDictionaryResult.duplicate,
      SpeechDictionaryAddResult.emptyTerm => SpeechDictionaryResult.emptyTerm,
      SpeechDictionaryAddResult.termTooLong =>
        SpeechDictionaryResult.termTooLong,
    };
  }

  /// The category a term picked in [entry] belongs to: the entry's own, or
  /// for an image or recording without one, its linked task's.
  Future<String?> _getCategoryIdForEntry(JournalEntity entry) async {
    final own = entry.meta.categoryId;
    if (own != null || entry is Task) return own;

    if (entry is JournalImage || entry is JournalAudio) {
      final linkedEntities = await journalRepository.getLinkedToEntities(
        linkedTo: entry.id,
      );
      for (final linked in linkedEntities) {
        if (linked is Task) {
          return linked.meta.categoryId;
        }
      }
    }

    return null;
  }
}

/// Result of attempting to add a term to the speech dictionary.
enum SpeechDictionaryResult {
  /// The term was added, or its scope extended to the entry's category.
  success,

  /// The term was empty after trimming.
  emptyTerm,

  /// The term exceeds the maximum length.
  termTooLong,

  /// The term already reaches the entry's category (case-insensitive).
  duplicate,

  /// The entry was not found.
  entryNotFound,

  /// Failed to save the entry.
  saveFailed,
}
