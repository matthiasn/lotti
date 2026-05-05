// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_task_filter_activator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// id of the saved filter whose persisted shape matches the live tasks-page
/// filter, or null when no saved filter matches.

@ProviderFor(currentSavedTaskFilterId)
final currentSavedTaskFilterIdProvider = CurrentSavedTaskFilterIdProvider._();

/// id of the saved filter whose persisted shape matches the live tasks-page
/// filter, or null when no saved filter matches.

final class CurrentSavedTaskFilterIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// id of the saved filter whose persisted shape matches the live tasks-page
  /// filter, or null when no saved filter matches.
  CurrentSavedTaskFilterIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSavedTaskFilterIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSavedTaskFilterIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentSavedTaskFilterId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentSavedTaskFilterIdHash() =>
    r'00920e878c33b99fac210d31d1f942916a3d2dae';

/// True when the live filter has clauses that don't match any saved filter
/// — the sidebar `+` and the modal Save button use this to decide whether
/// they're enabled.

@ProviderFor(tasksFilterHasUnsavedClauses)
final tasksFilterHasUnsavedClausesProvider =
    TasksFilterHasUnsavedClausesProvider._();

/// True when the live filter has clauses that don't match any saved filter
/// — the sidebar `+` and the modal Save button use this to decide whether
/// they're enabled.

final class TasksFilterHasUnsavedClausesProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True when the live filter has clauses that don't match any saved filter
  /// — the sidebar `+` and the modal Save button use this to decide whether
  /// they're enabled.
  TasksFilterHasUnsavedClausesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksFilterHasUnsavedClausesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksFilterHasUnsavedClausesHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return tasksFilterHasUnsavedClauses(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$tasksFilterHasUnsavedClausesHash() =>
    r'fb0290d76c1b5ebf734e036790c899e6981813a8';
