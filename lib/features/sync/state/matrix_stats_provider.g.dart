// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matrix_stats_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Streams live message-count [MatrixStats] from the Matrix service for the
/// stats UI.

@ProviderFor(matrixStatsStream)
final matrixStatsStreamProvider = MatrixStatsStreamProvider._();

/// Streams live message-count [MatrixStats] from the Matrix service for the
/// stats UI.

final class MatrixStatsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<MatrixStats>,
          MatrixStats,
          Stream<MatrixStats>
        >
    with $FutureModifier<MatrixStats>, $StreamProvider<MatrixStats> {
  /// Streams live message-count [MatrixStats] from the Matrix service for the
  /// stats UI.
  MatrixStatsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matrixStatsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matrixStatsStreamHash();

  @$internal
  @override
  $StreamProviderElement<MatrixStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MatrixStats> create(Ref ref) {
    return matrixStatsStream(ref);
  }
}

String _$matrixStatsStreamHash() => r'f65363ebb78af16342af4b7347dc68febafaf1b7';

/// Exposes the latest [MatrixStats], seeded from the service's current counts
/// and then kept live by [matrixStatsStream].

@ProviderFor(MatrixStatsController)
final matrixStatsControllerProvider = MatrixStatsControllerProvider._();

/// Exposes the latest [MatrixStats], seeded from the service's current counts
/// and then kept live by [matrixStatsStream].
final class MatrixStatsControllerProvider
    extends $AsyncNotifierProvider<MatrixStatsController, MatrixStats> {
  /// Exposes the latest [MatrixStats], seeded from the service's current counts
  /// and then kept live by [matrixStatsStream].
  MatrixStatsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matrixStatsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matrixStatsControllerHash();

  @$internal
  @override
  MatrixStatsController create() => MatrixStatsController();
}

String _$matrixStatsControllerHash() =>
    r'494709d34289d70c6583df085d70c6c5c59c76fb';

/// Exposes the latest [MatrixStats], seeded from the service's current counts
/// and then kept live by [matrixStatsStream].

abstract class _$MatrixStatsController extends $AsyncNotifier<MatrixStats> {
  FutureOr<MatrixStats> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MatrixStats>, MatrixStats>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MatrixStats>, MatrixStats>,
              AsyncValue<MatrixStats>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Rolling in-memory history for a few KPI metrics to power sparklines.
/// Kept UI-side to avoid coupling to the pipeline internals.

@ProviderFor(SyncMetricsHistory)
final syncMetricsHistoryProvider = SyncMetricsHistoryProvider._();

/// Rolling in-memory history for a few KPI metrics to power sparklines.
/// Kept UI-side to avoid coupling to the pipeline internals.
final class SyncMetricsHistoryProvider
    extends $NotifierProvider<SyncMetricsHistory, Map<String, List<int>>> {
  /// Rolling in-memory history for a few KPI metrics to power sparklines.
  /// Kept UI-side to avoid coupling to the pipeline internals.
  SyncMetricsHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncMetricsHistoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncMetricsHistoryHash();

  @$internal
  @override
  SyncMetricsHistory create() => SyncMetricsHistory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, List<int>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, List<int>>>(value),
    );
  }
}

String _$syncMetricsHistoryHash() =>
    r'50726338f9d9edc7d5a347f3122a2fdf1d9acb22';

/// Rolling in-memory history for a few KPI metrics to power sparklines.
/// Kept UI-side to avoid coupling to the pipeline internals.

abstract class _$SyncMetricsHistory extends $Notifier<Map<String, List<int>>> {
  Map<String, List<int>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<Map<String, List<int>>, Map<String, List<int>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, List<int>>, Map<String, List<int>>>,
              Map<String, List<int>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
