// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_task_summary_refresh_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(DirectTaskSummaryRefreshController)
final directTaskSummaryRefreshControllerProvider =
    DirectTaskSummaryRefreshControllerProvider._();

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
final class DirectTaskSummaryRefreshControllerProvider
    extends $NotifierProvider<DirectTaskSummaryRefreshController,
        ScheduledRefreshState> {
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
  DirectTaskSummaryRefreshControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'directTaskSummaryRefreshControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() =>
      _$directTaskSummaryRefreshControllerHash();

  @$internal
  @override
  DirectTaskSummaryRefreshController create() =>
      DirectTaskSummaryRefreshController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledRefreshState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledRefreshState>(value),
    );
  }
}

String _$directTaskSummaryRefreshControllerHash() =>
    r'ac40cf7076a8c1b349720d6e200572021a9894c2';

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

abstract class _$DirectTaskSummaryRefreshController
    extends $Notifier<ScheduledRefreshState> {
  ScheduledRefreshState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ScheduledRefreshState, ScheduledRefreshState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ScheduledRefreshState, ScheduledRefreshState>,
        ScheduledRefreshState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Provider that exposes the scheduled refresh time for a specific task

@ProviderFor(scheduledTaskSummaryRefresh)
final scheduledTaskSummaryRefreshProvider =
    ScheduledTaskSummaryRefreshFamily._();

/// Provider that exposes the scheduled refresh time for a specific task

final class ScheduledTaskSummaryRefreshProvider
    extends $FunctionalProvider<DateTime?, DateTime?, DateTime?>
    with $Provider<DateTime?> {
  /// Provider that exposes the scheduled refresh time for a specific task
  ScheduledTaskSummaryRefreshProvider._(
      {required ScheduledTaskSummaryRefreshFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'scheduledTaskSummaryRefreshProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$scheduledTaskSummaryRefreshHash();

  @override
  String toString() {
    return r'scheduledTaskSummaryRefreshProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime? create(Ref ref) {
    final argument = this.argument as String;
    return scheduledTaskSummaryRefresh(
      ref,
      taskId: argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScheduledTaskSummaryRefreshProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scheduledTaskSummaryRefreshHash() =>
    r'dec86e9ad67e7fcca315e32fec9f4e4be601983b';

/// Provider that exposes the scheduled refresh time for a specific task

final class ScheduledTaskSummaryRefreshFamily extends $Family
    with $FunctionalFamilyOverride<DateTime?, String> {
  ScheduledTaskSummaryRefreshFamily._()
      : super(
          retry: null,
          name: r'scheduledTaskSummaryRefreshProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Provider that exposes the scheduled refresh time for a specific task

  ScheduledTaskSummaryRefreshProvider call({
    required String taskId,
  }) =>
      ScheduledTaskSummaryRefreshProvider._(argument: taskId, from: this);

  @override
  String toString() => r'scheduledTaskSummaryRefreshProvider';
}
