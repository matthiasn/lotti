// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zoom_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ZoomController)
final zoomControllerProvider = ZoomControllerProvider._();

final class ZoomControllerProvider
    extends $NotifierProvider<ZoomController, double> {
  ZoomControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoomControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoomControllerHash();

  @$internal
  @override
  ZoomController create() => ZoomController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$zoomControllerHash() => r'8b52f573b8a10aed0a1c6e31b1f0b45c0103ab17';

abstract class _$ZoomController extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
