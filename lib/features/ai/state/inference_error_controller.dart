import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Holds the detailed failure from the latest inference run for one entity and
/// response type.
///
/// The value is cleared when a new run starts and populated when it fails.
/// Keeping this separate from `InferenceStatus` lets compact activity widgets
/// remain driven by a small lifecycle enum while still surfacing provider HTTP
/// messages, request ids, timeouts, and other power-user diagnostics.
final NotifierProviderFamily<
  InferenceErrorController,
  String?,
  ({AiResponseType aiResponseType, String id})
>
inferenceErrorControllerProvider = NotifierProvider.autoDispose
    .family<
      InferenceErrorController,
      String?,
      ({String id, AiResponseType aiResponseType})
    >(
      InferenceErrorController.new,
      name: 'inferenceErrorControllerProvider',
    );

class InferenceErrorController extends Notifier<String?> {
  InferenceErrorController(this.providerArgs);

  final ({String id, AiResponseType aiResponseType}) providerArgs;

  @override
  String? build() {
    ref.cacheFor(inferenceStateCacheDuration);
    return null;
  }

  // ignore: use_setters_to_change_properties
  void setError(String? error) {
    state = error;
  }
}
