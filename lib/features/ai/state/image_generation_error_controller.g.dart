// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_generation_error_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ImageGenerationErrorController)
final imageGenerationErrorControllerProvider =
    ImageGenerationErrorControllerFamily._();

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
final class ImageGenerationErrorControllerProvider
    extends $NotifierProvider<ImageGenerationErrorController, String?> {
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
  ImageGenerationErrorControllerProvider._({
    required ImageGenerationErrorControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'imageGenerationErrorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$imageGenerationErrorControllerHash();

  @override
  String toString() {
    return r'imageGenerationErrorControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ImageGenerationErrorController create() => ImageGenerationErrorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageGenerationErrorControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageGenerationErrorControllerHash() =>
    r'969685c9d5f686ab157b2ee7f4be237e12d02db1';

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

final class ImageGenerationErrorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ImageGenerationErrorController,
          String?,
          String?,
          String?,
          String
        > {
  ImageGenerationErrorControllerFamily._()
    : super(
        retry: null,
        name: r'imageGenerationErrorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

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

  ImageGenerationErrorControllerProvider call({required String id}) =>
      ImageGenerationErrorControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'imageGenerationErrorControllerProvider';
}

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

abstract class _$ImageGenerationErrorController extends $Notifier<String?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  String? build({required String id});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(id: _$args));
  }
}
