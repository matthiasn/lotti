// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_refresh_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that handles task summary refresh operations for checklists
/// This centralizes the logic that was duplicated across repositories

@ProviderFor(taskSummaryRefreshService)
final taskSummaryRefreshServiceProvider = TaskSummaryRefreshServiceProvider._();

/// Service that handles task summary refresh operations for checklists
/// This centralizes the logic that was duplicated across repositories

final class TaskSummaryRefreshServiceProvider extends $FunctionalProvider<
    TaskSummaryRefreshService,
    TaskSummaryRefreshService,
    TaskSummaryRefreshService> with $Provider<TaskSummaryRefreshService> {
  /// Service that handles task summary refresh operations for checklists
  /// This centralizes the logic that was duplicated across repositories
  TaskSummaryRefreshServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskSummaryRefreshServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$taskSummaryRefreshServiceHash();

  @$internal
  @override
  $ProviderElement<TaskSummaryRefreshService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TaskSummaryRefreshService create(Ref ref) {
    return taskSummaryRefreshService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskSummaryRefreshService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskSummaryRefreshService>(value),
    );
  }
}

String _$taskSummaryRefreshServiceHash() =>
    r'f097049182868be70e2798b084bab2cca69a9f21';
