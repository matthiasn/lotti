// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theming_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$enableTooltipsHash() => r'd4ffad68f2eb7a43301add99bb014fa3fe0d2898';

/// Stream provider watching the tooltip enable flag from config.
///
/// Copied from [enableTooltips].
@ProviderFor(enableTooltips)
final enableTooltipsProvider = AutoDisposeStreamProvider<bool>.internal(
  enableTooltips,
  name: r'enableTooltipsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$enableTooltipsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EnableTooltipsRef = AutoDisposeStreamProviderRef<bool>;
String _$themingControllerHash() => r'f81327e92953d43be12b831636904cab67990811';

/// Notifier managing the complete theming state.
/// Marked as keepAlive since theme state should persist for the entire app lifecycle.
///
/// Copied from [ThemingController].
@ProviderFor(ThemingController)
final themingControllerProvider =
    NotifierProvider<ThemingController, ThemingState>.internal(
  ThemingController.new,
  name: r'themingControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$themingControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemingController = Notifier<ThemingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
