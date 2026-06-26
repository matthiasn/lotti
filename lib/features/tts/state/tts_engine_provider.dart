import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/engine/supertonic_onnx_engine.dart';
import 'package:lotti/features/tts/engine/tts_engine.dart';

/// Fallback engine used until the concrete Supertonic ONNX engine is wired in.
///
/// Reports [isSupported] == false so the playback controller degrades
/// gracefully (showing an unavailable state) instead of crashing when the
/// real engine isn't registered yet.
class UnavailableTtsEngine implements TtsEngine {
  const UnavailableTtsEngine();

  @override
  bool get isSupported => false;

  @override
  Future<File> synthesizeToFile({
    required String text,
    required String voiceId,
    required String modelDirectory,
    required String language,
  }) {
    throw UnsupportedError('TTS engine is not available on this build.');
  }

  @override
  Future<void> dispose() async {}
}

/// Provides the on-device TTS engine — the Supertonic ONNX engine on the
/// platforms where `flutter_onnxruntime` is integrated
/// ([SupertonicOnnxEngine.isPlatformSupported]: macOS, iOS, Linux, Android), the
/// unavailable fallback elsewhere. Tests override this with a fake.
final ttsEngineProvider = Provider<TtsEngine>(
  ttsEngine,
  name: 'ttsEngineProvider',
);
TtsEngine ttsEngine(Ref ref) {
  if (!SupertonicOnnxEngine.isPlatformSupported) {
    return const UnavailableTtsEngine();
  }
  final engine = SupertonicOnnxEngine();
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
}
