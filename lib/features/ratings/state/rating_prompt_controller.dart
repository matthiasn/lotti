import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rating_prompt_controller.g.dart';

/// Controls when the rating modal should be shown.
///
/// Holds the target entry ID that should be rated, or null when no
/// rating is pending. The UI layer listens to this and shows the
/// modal when it becomes non-null.
@riverpod
class RatingPromptController extends _$RatingPromptController {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void requestRating(String targetId) => state = targetId;
  void dismiss() => state = null;
}
