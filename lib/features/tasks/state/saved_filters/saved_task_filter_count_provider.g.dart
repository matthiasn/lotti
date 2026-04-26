// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_task_filter_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Override hook so widget tests can provide a [SavedTaskFilterCountRepository]
/// without going through GetIt. Production reads the live one from GetIt at
/// build time.

@ProviderFor(savedTaskFilterCountRepository)
final savedTaskFilterCountRepositoryProvider =
    SavedTaskFilterCountRepositoryProvider._();

/// Override hook so widget tests can provide a [SavedTaskFilterCountRepository]
/// without going through GetIt. Production reads the live one from GetIt at
/// build time.

final class SavedTaskFilterCountRepositoryProvider
    extends
        $FunctionalProvider<
          SavedTaskFilterCountRepository,
          SavedTaskFilterCountRepository,
          SavedTaskFilterCountRepository
        >
    with $Provider<SavedTaskFilterCountRepository> {
  /// Override hook so widget tests can provide a [SavedTaskFilterCountRepository]
  /// without going through GetIt. Production reads the live one from GetIt at
  /// build time.
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
    r'df8528f6e6e159cc103f77d2aee7dc9b2182522f';

/// Live count of tasks matching the saved filter with [savedFilterId].
///
/// Resolves the saved filter from [savedTaskFiltersControllerProvider],
/// delegates the count to [SavedTaskFilterCountRepository], and invalidates
/// itself whenever a task-shaped change is broadcast on
/// [UpdateNotifications.updateStream]. Returns 0 when the saved id no longer
/// resolves (concurrent delete) so the sidebar doesn't show a stale number.

@ProviderFor(savedTaskFilterCount)
final savedTaskFilterCountProvider = SavedTaskFilterCountFamily._();

/// Live count of tasks matching the saved filter with [savedFilterId].
///
/// Resolves the saved filter from [savedTaskFiltersControllerProvider],
/// delegates the count to [SavedTaskFilterCountRepository], and invalidates
/// itself whenever a task-shaped change is broadcast on
/// [UpdateNotifications.updateStream]. Returns 0 when the saved id no longer
/// resolves (concurrent delete) so the sidebar doesn't show a stale number.

final class SavedTaskFilterCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Live count of tasks matching the saved filter with [savedFilterId].
  ///
  /// Resolves the saved filter from [savedTaskFiltersControllerProvider],
  /// delegates the count to [SavedTaskFilterCountRepository], and invalidates
  /// itself whenever a task-shaped change is broadcast on
  /// [UpdateNotifications.updateStream]. Returns 0 when the saved id no longer
  /// resolves (concurrent delete) so the sidebar doesn't show a stale number.
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
    r'f2298f1e85bca36edaf4d0bb3826274062289c43';

/// Live count of tasks matching the saved filter with [savedFilterId].
///
/// Resolves the saved filter from [savedTaskFiltersControllerProvider],
/// delegates the count to [SavedTaskFilterCountRepository], and invalidates
/// itself whenever a task-shaped change is broadcast on
/// [UpdateNotifications.updateStream]. Returns 0 when the saved id no longer
/// resolves (concurrent delete) so the sidebar doesn't show a stale number.

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

  /// Live count of tasks matching the saved filter with [savedFilterId].
  ///
  /// Resolves the saved filter from [savedTaskFiltersControllerProvider],
  /// delegates the count to [SavedTaskFilterCountRepository], and invalidates
  /// itself whenever a task-shaped change is broadcast on
  /// [UpdateNotifications.updateStream]. Returns 0 when the saved id no longer
  /// resolves (concurrent delete) so the sidebar doesn't show a stale number.

  SavedTaskFilterCountProvider call(String savedFilterId) =>
      SavedTaskFilterCountProvider._(argument: savedFilterId, from: this);

  @override
  String toString() => r'savedTaskFilterCountProvider';
}
