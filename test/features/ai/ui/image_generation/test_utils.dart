import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';

/// Configurable fake for [ReferenceImageSelectionController]: serves a fixed
/// state, records `toggleImageSelection`/`clearSelection` calls, and returns
/// [processedImages] from `processSelectedImages`.
class FakeReferenceImageSelectionController
    extends ReferenceImageSelectionController {
  FakeReferenceImageSelectionController(
    this._fixedState, {
    this.processedImages = const [],
  });

  final ReferenceImageSelectionState _fixedState;
  final List<ProcessedReferenceImage> processedImages;

  /// Every image id passed to [toggleImageSelection], in call order.
  final List<String> toggledImageIds = [];

  /// Number of [clearSelection] invocations.
  int clearSelectionCalls = 0;

  @override
  ReferenceImageSelectionState build({required String taskId}) => _fixedState;

  @override
  void toggleImageSelection(String imageId) {
    toggledImageIds.add(imageId);
  }

  @override
  void clearSelection() {
    clearSelectionCalls++;
  }

  @override
  Future<List<ProcessedReferenceImage>> processSelectedImages() async {
    return processedImages;
  }
}
