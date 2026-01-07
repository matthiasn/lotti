// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_unverified_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MatrixUnverifiedController)
final matrixUnverifiedControllerProvider =
    MatrixUnverifiedControllerProvider._();

final class MatrixUnverifiedControllerProvider extends $AsyncNotifierProvider<
    MatrixUnverifiedController, List<DeviceKeys>> {
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

abstract class _$MatrixUnverifiedController
    extends $AsyncNotifier<List<DeviceKeys>> {
  FutureOr<List<DeviceKeys>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<DeviceKeys>>, List<DeviceKeys>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<DeviceKeys>>, List<DeviceKeys>>,
        AsyncValue<List<DeviceKeys>>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
