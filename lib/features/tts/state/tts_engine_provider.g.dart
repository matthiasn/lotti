// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the on-device TTS engine. Tests override this with a fake; the
/// concrete Supertonic ONNX engine replaces the fallback once wired.

@ProviderFor(ttsEngine)
final ttsEngineProvider = TtsEngineProvider._();

/// Provides the on-device TTS engine. Tests override this with a fake; the
/// concrete Supertonic ONNX engine replaces the fallback once wired.

final class TtsEngineProvider
    extends $FunctionalProvider<TtsEngine, TtsEngine, TtsEngine>
    with $Provider<TtsEngine> {
  /// Provides the on-device TTS engine. Tests override this with a fake; the
  /// concrete Supertonic ONNX engine replaces the fallback once wired.
  TtsEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsEngineHash();

  @$internal
  @override
  $ProviderElement<TtsEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TtsEngine create(Ref ref) {
    return ttsEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsEngine>(value),
    );
  }
}

String _$ttsEngineHash() => r'a6697d4a986a4486cc7e33a34198ad6ce0d807dc';
