// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskSummaryRepository)
final taskSummaryRepositoryProvider = TaskSummaryRepositoryProvider._();

final class TaskSummaryRepositoryProvider
    extends
        $FunctionalProvider<
          TaskSummaryRepository,
          TaskSummaryRepository,
          TaskSummaryRepository
        >
    with $Provider<TaskSummaryRepository> {
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
