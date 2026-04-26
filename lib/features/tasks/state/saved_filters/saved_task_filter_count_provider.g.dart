// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_task_filter_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Override hook so widget tests can provide a fake repository without going
/// through GetIt.

@ProviderFor(savedTaskFilterCountRepository)
final savedTaskFilterCountRepositoryProvider =
    SavedTaskFilterCountRepositoryProvider._();

/// Override hook so widget tests can provide a fake repository without going
/// through GetIt.

final class SavedTaskFilterCountRepositoryProvider
    extends
        $FunctionalProvider<
          SavedTaskFilterCountRepository,
          SavedTaskFilterCountRepository,
          SavedTaskFilterCountRepository
        >
    with $Provider<SavedTaskFilterCountRepository> {
  /// Override hook so widget tests can provide a fake repository without going
  /// through GetIt.
  SavedTaskFilterCountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedTaskFilterCountRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedTaskFilterCountRepositoryHash();

  @$internal
  @override
  $ProviderElement<SavedTaskFilterCountRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SavedTaskFilterCountRepository create(Ref ref) {
    return savedTaskFilterCountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedTaskFilterCountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedTaskFilterCountRepository>(
        value,
      ),
    );
  }
}

String _$savedTaskFilterCountRepositoryHash() =>
    r'0e7df05e8549069ba1778e04297051027703217a';

/// Live `{savedFilterId → matching task count}` for every persisted saved
/// filter, recomputed when the filter list changes or when a task-shaped
/// notification arrives.
///
/// `UpdateNotifications.updateStream` multiplexes both locally-originated
/// notifications and sync-originated ones (the latter are debounced by
/// `UpdateNotifications` and flushed onto the same controller), so counts
/// stay in sync when tasks arrive from another device.

@ProviderFor(savedTaskFilterCounts)
final savedTaskFilterCountsProvider = SavedTaskFilterCountsProvider._();

/// Live `{savedFilterId → matching task count}` for every persisted saved
/// filter, recomputed when the filter list changes or when a task-shaped
/// notification arrives.
///
/// `UpdateNotifications.updateStream` multiplexes both locally-originated
/// notifications and sync-originated ones (the latter are debounced by
/// `UpdateNotifications` and flushed onto the same controller), so counts
/// stay in sync when tasks arrive from another device.

final class SavedTaskFilterCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          FutureOr<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $FutureProvider<Map<String, int>> {
  /// Live `{savedFilterId → matching task count}` for every persisted saved
  /// filter, recomputed when the filter list changes or when a task-shaped
  /// notification arrives.
  ///
  /// `UpdateNotifications.updateStream` multiplexes both locally-originated
  /// notifications and sync-originated ones (the latter are debounced by
  /// `UpdateNotifications` and flushed onto the same controller), so counts
  /// stay in sync when tasks arrive from another device.
  SavedTaskFilterCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedTaskFilterCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedTaskFilterCountsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, int>> create(Ref ref) {
    return savedTaskFilterCounts(ref);
  }
}

String _$savedTaskFilterCountsHash() =>
    r'5587d162360a3b03b6d45ef9a508febbbb77fd52';

/// Convenience family — reads a single saved filter's count from the
/// aggregated map. Returns 0 when the id no longer resolves (concurrent
/// delete) so the sidebar doesn't show a stale number.

@ProviderFor(savedTaskFilterCount)
final savedTaskFilterCountProvider = SavedTaskFilterCountFamily._();

/// Convenience family — reads a single saved filter's count from the
/// aggregated map. Returns 0 when the id no longer resolves (concurrent
/// delete) so the sidebar doesn't show a stale number.

final class SavedTaskFilterCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Convenience family — reads a single saved filter's count from the
  /// aggregated map. Returns 0 when the id no longer resolves (concurrent
  /// delete) so the sidebar doesn't show a stale number.
  SavedTaskFilterCountProvider._({
    required SavedTaskFilterCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'savedTaskFilterCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$savedTaskFilterCountHash();

  @override
  String toString() {
    return r'savedTaskFilterCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return savedTaskFilterCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedTaskFilterCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$savedTaskFilterCountHash() =>
    r'664ed3fc4c878ca9b41cce182db4d41f3d49f52a';

/// Convenience family — reads a single saved filter's count from the
/// aggregated map. Returns 0 when the id no longer resolves (concurrent
/// delete) so the sidebar doesn't show a stale number.

final class SavedTaskFilterCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  SavedTaskFilterCountFamily._()
    : super(
        retry: null,
        name: r'savedTaskFilterCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Convenience family — reads a single saved filter's count from the
  /// aggregated map. Returns 0 when the id no longer resolves (concurrent
  /// delete) so the sidebar doesn't show a stale number.

  SavedTaskFilterCountProvider call(String savedFilterId) =>
      SavedTaskFilterCountProvider._(argument: savedFilterId, from: this);

  @override
  String toString() => r'savedTaskFilterCountProvider';
}
