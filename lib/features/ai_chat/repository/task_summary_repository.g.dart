// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [TaskSummaryRepository], wiring in the journal DB and a
/// [TaskSummaryResolver] backed by the agent database when one is registered
/// (the resolver prefers agent reports, falling back to legacy summaries).

@ProviderFor(taskSummaryRepository)
final taskSummaryRepositoryProvider = TaskSummaryRepositoryProvider._();

/// Provides the [TaskSummaryRepository], wiring in the journal DB and a
/// [TaskSummaryResolver] backed by the agent database when one is registered
/// (the resolver prefers agent reports, falling back to legacy summaries).

final class TaskSummaryRepositoryProvider
    extends
        $FunctionalProvider<
          TaskSummaryRepository,
          TaskSummaryRepository,
          TaskSummaryRepository
        >
    with $Provider<TaskSummaryRepository> {
  /// Provides the [TaskSummaryRepository], wiring in the journal DB and a
  /// [TaskSummaryResolver] backed by the agent database when one is registered
  /// (the resolver prefers agent reports, falling back to legacy summaries).
  TaskSummaryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSummaryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSummaryRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskSummaryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TaskSummaryRepository create(Ref ref) {
    return taskSummaryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSummaryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSummaryRepository>(value),
    );
  }
}

String _$taskSummaryRepositoryHash() =>
    r'cc24e3cf1f46f2390ae59378d940127075e7d99d';
