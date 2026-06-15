import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_generation_error_controller.g.dart';

/// Holds the provider's *verbatim* failure reason for an entity/task id (e.g. a
/// Gemini `finishReason` like `PROHIBITED_CONTENT`) so the cover-art UI can show
/// the actual reason the provider returned, framed by a localized "rejected"
/// message — never an invented description.
///
/// Keyed by id exactly like `InferenceStatusController`, and driven by
/// `SkillInferenceRunner.runImageGeneration`: cleared to `null` when a run
/// starts and populated when a run fails with a provider reason. `null` means
/// "no provider reason" (e.g. a network error), so the UI falls back to a
/// generic failure message.
@riverpod
class ImageGenerationErrorController extends _$ImageGenerationErrorController {
  @override
  String? build({required String id}) {
    ref.cacheFor(inferenceStateCacheDuration);
    return null;
  }

  // ignore: use_setters_to_change_properties
  void setError(String? providerReason) {
    state = providerReason;
  }
}
