import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';

/// Service for managing speech dictionary operations.
///
/// This service provides methods to add terms to a category's speech dictionary
/// from various contexts (e.g., text editor context menu).
final speechDictionaryServiceProvider =
    Provider<SpeechDictionaryService>((ref) {
  return SpeechDictionaryService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
  );
});

class SpeechDictionaryService {
  SpeechDictionaryService({
    required this.categoryRepository,
    required this.journalRepository,
  });

  final CategoryRepository categoryRepository;
  final JournalRepository journalRepository;

  /// Adds a term to the speech dictionary of the category associated with the given entry.
  ///
  /// Returns a [SpeechDictionaryResult] indicating success or the reason for failure.
  ///
  /// The entry can be:
  /// - A Task: uses the task's category directly
  /// - A JournalImage or JournalAudio: looks for a linked task and uses its category
  /// - Other types: returns [SpeechDictionaryResult.noCategory]
  Future<SpeechDictionaryResult> addTermForEntry({
    required String entryId,
    required String term,
  }) async {
    // Validate term
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return SpeechDictionaryResult.emptyTerm;
    }

    if (trimmedTerm.length > kMaxTermLength) {
      return SpeechDictionaryResult.termTooLong;
    }

    // Get the entry
    final entry = await journalRepository.getJournalEntityById(entryId);
    if (entry == null) {
      return SpeechDictionaryResult.entryNotFound;
    }

    // Find the task and its category
    final categoryId = await _getCategoryIdForEntry(entry);
    if (categoryId == null) {
      return SpeechDictionaryResult.noCategory;
    }

    // Get the category
    final category = await categoryRepository.getCategoryById(categoryId);
    if (category == null) {
      return SpeechDictionaryResult.categoryNotFound;
    }

    // Add term to dictionary
    final currentDictionary = category.speechDictionary ?? [];
    final updatedDictionary = [...currentDictionary, trimmedTerm];

    // Update category
    final updatedCategory = category.copyWith(
      speechDictionary: updatedDictionary,
    );

    await categoryRepository.updateCategory(updatedCategory);

    return SpeechDictionaryResult.success;
  }

  /// Gets the category ID for a given entry.
  ///
  /// For tasks, returns the task's category ID directly.
  /// For images and audio, looks for a linked task and returns its category ID.
  Future<String?> _getCategoryIdForEntry(JournalEntity entry) async {
    if (entry is Task) {
      return entry.meta.categoryId;
    }

    if (entry is JournalImage || entry is JournalAudio) {
      // Look for linked task
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

  /// Checks if a term can be added to the dictionary for a given entry.
  ///
  /// Returns true if the entry has an associated category.
  Future<bool> canAddTermForEntry(String entryId) async {
    final entry = await journalRepository.getJournalEntityById(entryId);
    if (entry == null) return false;

    final categoryId = await _getCategoryIdForEntry(entry);
    return categoryId != null;
  }
}

/// Result of attempting to add a term to the speech dictionary.
enum SpeechDictionaryResult {
  /// Term was added successfully.
  success,

  /// The term was empty after trimming.
  emptyTerm,

  /// The term exceeds the maximum length.
  termTooLong,

  /// The entry was not found.
  entryNotFound,

  /// The entry has no associated task with a category.
  noCategory,

  /// The category was not found.
  categoryNotFound,
}
