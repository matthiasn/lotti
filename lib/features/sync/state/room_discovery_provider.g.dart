// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_discovery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RoomDiscoveryController)
final roomDiscoveryControllerProvider = RoomDiscoveryControllerProvider._();

final class RoomDiscoveryControllerProvider
    extends $NotifierProvider<RoomDiscoveryController, RoomDiscoveryState> {
  RoomDiscoveryControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'roomDiscoveryControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$roomDiscoveryControllerHash();

  @$internal
  @override
  RoomDiscoveryController create() => RoomDiscoveryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoomDiscoveryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoomDiscoveryState>(value),
    );
  }
}

String _$roomDiscoveryControllerHash() =>
    r'2c5f57a4e390ea0420847656efca879f6f12a8f1';

abstract class _$RoomDiscoveryController extends $Notifier<RoomDiscoveryState> {
  RoomDiscoveryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RoomDiscoveryState, RoomDiscoveryState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<RoomDiscoveryState, RoomDiscoveryState>,
        RoomDiscoveryState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
