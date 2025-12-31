// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_recorder_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the audio recorder repository.
/// Kept alive to maintain recording state across navigation.

@ProviderFor(audioRecorderRepository)
final audioRecorderRepositoryProvider = AudioRecorderRepositoryProvider._();

/// Provider for the audio recorder repository.
/// Kept alive to maintain recording state across navigation.

final class AudioRecorderRepositoryProvider extends $FunctionalProvider<
    AudioRecorderRepository,
    AudioRecorderRepository,
    AudioRecorderRepository> with $Provider<AudioRecorderRepository> {
  /// Provider for the audio recorder repository.
  /// Kept alive to maintain recording state across navigation.
  AudioRecorderRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'audioRecorderRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$audioRecorderRepositoryHash();

  @$internal
  @override
  $ProviderElement<AudioRecorderRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioRecorderRepository create(Ref ref) {
    return audioRecorderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioRecorderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioRecorderRepository>(value),
    );
  }
}

String _$audioRecorderRepositoryHash() =>
    r'f0050ec0bfccbaaedbeddb0f560f661558313922';
