// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_category_visibility_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller that provides category visibility state for the Calendar view.
///
/// This controller reads from the same persistence layer as the Tasks page
/// (JournalPageCubit), allowing the Calendar to respect the category
/// visibility settings configured on the Tasks page.
///
/// Visibility semantics:
/// - Empty set = all categories visible (show all text)
/// - Non-empty set = only those categories visible, others have text hidden

@ProviderFor(CalendarCategoryVisibilityController)
final calendarCategoryVisibilityControllerProvider =
    CalendarCategoryVisibilityControllerProvider._();

/// Controller that provides category visibility state for the Calendar view.
///
/// This controller reads from the same persistence layer as the Tasks page
/// (JournalPageCubit), allowing the Calendar to respect the category
/// visibility settings configured on the Tasks page.
///
/// Visibility semantics:
/// - Empty set = all categories visible (show all text)
/// - Non-empty set = only those categories visible, others have text hidden
final class CalendarCategoryVisibilityControllerProvider
    extends $NotifierProvider<CalendarCategoryVisibilityController,
        Set<String>> {
  /// Controller that provides category visibility state for the Calendar view.
  ///
  /// This controller reads from the same persistence layer as the Tasks page
  /// (JournalPageCubit), allowing the Calendar to respect the category
  /// visibility settings configured on the Tasks page.
  ///
  /// Visibility semantics:
  /// - Empty set = all categories visible (show all text)
  /// - Non-empty set = only those categories visible, others have text hidden
  CalendarCategoryVisibilityControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'calendarCategoryVisibilityControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() =>
      _$calendarCategoryVisibilityControllerHash();

  @$internal
  @override
  CalendarCategoryVisibilityController create() =>
      CalendarCategoryVisibilityController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$calendarCategoryVisibilityControllerHash() =>
    r'82e832a18c871e053c4a108884f28a10ef26294d';

/// Controller that provides category visibility state for the Calendar view.
///
/// This controller reads from the same persistence layer as the Tasks page
/// (JournalPageCubit), allowing the Calendar to respect the category
/// visibility settings configured on the Tasks page.
///
/// Visibility semantics:
/// - Empty set = all categories visible (show all text)
/// - Non-empty set = only those categories visible, others have text hidden

abstract class _$CalendarCategoryVisibilityController
    extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Set<String>, Set<String>>, Set<String>, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
