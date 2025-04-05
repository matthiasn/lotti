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

@riverpod
class InferenceRunningController extends _$InferenceRunningController {
  @override
  bool build({
    required String id,
    required Set<String> responseTypes,
  }) {
    final runningStatuses = responseTypes.map((responseType) {
      final inferenceStatus = ref.watch(
        inferenceStatusControllerProvider(
          id: id,
          aiResponseType: responseType,
        ),
      );

      return inferenceStatus == InferenceStatus.running;
    });

    return runningStatuses.contains(true);
  }
}
