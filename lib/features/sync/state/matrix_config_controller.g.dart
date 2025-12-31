// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MatrixConfigController)
final matrixConfigControllerProvider = MatrixConfigControllerProvider._();

final class MatrixConfigControllerProvider
    extends $AsyncNotifierProvider<MatrixConfigController, MatrixConfig?> {
  MatrixConfigControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'matrixConfigControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$matrixConfigControllerHash();

  @$internal
  @override
  MatrixConfigController create() => MatrixConfigController();
}

String _$matrixConfigControllerHash() =>
    r'a091c9998b61c507f3f735ca9818c8d4a66445ea';

abstract class _$MatrixConfigController extends $AsyncNotifier<MatrixConfig?> {
  FutureOr<MatrixConfig?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MatrixConfig?>, MatrixConfig?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<MatrixConfig?>, MatrixConfig?>,
        AsyncValue<MatrixConfig?>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
