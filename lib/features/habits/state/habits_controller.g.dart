// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habits_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the whole [HabitsState] for the habits tab.
///
/// Subscribes to three sources and recomputes derived state whenever any
/// fires: the repository's habit-definition stream, the update stream filtered
/// for `habitCompletionNotification`, and the nav-index stream (to refresh the
/// time-sensitive due/later split when the tab is re-entered). The heavy lift
/// is [_determineHabitSuccessByDays], which buckets completions into the
/// per-day maps, splits open habits into due-now vs. pending-later via
/// `showHabit`, applies the category filter, counts streaks and recomputes the
/// chart's [HabitsState.minY].
///
/// Marked `keepAlive` so the (relatively expensive) state survives navigating
/// away from and back to the tab.

@ProviderFor(HabitsController)
final habitsControllerProvider = HabitsControllerProvider._();

/// Owns the whole [HabitsState] for the habits tab.
///
/// Subscribes to three sources and recomputes derived state whenever any
/// fires: the repository's habit-definition stream, the update stream filtered
/// for `habitCompletionNotification`, and the nav-index stream (to refresh the
/// time-sensitive due/later split when the tab is re-entered). The heavy lift
/// is [_determineHabitSuccessByDays], which buckets completions into the
/// per-day maps, splits open habits into due-now vs. pending-later via
/// `showHabit`, applies the category filter, counts streaks and recomputes the
/// chart's [HabitsState.minY].
///
/// Marked `keepAlive` so the (relatively expensive) state survives navigating
/// away from and back to the tab.
final class HabitsControllerProvider
    extends $NotifierProvider<HabitsController, HabitsState> {
  /// Owns the whole [HabitsState] for the habits tab.
  ///
  /// Subscribes to three sources and recomputes derived state whenever any
  /// fires: the repository's habit-definition stream, the update stream filtered
  /// for `habitCompletionNotification`, and the nav-index stream (to refresh the
  /// time-sensitive due/later split when the tab is re-entered). The heavy lift
  /// is [_determineHabitSuccessByDays], which buckets completions into the
  /// per-day maps, splits open habits into due-now vs. pending-later via
  /// `showHabit`, applies the category filter, counts streaks and recomputes the
  /// chart's [HabitsState.minY].
  ///
  /// Marked `keepAlive` so the (relatively expensive) state survives navigating
  /// away from and back to the tab.
  HabitsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitsControllerHash();

  @$internal
  @override
  HabitsController create() => HabitsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitsState>(value),
    );
  }
}

String _$habitsControllerHash() => r'e6da6f4ec4d09e1e84e3baf89b8815c740fafbfa';

/// Owns the whole [HabitsState] for the habits tab.
///
/// Subscribes to three sources and recomputes derived state whenever any
/// fires: the repository's habit-definition stream, the update stream filtered
/// for `habitCompletionNotification`, and the nav-index stream (to refresh the
/// time-sensitive due/later split when the tab is re-entered). The heavy lift
/// is [_determineHabitSuccessByDays], which buckets completions into the
/// per-day maps, splits open habits into due-now vs. pending-later via
/// `showHabit`, applies the category filter, counts streaks and recomputes the
/// chart's [HabitsState.minY].
///
/// Marked `keepAlive` so the (relatively expensive) state survives navigating
/// away from and back to the tab.

abstract class _$HabitsController extends $Notifier<HabitsState> {
  HabitsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HabitsState, HabitsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HabitsState, HabitsState>,
              HabitsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
