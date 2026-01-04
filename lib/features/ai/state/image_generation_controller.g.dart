// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_generation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for generating cover art images using AI.
///
/// This controller manages the state of image generation, including:
/// - Building prompts from task context and audio descriptions
/// - Calling the Gemini image generation API
/// - Managing generation state (idle, generating, success, error)

@ProviderFor(ImageGenerationController)
final imageGenerationControllerProvider = ImageGenerationControllerFamily._();

/// Controller for generating cover art images using AI.
///
/// This controller manages the state of image generation, including:
/// - Building prompts from task context and audio descriptions
/// - Calling the Gemini image generation API
/// - Managing generation state (idle, generating, success, error)
final class ImageGenerationControllerProvider
    extends $NotifierProvider<ImageGenerationController, ImageGenerationState> {
  /// Controller for generating cover art images using AI.
  ///
  /// This controller manages the state of image generation, including:
  /// - Building prompts from task context and audio descriptions
  /// - Calling the Gemini image generation API
  /// - Managing generation state (idle, generating, success, error)
  ImageGenerationControllerProvider._(
      {required ImageGenerationControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'imageGenerationControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$imageGenerationControllerHash();

  @override
  String toString() {
    return r'imageGenerationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ImageGenerationController create() => ImageGenerationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageGenerationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageGenerationState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageGenerationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageGenerationControllerHash() =>
    r'a1176ccd74663113d6afb2a942e6dec9b99db43b';

/// Controller for generating cover art images using AI.
///
/// This controller manages the state of image generation, including:
/// - Building prompts from task context and audio descriptions
/// - Calling the Gemini image generation API
/// - Managing generation state (idle, generating, success, error)

final class ImageGenerationControllerFamily extends $Family
    with
        $ClassFamilyOverride<ImageGenerationController, ImageGenerationState,
            ImageGenerationState, ImageGenerationState, String> {
  ImageGenerationControllerFamily._()
      : super(
          retry: null,
          name: r'imageGenerationControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Controller for generating cover art images using AI.
  ///
  /// This controller manages the state of image generation, including:
  /// - Building prompts from task context and audio descriptions
  /// - Calling the Gemini image generation API
  /// - Managing generation state (idle, generating, success, error)

  ImageGenerationControllerProvider call({
    required String entityId,
  }) =>
      ImageGenerationControllerProvider._(argument: entityId, from: this);

  @override
  String toString() => r'imageGenerationControllerProvider';
}

/// Controller for generating cover art images using AI.
///
/// This controller manages the state of image generation, including:
/// - Building prompts from task context and audio descriptions
/// - Calling the Gemini image generation API
/// - Managing generation state (idle, generating, success, error)

abstract class _$ImageGenerationController
    extends $Notifier<ImageGenerationState> {
  late final _$args = ref.$arg as String;
  String get entityId => _$args;

  ImageGenerationState build({
    required String entityId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImageGenerationState, ImageGenerationState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ImageGenerationState, ImageGenerationState>,
        ImageGenerationState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              entityId: _$args,
            ));
  }
}
