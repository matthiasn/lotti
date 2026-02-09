// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rating_prompt_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls when the rating modal should be shown.
///
/// Holds the target entry ID that should be rated, or null when no
/// rating is pending. The UI layer listens to this and shows the
/// modal when it becomes non-null.

@ProviderFor(RatingPromptController)
final ratingPromptControllerProvider = RatingPromptControllerProvider._();

/// Controls when the rating modal should be shown.
///
/// Holds the target entry ID that should be rated, or null when no
/// rating is pending. The UI layer listens to this and shows the
/// modal when it becomes non-null.
final class RatingPromptControllerProvider
    extends $NotifierProvider<RatingPromptController, String?> {
  /// Controls when the rating modal should be shown.
  ///
  /// Holds the target entry ID that should be rated, or null when no
  /// rating is pending. The UI layer listens to this and shows the
  /// modal when it becomes non-null.
  RatingPromptControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'ratingPromptControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$ratingPromptControllerHash();

  @$internal
  @override
  RatingPromptController create() => RatingPromptController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$ratingPromptControllerHash() =>
    r'af45b51088fd457dff96fbcbeb905930a00f7209';

/// Controls when the rating modal should be shown.
///
/// Holds the target entry ID that should be rated, or null when no
/// rating is pending. The UI layer listens to this and shows the
/// modal when it becomes non-null.

abstract class _$RatingPromptController extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String?, String?>, String?, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
