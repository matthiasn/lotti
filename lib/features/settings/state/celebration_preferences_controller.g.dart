// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'celebration_preferences_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the three celebratory-animation switches, persisted across launches in
/// [SettingsDb].
///
/// [build] returns [CelebrationPreferences.allEnabled] synchronously and then
/// hydrates the persisted values, mirroring `ZoomController`. Returning a value
/// synchronously (rather than an `AsyncValue`) lets a celebration call site read
/// the flag on the very frame it would fire — no loading state to thread through
/// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
/// is not registered (some widget tests), so the default simply stays on.

@ProviderFor(CelebrationPreferencesController)
final celebrationPreferencesControllerProvider =
    CelebrationPreferencesControllerProvider._();

/// Holds the three celebratory-animation switches, persisted across launches in
/// [SettingsDb].
///
/// [build] returns [CelebrationPreferences.allEnabled] synchronously and then
/// hydrates the persisted values, mirroring `ZoomController`. Returning a value
/// synchronously (rather than an `AsyncValue`) lets a celebration call site read
/// the flag on the very frame it would fire — no loading state to thread through
/// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
/// is not registered (some widget tests), so the default simply stays on.
final class CelebrationPreferencesControllerProvider
    extends
        $NotifierProvider<
          CelebrationPreferencesController,
          CelebrationPreferences
        > {
  /// Holds the three celebratory-animation switches, persisted across launches in
  /// [SettingsDb].
  ///
  /// [build] returns [CelebrationPreferences.allEnabled] synchronously and then
  /// hydrates the persisted values, mirroring `ZoomController`. Returning a value
  /// synchronously (rather than an `AsyncValue`) lets a celebration call site read
  /// the flag on the very frame it would fire — no loading state to thread through
  /// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
  /// is not registered (some widget tests), so the default simply stays on.
  CelebrationPreferencesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'celebrationPreferencesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$celebrationPreferencesControllerHash();

  @$internal
  @override
  CelebrationPreferencesController create() =>
      CelebrationPreferencesController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CelebrationPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CelebrationPreferences>(value),
    );
  }
}

String _$celebrationPreferencesControllerHash() =>
    r'52037a3a1bd3e6419b53b7598f1a883a5cfd30b0';

/// Holds the three celebratory-animation switches, persisted across launches in
/// [SettingsDb].
///
/// [build] returns [CelebrationPreferences.allEnabled] synchronously and then
/// hydrates the persisted values, mirroring `ZoomController`. Returning a value
/// synchronously (rather than an `AsyncValue`) lets a celebration call site read
/// the flag on the very frame it would fire — no loading state to thread through
/// a `didUpdateWidget`. Reads from / writes to [SettingsDb] are skipped when it
/// is not registered (some widget tests), so the default simply stays on.

abstract class _$CelebrationPreferencesController
    extends $Notifier<CelebrationPreferences> {
  CelebrationPreferences build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<CelebrationPreferences, CelebrationPreferences>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CelebrationPreferences, CelebrationPreferences>,
              CelebrationPreferences,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Convenience read of the current [CelebrationPreferences]. Celebration call
/// sites watch this; tests override it with `overrideWithValue(...)` to assert
/// gating without touching persistence.

@ProviderFor(celebrationPreferences)
final celebrationPreferencesProvider = CelebrationPreferencesProvider._();

/// Convenience read of the current [CelebrationPreferences]. Celebration call
/// sites watch this; tests override it with `overrideWithValue(...)` to assert
/// gating without touching persistence.

final class CelebrationPreferencesProvider
    extends
        $FunctionalProvider<
          CelebrationPreferences,
          CelebrationPreferences,
          CelebrationPreferences
        >
    with $Provider<CelebrationPreferences> {
  /// Convenience read of the current [CelebrationPreferences]. Celebration call
  /// sites watch this; tests override it with `overrideWithValue(...)` to assert
  /// gating without touching persistence.
  CelebrationPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'celebrationPreferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$celebrationPreferencesHash();

  @$internal
  @override
  $ProviderElement<CelebrationPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CelebrationPreferences create(Ref ref) {
    return celebrationPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CelebrationPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CelebrationPreferences>(value),
    );
  }
}

String _$celebrationPreferencesHash() =>
    r'554b9ec2d73fe4f2b19c5edb17662545340ad148';
