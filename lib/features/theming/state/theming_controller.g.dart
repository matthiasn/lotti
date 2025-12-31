// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theming_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream provider watching the tooltip enable flag from config.

@ProviderFor(enableTooltips)
final enableTooltipsProvider = EnableTooltipsProvider._();

/// Stream provider watching the tooltip enable flag from config.

final class EnableTooltipsProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Stream provider watching the tooltip enable flag from config.
  EnableTooltipsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'enableTooltipsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$enableTooltipsHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return enableTooltips(ref);
  }
}

String _$enableTooltipsHash() => r'd4ffad68f2eb7a43301add99bb014fa3fe0d2898';

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.

@ProviderFor(ThemingController)
final themingControllerProvider = ThemingControllerProvider._();

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.
final class ThemingControllerProvider
    extends $NotifierProvider<ThemingController, ThemingState> {
  /// Notifier managing the complete theming state.
  /// Marked as keepAlive since theme state should persist for the entire app lifecycle.
  ThemingControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themingControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themingControllerHash();

  @$internal
  @override
  ThemingController create() => ThemingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemingState>(value),
    );
  }
}

String _$themingControllerHash() => r'f81327e92953d43be12b831636904cab67990811';

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.

abstract class _$ThemingController extends $Notifier<ThemingState> {
  ThemingState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThemingState, ThemingState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ThemingState, ThemingState>,
        ThemingState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
