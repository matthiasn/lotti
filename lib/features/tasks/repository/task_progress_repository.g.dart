// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_progress_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskProgressRepository)
final taskProgressRepositoryProvider = TaskProgressRepositoryProvider._();

final class TaskProgressRepositoryProvider extends $FunctionalProvider<
    TaskProgressRepository,
    TaskProgressRepository,
    TaskProgressRepository> with $Provider<TaskProgressRepository> {
  TaskProgressRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskProgressRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskProgressRepositoryHash();

  @$internal
  @override
  $ProviderElement<TaskProgressRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskProgressRepository create(Ref ref) {
    return taskProgressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskProgressRepository>(value),
    );
  }
}

String _$taskProgressRepositoryHash() =>
    r'61ac7e56fee89c67777d4898e7b65a716a7c725d';
