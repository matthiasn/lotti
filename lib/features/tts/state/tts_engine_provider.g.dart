// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the on-device TTS engine — the Supertonic ONNX engine on the
/// platforms where `flutter_onnxruntime` is integrated
/// ([SupertonicOnnxEngine.isPlatformSupported]: macOS, iOS, Linux, Android), the
/// unavailable fallback elsewhere. Tests override this with a fake.

@ProviderFor(ttsEngine)
final ttsEngineProvider = TtsEngineProvider._();

/// Provides the on-device TTS engine — the Supertonic ONNX engine on the
/// platforms where `flutter_onnxruntime` is integrated
/// ([SupertonicOnnxEngine.isPlatformSupported]: macOS, iOS, Linux, Android), the
/// unavailable fallback elsewhere. Tests override this with a fake.

final class TtsEngineProvider
    extends $FunctionalProvider<TtsEngine, TtsEngine, TtsEngine>
    with $Provider<TtsEngine> {
  /// Provides the on-device TTS engine — the Supertonic ONNX engine on the
  /// platforms where `flutter_onnxruntime` is integrated
  /// ([SupertonicOnnxEngine.isPlatformSupported]: macOS, iOS, Linux, Android), the
  /// unavailable fallback elsewhere. Tests override this with a fake.
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

String _$ttsEngineHash() => r'1daa0b63336c245a5f7e279d11cce0aa23d71a69';
