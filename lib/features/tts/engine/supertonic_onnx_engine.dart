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

/// Loads a Supertonic session from a model directory.
typedef SupertonicSessionLoader =
    Future<SupertonicTtsSession> Function(String modelDir);

/// Loads a batched [VoiceStyle] from one or more voice-style JSON paths.
typedef VoiceStyleLoader = Future<VoiceStyle> Function(List<String> paths);

/// Resolves a directory for synthesized WAV output.
typedef TempDirProvider = Future<Directory> Function();

/// [TtsEngine] backed by the Supertonic ONNX models via `flutter_onnxruntime`.
///
/// The loaded session and per-voice styles are cached so repeated playback
/// reuses them. Synthesis writes a 44.1kHz WAV to a temp file the player
/// opens. Gated to the platforms where `flutter_onnxruntime` is integrated and
/// verified to link (macOS, iOS, Linux); other platforms fall back to the
/// unavailable engine.
///
/// The session loader, voice-style loader, and temp-dir provider are injected
/// (defaulting to the real `flutter_onnxruntime` / `path_provider` calls) so
/// the caching, output, and disposal logic can be unit-tested with mocks
/// without the native runtime.
class SupertonicOnnxEngine implements TtsEngine {
  SupertonicOnnxEngine({
    SupertonicSessionLoader? sessionLoader,
    VoiceStyleLoader? voiceLoader,
    TempDirProvider? tempDirProvider,
  }) : _sessionLoader = sessionLoader ?? loadSupertonicSession,
       _voiceLoader = voiceLoader ?? loadVoiceStyle,
       _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final SupertonicSessionLoader _sessionLoader;
  final VoiceStyleLoader _voiceLoader;
  final TempDirProvider _tempDirProvider;

  SupertonicTtsSession? _session;
  String? _sessionDir;
  final Map<String, VoiceStyle> _voiceCache = <String, VoiceStyle>{};
  int _counter = 0;

  /// Platforms where `flutter_onnxruntime` is integrated and the Supertonic
  /// engine can run. Single source of truth for TTS platform support — the
  /// `ttsEngine` provider gates on this too, so the list lives in one place.
  static bool get isPlatformSupported =>
      platform.isMacOS ||
      platform.isIOS ||
      platform.isLinux ||
      platform.isAndroid;

  @override
  bool get isSupported => isPlatformSupported;

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
    final dir = await _tempDirProvider();
    final path = '${dir.path}/tts_${voiceId}_${_counter++}.wav';
    await writeWavFile(path, result.samples, session.sampleRate);
    return File(path);
  }

  Future<SupertonicTtsSession> _ensureSession(String modelDir) async {
    final existing = _session;
    if (existing != null && _sessionDir == modelDir) return existing;
    await existing?.dispose();
    final session = await _sessionLoader(modelDir);
    _session = session;
    _sessionDir = modelDir;
    return session;
  }

  Future<VoiceStyle> _ensureVoice(String voiceId) async {
    final cached = _voiceCache[voiceId];
    if (cached != null) return cached;
    final style = await _voiceLoader(['$_voiceAssetDir/$voiceId.json']);
    _voiceCache[voiceId] = style;
    return style;
  }

  @override
  Future<void> dispose() async {
    await _session?.dispose();
    _session = null;
    _sessionDir = null;
    // Each VoiceStyle holds native OrtValue tensors (style_ttl/style_dp);
    // clearing the map alone would leak them on the native heap.
    for (final style in _voiceCache.values) {
      await style.ttl.dispose();
      await style.dp.dispose();
    }
    _voiceCache.clear();
  }
}
