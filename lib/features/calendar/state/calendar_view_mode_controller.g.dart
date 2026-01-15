// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_view_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the calendar view mode preference.
///
/// This allows users to toggle between the classic calendar view
/// and the new Daily OS view.

@ProviderFor(CalendarViewModeController)
final calendarViewModeControllerProvider =
    CalendarViewModeControllerProvider._();

/// Controller for the calendar view mode preference.
///
/// This allows users to toggle between the classic calendar view
/// and the new Daily OS view.
final class CalendarViewModeControllerProvider
    extends $NotifierProvider<CalendarViewModeController, CalendarViewMode> {
  /// Controller for the calendar view mode preference.
  ///
  /// This allows users to toggle between the classic calendar view
  /// and the new Daily OS view.
  CalendarViewModeControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'calendarViewModeControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$calendarViewModeControllerHash();

  @$internal
  @override
  CalendarViewModeController create() => CalendarViewModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarViewMode>(value),
    );
  }
}

String _$calendarViewModeControllerHash() =>
    r'a8563de5776c7588a45cd309996ca30f7239f596';

/// Controller for the calendar view mode preference.
///
/// This allows users to toggle between the classic calendar view
/// and the new Daily OS view.

abstract class _$CalendarViewModeController
    extends $Notifier<CalendarViewMode> {
  CalendarViewMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CalendarViewMode, CalendarViewMode>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CalendarViewMode, CalendarViewMode>,
        CalendarViewMode,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
