// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_scale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BarWidthController)
final barWidthControllerProvider = BarWidthControllerProvider._();

final class BarWidthControllerProvider
    extends $NotifierProvider<BarWidthController, double> {
  BarWidthControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'barWidthControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$barWidthControllerHash();

  @$internal
  @override
  BarWidthController create() => BarWidthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$barWidthControllerHash() =>
    r'1f0d03f0671b76de97cc89a7a6bb81cc3f335482';

abstract class _$BarWidthController extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<double, double>, double, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
