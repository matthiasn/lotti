// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_task_filters_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod controller backing the user's pinned task-filter list.
///
/// State is the ordered list of [SavedTaskFilter]s. Position in the list is
/// the sort order. Mutations write through to [SavedTaskFiltersPersistence]
/// after each operation.

@ProviderFor(SavedTaskFiltersController)
final savedTaskFiltersControllerProvider =
    SavedTaskFiltersControllerProvider._();

/// Riverpod controller backing the user's pinned task-filter list.
///
/// State is the ordered list of [SavedTaskFilter]s. Position in the list is
/// the sort order. Mutations write through to [SavedTaskFiltersPersistence]
/// after each operation.
final class SavedTaskFiltersControllerProvider
    extends
        $AsyncNotifierProvider<
          SavedTaskFiltersController,
          List<SavedTaskFilter>
        > {
  /// Riverpod controller backing the user's pinned task-filter list.
  ///
  /// State is the ordered list of [SavedTaskFilter]s. Position in the list is
  /// the sort order. Mutations write through to [SavedTaskFiltersPersistence]
  /// after each operation.
  SavedTaskFiltersControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedTaskFiltersControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedTaskFiltersControllerHash();

  @$internal
  @override
  SavedTaskFiltersController create() => SavedTaskFiltersController();
}

String _$savedTaskFiltersControllerHash() =>
    r'9b4871c872a517e08789775bd7b8a29781247592';

/// Riverpod controller backing the user's pinned task-filter list.
///
/// State is the ordered list of [SavedTaskFilter]s. Position in the list is
/// the sort order. Mutations write through to [SavedTaskFiltersPersistence]
/// after each operation.

abstract class _$SavedTaskFiltersController
    extends $AsyncNotifier<List<SavedTaskFilter>> {
  FutureOr<List<SavedTaskFilter>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<SavedTaskFilter>>, List<SavedTaskFilter>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SavedTaskFilter>>,
                List<SavedTaskFilter>
              >,
              AsyncValue<List<SavedTaskFilter>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
