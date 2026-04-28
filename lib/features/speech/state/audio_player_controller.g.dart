// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the player factory, can be overridden in tests.

@ProviderFor(playerFactory)
final playerFactoryProvider = PlayerFactoryProvider._();

/// Provider for the player factory, can be overridden in tests.

final class PlayerFactoryProvider
    extends $FunctionalProvider<PlayerFactory, PlayerFactory, PlayerFactory>
    with $Provider<PlayerFactory> {
  /// Provider for the player factory, can be overridden in tests.
  PlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerFactoryHash();

  @$internal
  @override
  $ProviderElement<PlayerFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlayerFactory create(Ref ref) {
    return playerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerFactory>(value),
    );
  }
}

String _$playerFactoryHash() => r'97fc3a12db5c97e405602b8ed38fdb574808a6ca';

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
///
/// The underlying media_kit [Player] is created lazily on the first
/// `setAudioNote`/`play` call and torn down again when playback completes.
/// Keeping the native mpv core thread out of memory between active sessions
/// makes Flutter hot restart safe whenever audio is not actively playing.
/// (mpv's `core_thread` invokes FFI callbacks asynchronously; if the Dart
/// VM is torn down by hot restart while the thread is alive, the trampolines
/// it calls into are gone and the process aborts with
/// "Callback invoked after it has been deleted".)

@ProviderFor(AudioPlayerController)
final audioPlayerControllerProvider = AudioPlayerControllerProvider._();

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
///
/// The underlying media_kit [Player] is created lazily on the first
/// `setAudioNote`/`play` call and torn down again when playback completes.
/// Keeping the native mpv core thread out of memory between active sessions
/// makes Flutter hot restart safe whenever audio is not actively playing.
/// (mpv's `core_thread` invokes FFI callbacks asynchronously; if the Dart
/// VM is torn down by hot restart while the thread is alive, the trampolines
/// it calls into are gone and the process aborts with
/// "Callback invoked after it has been deleted".)
final class AudioPlayerControllerProvider
    extends $NotifierProvider<AudioPlayerController, AudioPlayerState> {
  /// Notifier managing audio player state.
  /// Marked as keepAlive since audio state should persist for the entire app
  /// lifecycle.
  ///
  /// The underlying media_kit [Player] is created lazily on the first
  /// `setAudioNote`/`play` call and torn down again when playback completes.
  /// Keeping the native mpv core thread out of memory between active sessions
  /// makes Flutter hot restart safe whenever audio is not actively playing.
  /// (mpv's `core_thread` invokes FFI callbacks asynchronously; if the Dart
  /// VM is torn down by hot restart while the thread is alive, the trampolines
  /// it calls into are gone and the process aborts with
  /// "Callback invoked after it has been deleted".)
  AudioPlayerControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerControllerHash();

  @$internal
  @override
  AudioPlayerController create() => AudioPlayerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayerState>(value),
    );
  }
}

String _$audioPlayerControllerHash() =>
    r'20ac72444988e23f4319261fba05b43f15ff0f9f';

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
///
/// The underlying media_kit [Player] is created lazily on the first
/// `setAudioNote`/`play` call and torn down again when playback completes.
/// Keeping the native mpv core thread out of memory between active sessions
/// makes Flutter hot restart safe whenever audio is not actively playing.
/// (mpv's `core_thread` invokes FFI callbacks asynchronously; if the Dart
/// VM is torn down by hot restart while the thread is alive, the trampolines
/// it calls into are gone and the process aborts with
/// "Callback invoked after it has been deleted".)

abstract class _$AudioPlayerController extends $Notifier<AudioPlayerState> {
  AudioPlayerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AudioPlayerState, AudioPlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioPlayerState, AudioPlayerState>,
              AudioPlayerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
