import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_status_controller.g.dart';

/// Coarse lifecycle state of an inference run, surfaced to the UI.
enum InferenceStatus {
  idle,
  running,
  error,
}

/// Holds the [InferenceStatus] for a single (id, responseType) pair.
///
/// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
/// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
/// lost. Updated via [setStatus] by the inference runners.
@riverpod
class InferenceStatusController extends _$InferenceStatusController {
  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    ref.cacheFor(inferenceStateCacheDuration);
    return InferenceStatus.idle;
  }

  // ignore: use_setters_to_change_properties
  void setStatus(InferenceStatus status) {
    state = status;
  }
}

/// True when ANY of [responseTypes] is currently running for [id].
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.
@riverpod
class InferenceRunningController extends _$InferenceRunningController {
  @override
  bool build({
    required String id,
    required Set<AiResponseType> responseTypes,
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
