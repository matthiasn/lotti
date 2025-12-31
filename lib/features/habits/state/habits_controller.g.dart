// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habits_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier managing the complete habits page state.
/// Marked as keepAlive since habits state should persist across navigation.

@ProviderFor(HabitsController)
final habitsControllerProvider = HabitsControllerProvider._();

/// Notifier managing the complete habits page state.
/// Marked as keepAlive since habits state should persist across navigation.
final class HabitsControllerProvider
    extends $NotifierProvider<HabitsController, HabitsState> {
  /// Notifier managing the complete habits page state.
  /// Marked as keepAlive since habits state should persist across navigation.
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

String _$habitsControllerHash() => r'149a24586367ab6230a2748dba3436faed61d600';

/// Notifier managing the complete habits page state.
/// Marked as keepAlive since habits state should persist across navigation.

abstract class _$HabitsController extends $Notifier<HabitsState> {
  HabitsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HabitsState, HabitsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<HabitsState, HabitsState>, HabitsState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}
