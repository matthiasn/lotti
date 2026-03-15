import 'dart:developer' as developer;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reference_image_selection_controller.freezed.dart';
part 'reference_image_selection_controller.g.dart';

/// Error codes for reference image selection operations.
/// These codes should be mapped to localized strings in the widget layer.
enum ReferenceImageSelectionError {
  /// Failed to load linked images for the task.
  loadImagesFailed,
}

@freezed
sealed class ReferenceImageSelectionState with _$ReferenceImageSelectionState {
  const factory ReferenceImageSelectionState({
    @Default([]) List<JournalImage> availableImages,
    @Default({}) Set<String> selectedImageIds,
    @Default({}) Set<String> linkedTaskImageIds,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,

    /// Error code for display (to be localized by the widget layer).
    ReferenceImageSelectionError? errorCode,

    /// Raw error details for logging/debugging (not for display).
    String? errorDetail,
  }) = _ReferenceImageSelectionState;
}

/// Extension to add computed getters to [ReferenceImageSelectionState].
extension ReferenceImageSelectionStateX on ReferenceImageSelectionState {
  bool get canSelectMore => selectedImageIds.length < kMaxReferenceImages;
  int get selectionCount => selectedImageIds.length;
}

@riverpod
class ReferenceImageSelectionController
    extends _$ReferenceImageSelectionController {
  @override
  ReferenceImageSelectionState build({required String taskId}) {
    _loadAvailableImages();
    return const ReferenceImageSelectionState(isLoading: true);
  }

  Future<void> _loadAvailableImages() async {
    try {
      final journalRepository = ref.read(journalRepositoryProvider);

      // 1. Directly linked images (existing behavior).
      final directImages = await journalRepository.getLinkedImagesForTask(
        taskId,
      );

      if (!ref.mounted) return;

      // 2. Cover art from linked tasks.
      final linkedTaskCoverArt = await _fetchLinkedTaskCoverArt(
        journalRepository,
      );

      if (!ref.mounted) return;

      // 3. Deduplicate (a directly linked image might also be a linked
      // task's cover art).
      final directIds = directImages.map((img) => img.meta.id).toSet();
      final seen = <String>{};
      final combined = <JournalImage>[];
      final linkedIds = <String>{};
      for (final img in [...directImages, ...linkedTaskCoverArt]) {
        if (seen.add(img.meta.id)) {
          combined.add(img);
          // Mark as linked-task image only if it wasn't directly linked.
          if (!directIds.contains(img.meta.id)) {
            linkedIds.add(img.meta.id);
          }
        }
      }

      state = state.copyWith(
        availableImages: combined,
        linkedTaskImageIds: linkedIds,
        isLoading: false,
      );
    } catch (e) {
      developer.log(
        'Failed to load images for task $taskId: $e',
        name: 'ReferenceImageSelectionController',
        error: e,
      );

      // Only update state if still mounted
      if (!ref.mounted) return;

      state = state.copyWith(
        isLoading: false,
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
        errorDetail: e.toString(),
      );
    }
  }

  /// Fetches cover art images from tasks linked to this task (both
  /// directions: outgoing and incoming links).
  Future<List<JournalImage>> _fetchLinkedTaskCoverArt(
    JournalRepository journalRepository,
  ) async {
    final coverArtImages = <JournalImage>[];

    try {
      // Get outgoing links (this task → other entities)
      final outgoingLinks = await journalRepository.getLinksFromId(taskId);
      // Get incoming links (other entities → this task)
      final incomingLinks = await journalRepository.getLinkedToEntities(
        linkedTo: taskId,
      );

      if (!ref.mounted) return coverArtImages;

      // Collect unique linked entity IDs
      final linkedEntityIds = <String>{
        ...outgoingLinks.map((link) => link.toId),
        ...incomingLinks.map((entity) => entity.id),
      };

      // For each linked entity that is a Task with cover art, fetch the image.
      for (final entityId in linkedEntityIds) {
        if (!ref.mounted) return coverArtImages;

        final entity = await journalRepository.getJournalEntityById(entityId);
        if (entity is Task && entity.data.coverArtId != null) {
          final coverArtImage = await journalRepository.getJournalEntityById(
            entity.data.coverArtId!,
          );
          if (coverArtImage is JournalImage) {
            coverArtImages.add(coverArtImage);
          }
        }
      }
    } catch (e) {
      developer.log(
        'Failed to fetch linked task cover art for $taskId: $e',
        name: 'ReferenceImageSelectionController',
        error: e,
      );
      // Non-fatal: return whatever we collected so far.
    }

    return coverArtImages;
  }

  void toggleImageSelection(String imageId) {
    final current = Set<String>.from(state.selectedImageIds);

    if (current.contains(imageId)) {
      current.remove(imageId);
    } else if (current.length < kMaxReferenceImages) {
      current.add(imageId);
    }

    state = state.copyWith(selectedImageIds: current);
  }

  void clearSelection() {
    state = state.copyWith(selectedImageIds: {});
  }

  /// Processes selected images and returns them ready for API submission.
  ///
  /// If an individual image fails to process (e.g., file not found, corrupt),
  /// it is skipped and processing continues with the remaining images.
  /// Returns partial results if the controller is unmounted during processing.
  Future<List<ProcessedReferenceImage>> processSelectedImages() async {
    state = state.copyWith(isProcessing: true);

    final results = <ProcessedReferenceImage>[];

    // Build a map for O(1) lookups instead of O(N) firstWhere in loop
    final imageById = {
      for (final img in state.availableImages) img.meta.id: img,
    };

    for (final imageId in state.selectedImageIds) {
      final image = imageById[imageId];
      if (image == null) {
        developer.log(
          'Selected image not found in available images: $imageId, skipping',
          name: 'ReferenceImageSelectionController',
        );
        continue;
      }

      final filePath = getFullImagePath(image);
      final processed = await processReferenceImage(
        filePath: filePath,
        imageId: imageId,
      );

      // Check if still mounted after async operation
      if (!ref.mounted) return results;

      if (processed != null) {
        results.add(processed);
      }
    }

    // Only update state if still mounted
    if (ref.mounted) {
      state = state.copyWith(isProcessing: false);
    }
    return results;
  }
}
