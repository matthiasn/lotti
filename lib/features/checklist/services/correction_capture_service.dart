import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/utils/string_utils.dart' as string_utils;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'correction_capture_service.g.dart';

/// Provider for the correction capture service.
@riverpod
CorrectionCaptureService correctionCaptureService(Ref ref) {
  return CorrectionCaptureService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
  );
}

/// Notifier for correction capture events.
/// UI can watch this to show snackbar notifications.
@riverpod
class CorrectionCaptureNotifier extends _$CorrectionCaptureNotifier {
  Timer? _resetTimer;

  @override
  CorrectionCaptureEvent? build() {
    ref.onDispose(() {
      _resetTimer?.cancel();
      _resetTimer = null;
    });
    return null;
  }

  void notify(CorrectionCaptureEvent event) {
    state = event;
    // Cancel any pending reset timer
    _resetTimer?.cancel();
    // Reset after a short delay to allow UI to react
    _resetTimer = Timer(const Duration(milliseconds: 100), () {
      if (state == event) {
        state = null;
      }
    });
  }
}

/// Event emitted when a correction is captured.
class CorrectionCaptureEvent {
  const CorrectionCaptureEvent({
    required this.before,
    required this.after,
    required this.categoryName,
  });

  final String before;
  final String after;
  final String categoryName;
}

/// Service for capturing user corrections to checklist item titles.
///
/// When a user manually edits a checklist item title, this service captures
/// the before/after pair and stores it on the item's category for use in
/// AI prompts.
///
/// Follows the pattern established by SpeechDictionaryService.
class CorrectionCaptureService {
  CorrectionCaptureService({
    required this.categoryRepository,
  });

  final CategoryRepository categoryRepository;

  /// Captures a correction if the before and after texts differ meaningfully.
  ///
  /// Returns a result enum indicating success or the reason for skipping.
  Future<CorrectionCaptureResult> captureCorrection({
    required String? categoryId,
    required String beforeText,
    required String afterText,
  }) async {
    // Skip if no category
    if (categoryId == null) {
      developer.log(
        'Correction capture: skipped (no category)',
        name: 'CorrectionCaptureService',
      );
      return CorrectionCaptureResult.noCategory;
    }

    // Use shared normalization for consistency with AI updates
    final normalizedBefore = string_utils.normalizeWhitespace(beforeText);
    final normalizedAfter = string_utils.normalizeWhitespace(afterText);

    // Skip if texts are identical after normalization
    if (normalizedBefore == normalizedAfter) {
      return CorrectionCaptureResult.noChange;
    }

    // Skip trivial changes (pure whitespace, case-only for very short texts)
    if (!_isMeaningfulCorrection(normalizedBefore, normalizedAfter)) {
      developer.log(
        'Correction capture: skipped (trivial change)',
        name: 'CorrectionCaptureService',
      );
      return CorrectionCaptureResult.trivialChange;
    }

    // Get current category
    final category = await categoryRepository.getCategoryById(categoryId);
    if (category == null) {
      developer.log(
        'Correction capture: skipped (category not found: $categoryId)',
        name: 'CorrectionCaptureService',
      );
      return CorrectionCaptureResult.categoryNotFound;
    }

    // Check for duplicates (same before/after pair already exists)
    final existingExamples = category.correctionExamples ?? [];
    if (_isDuplicate(existingExamples, normalizedBefore, normalizedAfter)) {
      developer.log(
        'Correction capture: skipped (duplicate)',
        name: 'CorrectionCaptureService',
      );
      return CorrectionCaptureResult.duplicate;
    }

    // Add the correction example
    final newExample = ChecklistCorrectionExample(
      before: normalizedBefore,
      after: normalizedAfter,
      capturedAt: DateTime.now(),
    );

    final updatedExamples = [...existingExamples, newExample];

    // Update the category
    try {
      await categoryRepository.updateCategory(
        category.copyWith(correctionExamples: updatedExamples),
      );

      developer.log(
        'Correction capture: saved "$normalizedBefore" -> "$normalizedAfter" '
        'to category "${category.name}"',
        name: 'CorrectionCaptureService',
      );

      return CorrectionCaptureResult.success;
    } on Exception catch (e) {
      developer.log(
        'Correction capture: save failed: $e',
        name: 'CorrectionCaptureService',
      );
      return CorrectionCaptureResult.saveFailed;
    }
  }

  /// Determines if a correction is meaningful enough to capture.
  bool _isMeaningfulCorrection(String before, String after) {
    // Skip if only case changes for very short texts (< 3 chars)
    if (before.length < 3 && before.toLowerCase() == after.toLowerCase()) {
      return false;
    }
    return true;
  }

  /// Checks if a correction already exists in the examples list.
  bool _isDuplicate(
    List<ChecklistCorrectionExample> existing,
    String before,
    String after,
  ) {
    return existing.any(
      (e) => e.before == before && e.after == after,
    );
  }
}

/// Result of attempting to capture a correction.
enum CorrectionCaptureResult {
  /// Correction was captured successfully.
  success,

  /// Skipped: No category ID available on the checklist item.
  noCategory,

  /// Skipped: No meaningful change after normalization.
  noChange,

  /// Skipped: Change was trivial (e.g., case-only for short text).
  trivialChange,

  /// Skipped: Same before/after pair already exists.
  duplicate,

  /// Skipped: Category was not found in database.
  categoryNotFound,

  /// Failed: Could not save to database.
  saveFailed,
}
