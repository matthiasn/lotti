import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/utils/cache_extension.dart';

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
final NotifierProviderFamily<ImageGenerationErrorController, String?, String>
imageGenerationErrorControllerProvider = NotifierProvider.autoDispose
    .family<ImageGenerationErrorController, String?, String>(
      ImageGenerationErrorController.new,
      name: 'imageGenerationErrorControllerProvider',
    );

class ImageGenerationErrorController extends Notifier<String?> {
  ImageGenerationErrorController(this.id);

  final String id;

  @override
  String? build() {
    ref.cacheFor(inferenceStateCacheDuration);
    return null;
  }

  // ignore: use_setters_to_change_properties
  void setError(String? providerReason) {
    state = providerReason;
  }
}
