// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_ended_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks entry IDs whose timer sessions have just ended (recording→stopped
/// transition with duration >= 1 minute). Survives widget rebuilds and
/// navigation because it lives in Riverpod state rather than widget `State`.
///
/// Entries are added when a timer stops and removed when a new recording
/// starts on the same entry or when a rating is saved.

@ProviderFor(SessionEndedController)
final sessionEndedControllerProvider = SessionEndedControllerProvider._();

/// Tracks entry IDs whose timer sessions have just ended (recording→stopped
/// transition with duration >= 1 minute). Survives widget rebuilds and
/// navigation because it lives in Riverpod state rather than widget `State`.
///
/// Entries are added when a timer stops and removed when a new recording
/// starts on the same entry or when a rating is saved.
final class SessionEndedControllerProvider
    extends $NotifierProvider<SessionEndedController, Set<String>> {
  /// Tracks entry IDs whose timer sessions have just ended (recording→stopped
  /// transition with duration >= 1 minute). Survives widget rebuilds and
  /// navigation because it lives in Riverpod state rather than widget `State`.
  ///
  /// Entries are added when a timer stops and removed when a new recording
  /// starts on the same entry or when a rating is saved.
  SessionEndedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionEndedControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionEndedControllerHash();

  @$internal
  @override
  SessionEndedController create() => SessionEndedController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$sessionEndedControllerHash() =>
    r'27745ea13d975645b1682f659a35f837c19c339c';

/// Tracks entry IDs whose timer sessions have just ended (recording→stopped
/// transition with duration >= 1 minute). Survives widget rebuilds and
/// navigation because it lives in Riverpod state rather than widget `State`.
///
/// Entries are added when a timer stops and removed when a new recording
/// starts on the same entry or when a rating is saved.

abstract class _$SessionEndedController extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
