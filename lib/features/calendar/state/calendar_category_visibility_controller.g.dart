// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_category_visibility_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$calendarCategoryVisibilityControllerHash() =>
    r'062fa912856fe8cac391492b5768efc87f0c7fb7';

/// Controller that provides category visibility state for the Calendar view.
///
/// This controller reads from the same persistence layer as the Tasks page
/// (JournalPageCubit), allowing the Calendar to respect the category
/// visibility settings configured on the Tasks page.
///
/// Visibility semantics:
/// - Empty set = all categories visible (show all text)
/// - Non-empty set = only those categories visible, others have text hidden
///
/// Copied from [CalendarCategoryVisibilityController].
@ProviderFor(CalendarCategoryVisibilityController)
final calendarCategoryVisibilityControllerProvider = NotifierProvider<
    CalendarCategoryVisibilityController, Set<String>>.internal(
  CalendarCategoryVisibilityController.new,
  name: r'calendarCategoryVisibilityControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$calendarCategoryVisibilityControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CalendarCategoryVisibilityController = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
