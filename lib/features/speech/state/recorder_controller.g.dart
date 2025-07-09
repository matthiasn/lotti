// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recorder_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioRecorderControllerHash() =>
    r'8449d0e62e13a1c5f59bc99481c59c8730389268';

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
/// - Language selection for transcription
///
/// The controller is kept alive to maintain recording state across navigation.
///
/// Copied from [AudioRecorderController].
@ProviderFor(AudioRecorderController)
final audioRecorderControllerProvider =
    NotifierProvider<AudioRecorderController, AudioRecorderState>.internal(
  AudioRecorderController.new,
  name: r'audioRecorderControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioRecorderControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AudioRecorderController = Notifier<AudioRecorderState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
