// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_os_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the selected date for the Daily OS view.

@ProviderFor(DailyOsSelectedDate)
final dailyOsSelectedDateProvider = DailyOsSelectedDateProvider._();

/// Provides the selected date for the Daily OS view.
final class DailyOsSelectedDateProvider
    extends $NotifierProvider<DailyOsSelectedDate, DateTime> {
  /// Provides the selected date for the Daily OS view.
  DailyOsSelectedDateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dailyOsSelectedDateProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dailyOsSelectedDateHash();

  @$internal
  @override
  DailyOsSelectedDate create() => DailyOsSelectedDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$dailyOsSelectedDateHash() =>
    r'c3800905cdbd658c554c92c87f379b58008181f0';

/// Provides the selected date for the Daily OS view.

abstract class _$DailyOsSelectedDate extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<DateTime, DateTime>, DateTime, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.
/// Uses the UnifiedDailyOsDataController for data that auto-updates when
/// entries are created or synced.

@ProviderFor(DailyOsController)
final dailyOsControllerProvider = DailyOsControllerProvider._();

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.
/// Uses the UnifiedDailyOsDataController for data that auto-updates when
/// entries are created or synced.
final class DailyOsControllerProvider
    extends $AsyncNotifierProvider<DailyOsController, DailyOsState> {
  /// Main controller for the Daily OS view.
  ///
  /// Combines day plan, budget progress, and timeline data into a unified state.
  /// Uses the UnifiedDailyOsDataController for data that auto-updates when
  /// entries are created or synced.
  DailyOsControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dailyOsControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dailyOsControllerHash();

  @$internal
  @override
  DailyOsController create() => DailyOsController();
}

String _$dailyOsControllerHash() => r'4f848e6a6aeab9077b686d327be4adfac4552bcc';

/// Main controller for the Daily OS view.
///
/// Combines day plan, budget progress, and timeline data into a unified state.
/// Uses the UnifiedDailyOsDataController for data that auto-updates when
/// entries are created or synced.

abstract class _$DailyOsController extends $AsyncNotifier<DailyOsState> {
  FutureOr<DailyOsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DailyOsState>, DailyOsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<DailyOsState>, DailyOsState>,
        AsyncValue<DailyOsState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Provides just the highlighted category ID for efficient rebuilds.

@ProviderFor(highlightedCategoryId)
final highlightedCategoryIdProvider = HighlightedCategoryIdProvider._();

/// Provides just the highlighted category ID for efficient rebuilds.

final class HighlightedCategoryIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Provides just the highlighted category ID for efficient rebuilds.
  HighlightedCategoryIdProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'highlightedCategoryIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$highlightedCategoryIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return highlightedCategoryId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$highlightedCategoryIdHash() =>
    r'4d99c4f6b8f16b3a8738f1d7f329519a824a1d67';

/// Provides just the expanded fold regions for efficient rebuilds.

@ProviderFor(expandedFoldRegions)
final expandedFoldRegionsProvider = ExpandedFoldRegionsProvider._();

/// Provides just the expanded fold regions for efficient rebuilds.

final class ExpandedFoldRegionsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// Provides just the expanded fold regions for efficient rebuilds.
  ExpandedFoldRegionsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'expandedFoldRegionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$expandedFoldRegionsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return expandedFoldRegions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$expandedFoldRegionsHash() =>
    r'18fa6afc4b558bfa56ca2a1415ff9b4d38b5aae9';

/// Provides the active focus category ID based on the current time.
///
/// Returns the category ID of the planned block that the current time
/// falls within on TODAY's schedule, or null if there's no active block.
/// This is used for the "Focus First" UX where only the currently active
/// category is expanded and all others are collapsed.
///
/// The active category persists even when viewing historical or future dates,
/// since it always checks TODAY's schedule regardless of the selected date.
///
/// Re-evaluates every 15 seconds to keep the focus state reasonably current
/// without excessive resource usage. Handles midnight crossings by
/// recalculating "today" on each iteration.

@ProviderFor(activeFocusCategoryId)
final activeFocusCategoryIdProvider = ActiveFocusCategoryIdProvider._();

/// Provides the active focus category ID based on the current time.
///
/// Returns the category ID of the planned block that the current time
/// falls within on TODAY's schedule, or null if there's no active block.
/// This is used for the "Focus First" UX where only the currently active
/// category is expanded and all others are collapsed.
///
/// The active category persists even when viewing historical or future dates,
/// since it always checks TODAY's schedule regardless of the selected date.
///
/// Re-evaluates every 15 seconds to keep the focus state reasonably current
/// without excessive resource usage. Handles midnight crossings by
/// recalculating "today" on each iteration.

final class ActiveFocusCategoryIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, Stream<String?>>
    with $FutureModifier<String?>, $StreamProvider<String?> {
  /// Provides the active focus category ID based on the current time.
  ///
  /// Returns the category ID of the planned block that the current time
  /// falls within on TODAY's schedule, or null if there's no active block.
  /// This is used for the "Focus First" UX where only the currently active
  /// category is expanded and all others are collapsed.
  ///
  /// The active category persists even when viewing historical or future dates,
  /// since it always checks TODAY's schedule regardless of the selected date.
  ///
  /// Re-evaluates every 15 seconds to keep the focus state reasonably current
  /// without excessive resource usage. Handles midnight crossings by
  /// recalculating "today" on each iteration.
  ActiveFocusCategoryIdProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'activeFocusCategoryIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$activeFocusCategoryIdHash();

  @$internal
  @override
  $StreamProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String?> create(Ref ref) {
    return activeFocusCategoryId(ref);
  }
}

String _$activeFocusCategoryIdHash() =>
    r'e362bbab83c33ba3968e50d145ae255738d444d7';

/// Provides the category ID of the currently running timer.
///
/// Returns the category ID (from linkedFrom or the entry itself) when a timer
/// is actively running, or null when no timer is running.
/// Used for visual indicators in the UI (e.g., showing a timer icon).

@ProviderFor(RunningTimerCategoryId)
final runningTimerCategoryIdProvider = RunningTimerCategoryIdProvider._();

/// Provides the category ID of the currently running timer.
///
/// Returns the category ID (from linkedFrom or the entry itself) when a timer
/// is actively running, or null when no timer is running.
/// Used for visual indicators in the UI (e.g., showing a timer icon).
final class RunningTimerCategoryIdProvider
    extends $NotifierProvider<RunningTimerCategoryId, String?> {
  /// Provides the category ID of the currently running timer.
  ///
  /// Returns the category ID (from linkedFrom or the entry itself) when a timer
  /// is actively running, or null when no timer is running.
  /// Used for visual indicators in the UI (e.g., showing a timer icon).
  RunningTimerCategoryIdProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'runningTimerCategoryIdProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$runningTimerCategoryIdHash();

  @$internal
  @override
  RunningTimerCategoryId create() => RunningTimerCategoryId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$runningTimerCategoryIdHash() =>
    r'de27450d1e3ceddb8c4cb9e6dd3b5b286e86e08c';

/// Provides the category ID of the currently running timer.
///
/// Returns the category ID (from linkedFrom or the entry itself) when a timer
/// is actively running, or null when no timer is running.
/// Used for visual indicators in the UI (e.g., showing a timer icon).

abstract class _$RunningTimerCategoryId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String?, String?>, String?, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
