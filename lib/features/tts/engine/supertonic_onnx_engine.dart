import 'dart:io';

import 'package:lotti/features/tts/engine/supertonic_tts_session.dart';
import 'package:lotti/features/tts/engine/tts_engine.dart';
import 'package:lotti/features/tts/engine/voice_style_loader.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:path_provider/path_provider.dart';

/// Bundled-asset directory for voice-style JSONs.
const String _voiceAssetDir = 'assets/tts/voice_styles';

/// Denoising steps — the upstream example's default (quality vs latency).
const int _denoisingSteps = 8;

/// [TtsEngine] backed by the Supertonic ONNX models via `flutter_onnxruntime`.
///
/// The loaded session and per-voice styles are cached so repeated playback
/// reuses them. Synthesis writes a 44.1kHz WAV to a temp file the player
/// opens. Gated to macOS — the same platform the MLX audio bridge supports and
/// the only one Supertonic's Flutter example was validated on.
class SupertonicOnnxEngine implements TtsEngine {
  SupertonicTtsSession? _session;
  String? _sessionDir;
  final Map<String, VoiceStyle> _voiceCache = <String, VoiceStyle>{};
  int _counter = 0;

  @override
  bool get isSupported => platform.isMacOS;

  @override
  Future<File> synthesizeToFile({
    required String text,
    required String voiceId,
    required String modelDirectory,
    required String language,
  }) async {
    final session = await _ensureSession(modelDirectory);
    final style = await _ensureVoice(voiceId);
    final result = await session.synthesize(
      text: text,
      language: language,
      style: style,
      totalStep: _denoisingSteps,
    );
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tts_${voiceId}_${_counter++}.wav';
    await writeWavFile(path, result.samples, session.sampleRate);
    return File(path);
  }

  Future<SupertonicTtsSession> _ensureSession(String modelDir) async {
    final existing = _session;
    if (existing != null && _sessionDir == modelDir) return existing;
    await existing?.dispose();
    final session = await loadSupertonicSession(modelDir);
    _session = session;
    _sessionDir = modelDir;
    return session;
  }

  Future<VoiceStyle> _ensureVoice(String voiceId) async {
    final cached = _voiceCache[voiceId];
    if (cached != null) return cached;
    final style = await loadVoiceStyle(['$_voiceAssetDir/$voiceId.json']);
    _voiceCache[voiceId] = style;
    return style;
  }

  @override
  Future<void> dispose() async {
    await _session?.dispose();
    _session = null;
    _sessionDir = null;
    _voiceCache.clear();
  }
}
