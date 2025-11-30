// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_task_summary_refresh_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scheduledTaskSummaryRefreshHash() =>
    r'dec86e9ad67e7fcca315e32fec9f4e4be601983b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider that exposes the scheduled refresh time for a specific task
///
/// Copied from [scheduledTaskSummaryRefresh].
@ProviderFor(scheduledTaskSummaryRefresh)
const scheduledTaskSummaryRefreshProvider = ScheduledTaskSummaryRefreshFamily();

/// Provider that exposes the scheduled refresh time for a specific task
///
/// Copied from [scheduledTaskSummaryRefresh].
class ScheduledTaskSummaryRefreshFamily extends Family<DateTime?> {
  /// Provider that exposes the scheduled refresh time for a specific task
  ///
  /// Copied from [scheduledTaskSummaryRefresh].
  const ScheduledTaskSummaryRefreshFamily();

  /// Provider that exposes the scheduled refresh time for a specific task
  ///
  /// Copied from [scheduledTaskSummaryRefresh].
  ScheduledTaskSummaryRefreshProvider call({
    required String taskId,
  }) {
    return ScheduledTaskSummaryRefreshProvider(
      taskId: taskId,
    );
  }

  @override
  ScheduledTaskSummaryRefreshProvider getProviderOverride(
    covariant ScheduledTaskSummaryRefreshProvider provider,
  ) {
    return call(
      taskId: provider.taskId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'scheduledTaskSummaryRefreshProvider';
}

/// Provider that exposes the scheduled refresh time for a specific task
///
/// Copied from [scheduledTaskSummaryRefresh].
class ScheduledTaskSummaryRefreshProvider
    extends AutoDisposeProvider<DateTime?> {
  /// Provider that exposes the scheduled refresh time for a specific task
  ///
  /// Copied from [scheduledTaskSummaryRefresh].
  ScheduledTaskSummaryRefreshProvider({
    required String taskId,
  }) : this._internal(
          (ref) => scheduledTaskSummaryRefresh(
            ref as ScheduledTaskSummaryRefreshRef,
            taskId: taskId,
          ),
          from: scheduledTaskSummaryRefreshProvider,
          name: r'scheduledTaskSummaryRefreshProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$scheduledTaskSummaryRefreshHash,
          dependencies: ScheduledTaskSummaryRefreshFamily._dependencies,
          allTransitiveDependencies:
              ScheduledTaskSummaryRefreshFamily._allTransitiveDependencies,
          taskId: taskId,
        );

  ScheduledTaskSummaryRefreshProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  Override overrideWith(
    DateTime? Function(ScheduledTaskSummaryRefreshRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ScheduledTaskSummaryRefreshProvider._internal(
        (ref) => create(ref as ScheduledTaskSummaryRefreshRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<DateTime?> createElement() {
    return _ScheduledTaskSummaryRefreshProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledTaskSummaryRefreshProvider &&
        other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ScheduledTaskSummaryRefreshRef on AutoDisposeProviderRef<DateTime?> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _ScheduledTaskSummaryRefreshProviderElement
    extends AutoDisposeProviderElement<DateTime?>
    with ScheduledTaskSummaryRefreshRef {
  _ScheduledTaskSummaryRefreshProviderElement(super.provider);

  @override
  String get taskId => (origin as ScheduledTaskSummaryRefreshProvider).taskId;
}

String _$directTaskSummaryRefreshControllerHash() =>
    r'c43ba295aa153442e084ea681bed55d93c2b8744';

/// Manages scheduled task summary refresh requests from checklist actions.
///
/// This controller implements a "delayed refresh with countdown" pattern:
/// - First checklist change schedules a refresh with 5-minute delay
/// - UI shows countdown: "Summary in 4:32" with cancel/trigger-now buttons
/// - Additional changes batch into existing countdown (no timer reset)
/// - User can cancel the scheduled refresh or trigger immediately
///
/// This reduces API costs while actively working on a task, since summaries
/// are most valuable when returning to a task to catch up.
///
/// The controller bypasses the notification system to avoid circular
/// dependencies and infinite loops that could occur if checklist changes
/// triggered notifications that triggered refreshes that updated checklists.
///
/// Copied from [DirectTaskSummaryRefreshController].
@ProviderFor(DirectTaskSummaryRefreshController)
final directTaskSummaryRefreshControllerProvider = NotifierProvider<
    DirectTaskSummaryRefreshController, ScheduledRefreshState>.internal(
  DirectTaskSummaryRefreshController.new,
  name: r'directTaskSummaryRefreshControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$directTaskSummaryRefreshControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DirectTaskSummaryRefreshController = Notifier<ScheduledRefreshState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
