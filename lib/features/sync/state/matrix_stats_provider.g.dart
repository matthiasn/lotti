// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$matrixStatsStreamHash() => r'f65363ebb78af16342af4b7347dc68febafaf1b7';

/// See also [matrixStatsStream].
@ProviderFor(matrixStatsStream)
final matrixStatsStreamProvider =
    AutoDisposeStreamProvider<MatrixStats>.internal(
  matrixStatsStream,
  name: r'matrixStatsStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$matrixStatsStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MatrixStatsStreamRef = AutoDisposeStreamProviderRef<MatrixStats>;
String _$matrixStatsControllerHash() =>
    r'494709d34289d70c6583df085d70c6c5c59c76fb';

/// See also [MatrixStatsController].
@ProviderFor(MatrixStatsController)
final matrixStatsControllerProvider = AutoDisposeAsyncNotifierProvider<
    MatrixStatsController, MatrixStats>.internal(
  MatrixStatsController.new,
  name: r'matrixStatsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$matrixStatsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MatrixStatsController = AutoDisposeAsyncNotifier<MatrixStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
