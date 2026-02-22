// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_summary_refresh_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service that handles task summary refresh operations for checklists.
///
/// Must be `keepAlive` because it is used by keepAlive repositories
/// (ChecklistRepository, JournalRepository). An auto-disposed provider's
/// Ref becomes invalid once no listeners remain, causing "Cannot use Ref
/// after disposed" errors when the repository calls back into this service
/// asynchronously.

@ProviderFor(taskSummaryRefreshService)
final taskSummaryRefreshServiceProvider = TaskSummaryRefreshServiceProvider._();

/// Service that handles task summary refresh operations for checklists.
///
/// Must be `keepAlive` because it is used by keepAlive repositories
/// (ChecklistRepository, JournalRepository). An auto-disposed provider's
/// Ref becomes invalid once no listeners remain, causing "Cannot use Ref
/// after disposed" errors when the repository calls back into this service
/// asynchronously.

final class TaskSummaryRefreshServiceProvider extends $FunctionalProvider<
    TaskSummaryRefreshService,
    TaskSummaryRefreshService,
    TaskSummaryRefreshService> with $Provider<TaskSummaryRefreshService> {
  /// Service that handles task summary refresh operations for checklists.
  ///
  /// Must be `keepAlive` because it is used by keepAlive repositories
  /// (ChecklistRepository, JournalRepository). An auto-disposed provider's
  /// Ref becomes invalid once no listeners remain, causing "Cannot use Ref
  /// after disposed" errors when the repository calls back into this service
  /// asynchronously.
  TaskSummaryRefreshServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'taskSummaryRefreshServiceProvider',
          isAutoDispose: false,
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
    r'f489aec1f718f7ce988336ef0d57546c82e20354';
