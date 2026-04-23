// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backfill_stats_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BackfillStatsController)
final backfillStatsControllerProvider = BackfillStatsControllerProvider._();

final class BackfillStatsControllerProvider
    extends $NotifierProvider<BackfillStatsController, BackfillStatsState> {
  BackfillStatsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backfillStatsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backfillStatsControllerHash();

  @$internal
  @override
  BackfillStatsController create() => BackfillStatsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackfillStatsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackfillStatsState>(value),
    );
  }
}

String _$backfillStatsControllerHash() =>
    r'bfb72bcff264e0fcd66b40cb857913cd92e600c0';

abstract class _$BackfillStatsController extends $Notifier<BackfillStatsState> {
  BackfillStatsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BackfillStatsState, BackfillStatsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BackfillStatsState, BackfillStatsState>,
              BackfillStatsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
