import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/utils/string_utils.dart' as string_utils;
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'correction_capture_service.g.dart';

/// Duration before a pending correction is automatically saved.
const kCorrectionSaveDelay = Duration(seconds: 5);

/// Provider for the correction capture service.
@riverpod
CorrectionCaptureService correctionCaptureService(Ref ref) {
  return CorrectionCaptureService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    notifier: ref.read(correctionCaptureNotifierProvider.notifier),
  );
}

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.
@riverpod
class CorrectionCaptureNotifier extends _$CorrectionCaptureNotifier {
  Timer? _saveTimer;

  @override
  PendingCorrection? build() {
    ref.onDispose(() {
      _saveTimer?.cancel();
      _saveTimer = null;
    });
    return null;
  }

  /// Sets a pending correction and starts the countdown timer.
  /// After the delay, the correction will be saved automatically.
  void setPending({
    required PendingCorrection pending,
    required Future<void> Function() onSave,
  }) {
    // Cancel any existing timer
    _saveTimer?.cancel();

    state = pending;

    // Start the countdown timer
    _saveTimer = Timer(kCorrectionSaveDelay, () async {
      if (state == pending) {
        await onSave();
        state = null;
      }
    });
  }

  /// Cancels the pending correction (user clicked undo).
  /// Returns true if there was a pending correction to cancel.
  bool cancel() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (state != null) {
      developer.log(
        'Correction capture: cancelled by user',
        name: 'CorrectionCaptureService',
      );
      state = null;
      return true;
    }
    return false;
  }

  /// Clears the state without cancelling (used after save completes).
  void clear() {
    state = null;
  }
}

/// Represents a pending correction that hasn't been saved yet.
@immutable
class PendingCorrection {
  PendingCorrection({
    required this.before,
    required this.after,
    required this.categoryId,
    required this.categoryName,
    required this.createdAt,
  }) : id = _nextId++;

  static int _nextId = 0;

  /// Unique ID for this pending correction instance.
  final int id;
  final String before;
  final String after;
  final String categoryId;
  final String categoryName;
  final DateTime createdAt;

  /// Returns the remaining time until the correction is saved.
  Duration get remainingTime {
    final elapsed = DateTime.now().difference(createdAt);
    final remaining = kCorrectionSaveDelay - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingCorrection &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
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
    this.notifier,
  });

  final CategoryRepository categoryRepository;
  final CorrectionCaptureNotifier? notifier;

  /// Captures a correction if the before and after texts differ meaningfully.
  ///
  /// Instead of saving immediately, this creates a pending correction that
  /// will be saved after [kCorrectionSaveDelay] unless the user cancels.
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

    // Create a pending correction and notify the UI
    final pending = PendingCorrection(
      before: normalizedBefore,
      after: normalizedAfter,
      categoryId: categoryId,
      categoryName: category.name,
      createdAt: DateTime.now(),
    );

    developer.log(
      'Correction capture: pending "$normalizedBefore" -> "$normalizedAfter" '
      'for category "${category.name}" (will save in ${kCorrectionSaveDelay.inSeconds}s)',
      name: 'CorrectionCaptureService',
    );

    // Set up the pending correction with delayed save
    notifier?.setPending(
      pending: pending,
      onSave: () => _saveCorrection(
        categoryId: categoryId,
        normalizedBefore: normalizedBefore,
        normalizedAfter: normalizedAfter,
      ),
    );

    return CorrectionCaptureResult.pending;
  }

  /// Actually saves the correction to the database.
  /// Called after the countdown expires without cancellation.
  Future<void> _saveCorrection({
    required String categoryId,
    required String normalizedBefore,
    required String normalizedAfter,
  }) async {
    // Re-fetch category to get latest state
    final category = await categoryRepository.getCategoryById(categoryId);
    if (category == null) {
      developer.log(
        'Correction capture: save aborted (category not found)',
        name: 'CorrectionCaptureService',
      );
      return;
    }

    // Re-check for duplicates in case one was added during the delay
    final existingExamples = category.correctionExamples ?? [];
    if (_isDuplicate(existingExamples, normalizedBefore, normalizedAfter)) {
      developer.log(
        'Correction capture: save aborted (duplicate)',
        name: 'CorrectionCaptureService',
      );
      return;
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
    } on Exception catch (e) {
      developer.log(
        'Correction capture: save failed: $e',
        name: 'CorrectionCaptureService',
      );
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
  /// Correction is pending and will be saved after countdown.
  pending,

  /// Correction was captured successfully (immediate save - legacy).
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
