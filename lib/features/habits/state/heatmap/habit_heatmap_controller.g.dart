// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_heatmap_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the deep-history series for the habits consistency heatmap.
///
/// Deliberately separate from [HabitsController]: that controller refetches
/// only a short 7/14-day window on every completion to drive the tab's hot
/// path, whereas the heatmap wants a multi-year range — coupling them would put
/// years of data on the completion hot path. This controller fetches its own
/// wide range once, recomputes purely on category-filter changes (no refetch),
/// and refetches only when a habit completion actually changes.
///
/// State is a plain [HabitHeatmapData] (not an `AsyncValue`) seeded with
/// [HabitHeatmapData.empty]; after the first recompute it never republishes a
/// loading state, so a background refresh never blanks the grid.

@ProviderFor(HabitHeatmapController)
final habitHeatmapControllerProvider = HabitHeatmapControllerProvider._();

/// Owns the deep-history series for the habits consistency heatmap.
///
/// Deliberately separate from [HabitsController]: that controller refetches
/// only a short 7/14-day window on every completion to drive the tab's hot
/// path, whereas the heatmap wants a multi-year range — coupling them would put
/// years of data on the completion hot path. This controller fetches its own
/// wide range once, recomputes purely on category-filter changes (no refetch),
/// and refetches only when a habit completion actually changes.
///
/// State is a plain [HabitHeatmapData] (not an `AsyncValue`) seeded with
/// [HabitHeatmapData.empty]; after the first recompute it never republishes a
/// loading state, so a background refresh never blanks the grid.
final class HabitHeatmapControllerProvider
    extends $NotifierProvider<HabitHeatmapController, HabitHeatmapData> {
  /// Owns the deep-history series for the habits consistency heatmap.
  ///
  /// Deliberately separate from [HabitsController]: that controller refetches
  /// only a short 7/14-day window on every completion to drive the tab's hot
  /// path, whereas the heatmap wants a multi-year range — coupling them would put
  /// years of data on the completion hot path. This controller fetches its own
  /// wide range once, recomputes purely on category-filter changes (no refetch),
  /// and refetches only when a habit completion actually changes.
  ///
  /// State is a plain [HabitHeatmapData] (not an `AsyncValue`) seeded with
  /// [HabitHeatmapData.empty]; after the first recompute it never republishes a
  /// loading state, so a background refresh never blanks the grid.
  HabitHeatmapControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitHeatmapControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitHeatmapControllerHash();

  @$internal
  @override
  HabitHeatmapController create() => HabitHeatmapController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HabitHeatmapData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HabitHeatmapData>(value),
    );
  }
}

String _$habitHeatmapControllerHash() =>
    r'ddac11eaa36fb9be42f50f2310bdd6e9e58c35cc';

/// Owns the deep-history series for the habits consistency heatmap.
///
/// Deliberately separate from [HabitsController]: that controller refetches
/// only a short 7/14-day window on every completion to drive the tab's hot
/// path, whereas the heatmap wants a multi-year range — coupling them would put
/// years of data on the completion hot path. This controller fetches its own
/// wide range once, recomputes purely on category-filter changes (no refetch),
/// and refetches only when a habit completion actually changes.
///
/// State is a plain [HabitHeatmapData] (not an `AsyncValue`) seeded with
/// [HabitHeatmapData.empty]; after the first recompute it never republishes a
/// loading state, so a background refresh never blanks the grid.

abstract class _$HabitHeatmapController extends $Notifier<HabitHeatmapData> {
  HabitHeatmapData build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HabitHeatmapData, HabitHeatmapData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HabitHeatmapData, HabitHeatmapData>,
              HabitHeatmapData,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
