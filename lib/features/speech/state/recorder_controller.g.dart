// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recorder_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.

@ProviderFor(AudioRecorderController)
final audioRecorderControllerProvider = AudioRecorderControllerProvider._();

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.
final class AudioRecorderControllerProvider
    extends $NotifierProvider<AudioRecorderController, AudioRecorderState> {
  /// Main controller for audio recording functionality.
  ///
  /// This Riverpod controller manages the complete recording lifecycle including:
  /// - Recording state (start, stop, pause, resume)
  /// - Real-time audio level monitoring for VU meter display
  /// - Integration with audio player to pause playback during recording
  /// - UI state management (modal visibility, indicator visibility)
  ///
  /// The controller is kept alive to maintain recording state across navigation.
  AudioRecorderControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'audioRecorderControllerProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$audioRecorderControllerHash();

  @$internal
  @override
  AudioRecorderController create() => AudioRecorderController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioRecorderState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioRecorderState>(value),
    );
  }
}

String _$audioRecorderControllerHash() =>
    r'8b16a4bb18ef63bc31bbb855da59cc3626b342b6';

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.

abstract class _$AudioRecorderController extends $Notifier<AudioRecorderState> {
  AudioRecorderState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AudioRecorderState, AudioRecorderState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AudioRecorderState, AudioRecorderState>,
        AudioRecorderState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
