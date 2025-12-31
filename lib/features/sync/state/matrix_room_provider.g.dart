// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_room_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MatrixRoomController)
final matrixRoomControllerProvider = MatrixRoomControllerProvider._();

final class MatrixRoomControllerProvider
    extends $AsyncNotifierProvider<MatrixRoomController, String?> {
  MatrixRoomControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'matrixRoomControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$matrixRoomControllerHash();

  @$internal
  @override
  MatrixRoomController create() => MatrixRoomController();
}

String _$matrixRoomControllerHash() =>
    r'a7b0beef24beafaea7cf3cb58859edfd1713c07d';

abstract class _$MatrixRoomController extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<String?>, String?>,
        AsyncValue<String?>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
