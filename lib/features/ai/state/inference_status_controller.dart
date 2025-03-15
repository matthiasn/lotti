import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_status_controller.g.dart';

enum InferenceStatus {
  idle,
  running,
  error,
}

@riverpod
class InferenceStatusController extends _$InferenceStatusController {
  @override
  InferenceStatus build({
    required String id,
    required String aiResponseType,
  }) {
    ref.cacheFor(inferenceStateCacheDuration);
    return InferenceStatus.idle;
  }

  // ignore: use_setters_to_change_properties
  void setStatus(InferenceStatus status) {
    state = status;
  }
}
