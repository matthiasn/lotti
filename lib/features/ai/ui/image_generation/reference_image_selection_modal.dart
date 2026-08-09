import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the shared task-image selection flow and returns processed images.
///
/// An empty list means the task has no images or the user continued without a
/// selection. `null` means the modal was dismissed and the caller should abort.
class ReferenceImageSelectionModal {
  static Future<List<ProcessedReferenceImage>?> show({
    required BuildContext context,
    required String taskId,
    required int maxImages,
  }) {
    return ModalUtils.showSinglePageModal<List<ProcessedReferenceImage>>(
      context: context,
      builder: (modalContext) {
        void closeWith(List<ProcessedReferenceImage> images) {
          if (!modalContext.mounted) return;
          Navigator.of(modalContext).pop(images);
        }

        return ReferenceImageSelectionWidget(
          taskId: taskId,
          maxImages: maxImages,
          onContinue: closeWith,
          onSkip: () => closeWith(const <ProcessedReferenceImage>[]),
        );
      },
    );
  }
}
