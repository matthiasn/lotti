// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provisioning_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProvisioningController)
final provisioningControllerProvider = ProvisioningControllerProvider._();

final class ProvisioningControllerProvider
    extends $NotifierProvider<ProvisioningController, ProvisioningState> {
  ProvisioningControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'provisioningControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$provisioningControllerHash();

  @$internal
  @override
  ProvisioningController create() => ProvisioningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProvisioningState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProvisioningState>(value),
    );
  }
}

String _$provisioningControllerHash() =>
    r'14c005a63a7d80a9424bb92c55f2b8c12f585d0a';

abstract class _$ProvisioningController extends $Notifier<ProvisioningState> {
  ProvisioningState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ProvisioningState, ProvisioningState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ProvisioningState, ProvisioningState>,
        ProvisioningState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
