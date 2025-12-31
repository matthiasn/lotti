// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_waveform_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audioWaveform)
final audioWaveformProvider = AudioWaveformFamily._();

final class AudioWaveformProvider extends $FunctionalProvider<
        AsyncValue<AudioWaveformData?>,
        AudioWaveformData?,
        FutureOr<AudioWaveformData?>>
    with
        $FutureModifier<AudioWaveformData?>,
        $FutureProvider<AudioWaveformData?> {
  AudioWaveformProvider._(
      {required AudioWaveformFamily super.from,
      required AudioWaveformRequest super.argument})
      : super(
          retry: null,
          name: r'audioWaveformProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$audioWaveformHash();

  @override
  String toString() {
    return r'audioWaveformProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AudioWaveformData?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AudioWaveformData?> create(Ref ref) {
    final argument = this.argument as AudioWaveformRequest;
    return audioWaveform(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioWaveformProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioWaveformHash() => r'6b355266d3590bbdf948e9f0b0b89efda13b61fa';

final class AudioWaveformFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<AudioWaveformData?>,
            AudioWaveformRequest> {
  AudioWaveformFamily._()
      : super(
          retry: null,
          name: r'audioWaveformProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AudioWaveformProvider call(
    AudioWaveformRequest request,
  ) =>
      AudioWaveformProvider._(argument: request, from: this);

  @override
  String toString() => r'audioWaveformProvider';
}
