import 'dart:io';

import 'package:lotti/features/tts/engine/tts_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_engine_provider.g.dart';

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

/// Provides the on-device TTS engine. The concrete Supertonic ONNX engine
/// (which needs `flutter_onnxruntime` + a static-linkage Podfile and bundled
/// voice assets — see the feature README) is a deliberate native-integration
/// step; until it is wired this returns the unavailable fallback, and tests
/// override it with a fake.
@Riverpod(keepAlive: true)
TtsEngine ttsEngine(Ref ref) => const UnavailableTtsEngine();
