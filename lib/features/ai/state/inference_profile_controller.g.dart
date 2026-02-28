// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams all inference profiles for the profile management UI.

@ProviderFor(InferenceProfileController)
final inferenceProfileControllerProvider =
    InferenceProfileControllerProvider._();

/// Streams all inference profiles for the profile management UI.
final class InferenceProfileControllerProvider extends $StreamNotifierProvider<
    InferenceProfileController, List<AiConfig>> {
  /// Streams all inference profiles for the profile management UI.
  InferenceProfileControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'inferenceProfileControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$inferenceProfileControllerHash();

  @$internal
  @override
  InferenceProfileController create() => InferenceProfileController();
}

String _$inferenceProfileControllerHash() =>
    r'34611306f9f61d6e395b486a4765ccf8f4c8e518';

/// Streams all inference profiles for the profile management UI.

abstract class _$InferenceProfileController
    extends $StreamNotifier<List<AiConfig>> {
  Stream<List<AiConfig>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<AiConfig>>, List<AiConfig>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<AiConfig>>, List<AiConfig>>,
        AsyncValue<List<AiConfig>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
