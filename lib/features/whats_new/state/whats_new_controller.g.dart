// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whats_new_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the [WhatsNewService].

@ProviderFor(whatsNewService)
final whatsNewServiceProvider = WhatsNewServiceProvider._();

/// Provider for the [WhatsNewService].

final class WhatsNewServiceProvider
    extends
        $FunctionalProvider<WhatsNewService, WhatsNewService, WhatsNewService>
    with $Provider<WhatsNewService> {
  /// Provider for the [WhatsNewService].
  WhatsNewServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whatsNewServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whatsNewServiceHash();

  @$internal
  @override
  $ProviderElement<WhatsNewService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WhatsNewService create(Ref ref) {
    return whatsNewService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WhatsNewService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WhatsNewService>(value),
    );
  }
}

String _$whatsNewServiceHash() => r'3b9088dc9154be3bed600fddce2b5b9ce55b97c0';

/// Provider that checks if the What's New modal should auto-show.
///
/// Returns true when:
/// 1. The `enable_whats_new` config flag is enabled, AND
/// 2. This is the first app launch ever OR the app version has changed, AND
/// 3. There are unseen releases to show.
///
/// Once read, this provider marks the current version as "launched"
/// so subsequent checks return false until the next version change.

@ProviderFor(shouldAutoShowWhatsNew)
final shouldAutoShowWhatsNewProvider = ShouldAutoShowWhatsNewProvider._();

/// Provider that checks if the What's New modal should auto-show.
///
/// Returns true when:
/// 1. The `enable_whats_new` config flag is enabled, AND
/// 2. This is the first app launch ever OR the app version has changed, AND
/// 3. There are unseen releases to show.
///
/// Once read, this provider marks the current version as "launched"
/// so subsequent checks return false until the next version change.

final class ShouldAutoShowWhatsNewProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider that checks if the What's New modal should auto-show.
  ///
  /// Returns true when:
  /// 1. The `enable_whats_new` config flag is enabled, AND
  /// 2. This is the first app launch ever OR the app version has changed, AND
  /// 3. There are unseen releases to show.
  ///
  /// Once read, this provider marks the current version as "launched"
  /// so subsequent checks return false until the next version change.
  ShouldAutoShowWhatsNewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shouldAutoShowWhatsNewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shouldAutoShowWhatsNewHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return shouldAutoShowWhatsNew(ref);
  }
}

String _$shouldAutoShowWhatsNewHash() =>
    r'92b8a1e042f827341790c8cf3c97c941d0b6d56e';

/// Controller for the "What's New" feature.
///
/// Manages fetching release content and tracking which releases
/// the user has seen using SharedPreferences.

@ProviderFor(WhatsNewController)
final whatsNewControllerProvider = WhatsNewControllerProvider._();

/// Controller for the "What's New" feature.
///
/// Manages fetching release content and tracking which releases
/// the user has seen using SharedPreferences.
final class WhatsNewControllerProvider
    extends $AsyncNotifierProvider<WhatsNewController, WhatsNewState> {
  /// Controller for the "What's New" feature.
  ///
  /// Manages fetching release content and tracking which releases
  /// the user has seen using SharedPreferences.
  WhatsNewControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'whatsNewControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$whatsNewControllerHash();

  @$internal
  @override
  WhatsNewController create() => WhatsNewController();
}

String _$whatsNewControllerHash() =>
    r'5f32bbc79e5b9ab93703c333614c67582d9c57d9';

/// Controller for the "What's New" feature.
///
/// Manages fetching release content and tracking which releases
/// the user has seen using SharedPreferences.

abstract class _$WhatsNewController extends $AsyncNotifier<WhatsNewState> {
  FutureOr<WhatsNewState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WhatsNewState>, WhatsNewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WhatsNewState>, WhatsNewState>,
              AsyncValue<WhatsNewState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
