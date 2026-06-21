// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_unverified_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the current set of unverified Matrix devices for the
/// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.

@ProviderFor(MatrixUnverifiedController)
final matrixUnverifiedControllerProvider =
    MatrixUnverifiedControllerProvider._();

/// Exposes the current set of unverified Matrix devices for the
/// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.
final class MatrixUnverifiedControllerProvider
    extends
        $AsyncNotifierProvider<MatrixUnverifiedController, List<DeviceKeys>> {
  /// Exposes the current set of unverified Matrix devices for the
  /// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.
  MatrixUnverifiedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matrixUnverifiedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matrixUnverifiedControllerHash();

  @$internal
  @override
  MatrixUnverifiedController create() => MatrixUnverifiedController();
}

String _$matrixUnverifiedControllerHash() =>
    r'da543420f439121a16e51f4992934379143e27d5';

/// Exposes the current set of unverified Matrix devices for the
/// device-verification UI, sourced from `MatrixService.getUnverifiedDevices`.

abstract class _$MatrixUnverifiedController
    extends $AsyncNotifier<List<DeviceKeys>> {
  FutureOr<List<DeviceKeys>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<DeviceKeys>>, List<DeviceKeys>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<DeviceKeys>>, List<DeviceKeys>>,
              AsyncValue<List<DeviceKeys>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
