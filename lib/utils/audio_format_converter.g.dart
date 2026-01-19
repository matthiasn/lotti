// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_format_converter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the audio format converter service.

@ProviderFor(audioFormatConverter)
final audioFormatConverterProvider = AudioFormatConverterProvider._();

/// Provider for the audio format converter service.

final class AudioFormatConverterProvider extends $FunctionalProvider<
    AudioFormatConverterService,
    AudioFormatConverterService,
    AudioFormatConverterService> with $Provider<AudioFormatConverterService> {
  /// Provider for the audio format converter service.
  AudioFormatConverterProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'audioFormatConverterProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$audioFormatConverterHash();

  @$internal
  @override
  $ProviderElement<AudioFormatConverterService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioFormatConverterService create(Ref ref) {
    return audioFormatConverter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioFormatConverterService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioFormatConverterService>(value),
    );
  }
}

String _$audioFormatConverterHash() =>
    r'3c38339c5aac583b352c1d6bc9b4968a29b8e589';
