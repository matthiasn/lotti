import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/string_utils.dart' as string_utils;
import 'package:meta/meta.dart';

const _subDomain = 'CorrectionCaptureService';

/// Duration before a pending correction is automatically saved.
const kCorrectionSaveDelay = Duration(seconds: 5);

/// Provider for the correction capture service.
final Provider<CorrectionCaptureService> correctionCaptureServiceProvider =
    Provider.autoDispose<CorrectionCaptureService>(
      correctionCaptureService,
      name: 'correctionCaptureServiceProvider',
    );
CorrectionCaptureService correctionCaptureService(Ref ref) {
  return CorrectionCaptureService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    notifier: ref.read(correctionCaptureProvider.notifier),
  );
}

/// Notifier for pending correction with countdown.
/// UI watches this to show the snackbar with undo functionality.
final NotifierProvider<CorrectionCaptureNotifier, PendingCorrection?>
correctionCaptureProvider =
    NotifierProvider.autoDispose<CorrectionCaptureNotifier, PendingCorrection?>(
      CorrectionCaptureNotifier.new,
      name: 'correctionCaptureProvider',
    );

class CorrectionCaptureNotifier extends Notifier<PendingCorrection?> {
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
    final logger = ref.read(domainLoggerProvider);

    state = pending;

    // Start the countdown timer
    _saveTimer = Timer(kCorrectionSaveDelay, () async {
      if (state == pending) {
        try {
          await onSave();
        } catch (e, stackTrace) {
          // Log error but don't crash - correction save is fire-and-forget
          logger.error(
            LogDomain.tasks,
            e,
            stackTrace: stackTrace,
            subDomain: _subDomain,
            message: 'Correction capture: timer callback failed',
          );
        }
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
      ref
          .read(domainLoggerProvider)
          .log(
            LogDomain.tasks,
            'Correction capture: cancelled by user',
            subDomain: _subDomain,
          );
      state = null;
      return true;
    }
    return false;
  }
}

/// Represents a pending correction that hasn't been saved yet.
@immutable
class PendingCorrection {
  PendingCorrection({
    required this.before,
    required this.after,
    required this.createdAt,
  }) : id = _nextId++;

  static int _nextId = 0;

  /// Unique ID for this pending correction instance.
  final int id;

  /// Normalized original title before the user's edit.
  final String before;

  /// Normalized title after the user's edit.
  final String after;

  /// Wall-clock time the correction was captured; anchors [remainingTime].
  final DateTime createdAt;

  /// Returns the remaining time until the correction is saved.
  ///
  /// Reads the wall clock via `clock.now()` so tests can pin it with
  /// `withClock`.
  Duration get remainingTime {
    final elapsed = clock.now().difference(createdAt);
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
    required this._domainLogger,
    this.notifier,
  });

  final CategoryRepository categoryRepository;

  /// Receives the capture outcomes — never the before/after text, which is
  /// the user's checklist content.
  final DomainLogger _domainLogger;
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
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: skipped (no category)',
        subDomain: _subDomain,
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
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: skipped (trivial change)',
        subDomain: _subDomain,
      );
      return CorrectionCaptureResult.trivialChange;
    }

    // Get current category
    final category = await categoryRepository.getCategoryById(categoryId);
    if (category == null) {
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: skipped (category not found: $categoryId)',
        subDomain: _subDomain,
      );
      return CorrectionCaptureResult.categoryNotFound;
    }

    // Check for duplicates (same before/after pair already exists)
    final existingExamples = category.correctionExamples ?? [];
    if (_isDuplicate(existingExamples, normalizedBefore, normalizedAfter)) {
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: skipped (duplicate)',
        subDomain: _subDomain,
      );
      return CorrectionCaptureResult.duplicate;
    }

    // Create a pending correction and notify the UI
    final pending = PendingCorrection(
      before: normalizedBefore,
      after: normalizedAfter,
      createdAt: clock.now(),
    );

    _domainLogger.log(
      LogDomain.tasks,
      'Correction capture: pending for category ${category.id} '
      '(will save in ${kCorrectionSaveDelay.inSeconds}s)',
      subDomain: _subDomain,
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
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: save aborted (category not found)',
        subDomain: _subDomain,
      );
      return;
    }

    // Re-check for duplicates in case one was added during the delay
    final existingExamples = category.correctionExamples ?? [];
    if (_isDuplicate(existingExamples, normalizedBefore, normalizedAfter)) {
      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: save aborted (duplicate)',
        subDomain: _subDomain,
      );
      return;
    }

    // Add the correction example
    final newExample = ChecklistCorrectionExample(
      before: normalizedBefore,
      after: normalizedAfter,
      capturedAt: clock.now(),
    );

    final updatedExamples = [...existingExamples, newExample];

    // Update the category
    try {
      await categoryRepository.updateCategory(
        category.copyWith(correctionExamples: updatedExamples),
      );

      _domainLogger.log(
        LogDomain.tasks,
        'Correction capture: saved to category ${category.id}',
        subDomain: _subDomain,
      );
    } on Exception catch (e, stackTrace) {
      _domainLogger.error(
        LogDomain.tasks,
        e,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'Correction capture: save failed',
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
    return existing.any((e) => e.before == before && e.after == after);
  }
}

/// Result of attempting to capture a correction.
enum CorrectionCaptureResult {
  /// Correction is pending and will be saved after countdown.
  pending,

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
}
