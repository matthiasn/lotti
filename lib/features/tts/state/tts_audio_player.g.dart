// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_audio_player.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide [TtsAudioPlayer]. Overridden with a fake in tests.

@ProviderFor(ttsAudioPlayer)
final ttsAudioPlayerProvider = TtsAudioPlayerProvider._();

/// App-wide [TtsAudioPlayer]. Overridden with a fake in tests.

final class TtsAudioPlayerProvider
    extends $FunctionalProvider<TtsAudioPlayer, TtsAudioPlayer, TtsAudioPlayer>
    with $Provider<TtsAudioPlayer> {
  /// App-wide [TtsAudioPlayer]. Overridden with a fake in tests.
  TtsAudioPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsAudioPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsAudioPlayerHash();

  @$internal
  @override
  $ProviderElement<TtsAudioPlayer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TtsAudioPlayer create(Ref ref) {
    return ttsAudioPlayer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsAudioPlayer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsAudioPlayer>(value),
    );
  }
}

String _$ttsAudioPlayerHash() => r'f39a1b0c7e91459ccddb13d736e67d632c0d605c';
