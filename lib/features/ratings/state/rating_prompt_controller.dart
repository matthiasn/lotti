import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_prompt_controller.g.dart';

/// A pending rating request containing the target entity ID and catalog.
typedef RatingPrompt = ({String targetId, String catalogId});

/// Controls when the rating modal should be shown.
///
/// Holds the target entry ID and catalog ID that should be rated,
/// or null when no rating is pending. The UI layer listens to this
/// and shows the modal when it becomes non-null.
@riverpod
class RatingPromptController extends _$RatingPromptController {
  @override
  RatingPrompt? build() => null;

  /// Requests a rating for the given [targetId] with [catalogId].
  void requestRating({
    required String targetId,
    String catalogId = 'session',
  }) =>
      state = (targetId: targetId, catalogId: catalogId);

  void dismiss() => state = null;
}
