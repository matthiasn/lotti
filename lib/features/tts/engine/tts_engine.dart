import 'dart:io';

/// Abstraction over the on-device TTS engine.
///
/// The concrete implementation (`SupertonicOnnxEngine`) runs the Supertonic
/// ONNX models via `flutter_onnxruntime`. Controllers and tests depend on this
/// small, mockable surface rather than the native runtime, so playback logic
/// can be exercised end-to-end with a fake engine.
abstract interface class TtsEngine {
  /// Whether on-device TTS can run on this build/platform.
  bool get isSupported;

  /// Synthesizes [text] in [language] with the voice [voiceId], loading the
  /// model files from [modelDirectory], and returns the written 44.1kHz WAV
  /// file. The audio is generated at a natural rate; playback speed is applied
  /// downstream by the player, so the engine never re-synthesizes on a speed
  /// change.
  Future<File> synthesizeToFile({
    required String text,
    required String voiceId,
    required String modelDirectory,
    required String language,
  });

  /// Releases ONNX sessions / native resources.
  Future<void> dispose();
}
