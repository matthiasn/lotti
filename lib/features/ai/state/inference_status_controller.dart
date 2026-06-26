import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/cache_extension.dart';

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
/// lost. Updated via setStatus by the inference runners.
final NotifierProviderFamily<
  InferenceStatusController,
  InferenceStatus,
  ({AiResponseType aiResponseType, String id})
>
inferenceStatusControllerProvider = NotifierProvider.autoDispose
    .family<
      InferenceStatusController,
      InferenceStatus,
      ({String id, AiResponseType aiResponseType})
    >(
      InferenceStatusController.new,
      name: 'inferenceStatusControllerProvider',
    );

class InferenceStatusController extends Notifier<InferenceStatus> {
  InferenceStatusController([
    this._providerArgs = (
      id: '',
      aiResponseType: AiResponseType.imageAnalysis,
    ),
  ]);

  final ({String id, AiResponseType aiResponseType}) _providerArgs;
  String get id => _providerArgs.id;
  AiResponseType get aiResponseType => _providerArgs.aiResponseType;

  @override
  InferenceStatus build() {
    ref.cacheFor(inferenceStateCacheDuration);
    return InferenceStatus.idle;
  }

  // ignore: use_setters_to_change_properties
  void setStatus(InferenceStatus status) {
    state = status;
  }
}

/// True when ANY of responseTypes is currently running for id.
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.
final NotifierProviderFamily<
  InferenceRunningController,
  bool,
  ({String id, Set<AiResponseType> responseTypes})
>
inferenceRunningControllerProvider = NotifierProvider.autoDispose
    .family<
      InferenceRunningController,
      bool,
      ({String id, Set<AiResponseType> responseTypes})
    >(
      InferenceRunningController.new,
      name: 'inferenceRunningControllerProvider',
    );

class InferenceRunningController extends Notifier<bool> {
  InferenceRunningController(this._providerArgs);

  final ({String id, Set<AiResponseType> responseTypes}) _providerArgs;
  String get id => _providerArgs.id;
  Set<AiResponseType> get responseTypes => _providerArgs.responseTypes;

  @override
  bool build() {
    final runningStatuses = responseTypes.map((responseType) {
      final inferenceStatus = ref.watch(
        inferenceStatusControllerProvider((
          id: id,
          aiResponseType: responseType,
        )),
      );

      return inferenceStatus == InferenceStatus.running;
    });

    return runningStatuses.contains(true);
  }
}
