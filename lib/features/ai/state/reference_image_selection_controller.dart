import 'dart:developer' as developer;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reference_image_selection_controller.freezed.dart';
part 'reference_image_selection_controller.g.dart';

@freezed
sealed class ReferenceImageSelectionState with _$ReferenceImageSelectionState {
  const factory ReferenceImageSelectionState({
    @Default([]) List<JournalImage> availableImages,
    @Default({}) Set<String> selectedImageIds,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,
    String? errorMessage,
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
      final images = await journalRepository.getLinkedImagesForTask(taskId);

      // Check if still mounted after async operation
      if (!ref.mounted) return;

      state = state.copyWith(
        availableImages: images,
        isLoading: false,
      );
    } catch (e) {
      // Only update state if still mounted
      if (!ref.mounted) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load images: $e',
      );
    }
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
