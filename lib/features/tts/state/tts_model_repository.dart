import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_model_repository.g.dart';

/// Ensures the ONNX model files for a model id are present on disk —
/// downloading them from Hugging Face on first use — and resolves the local
/// directory the engine loads from.
abstract interface class TtsModelRepository {
  /// Whether the model's files are already present locally.
  Future<bool> isInstalled(String modelId);

  /// Local directory containing the model's ONNX + config files.
  Future<String> modelDirectory(String modelId);

  /// Ensures the model is present (downloading if needed), reporting progress
  /// in `[0, 1]`, and returns its local directory.
  Future<String> ensureInstalled(
    String modelId, {
    void Function(double progress)? onProgress,
  });
}

/// Placeholder repository used until the Hugging Face downloader is wired.
///
/// [isInstalled] safely reports `false`; the download methods throw so a
/// premature call is loud rather than silently wrong. The playback controller
/// only reaches these after checking the engine is supported, so this is never
/// exercised in production before the real downloader lands.
class UnwiredTtsModelRepository implements TtsModelRepository {
  const UnwiredTtsModelRepository();

  Never _unwired() =>
      throw UnimplementedError('TTS model download is not wired yet.');

  @override
  Future<bool> isInstalled(String modelId) async => false;

  @override
  Future<String> modelDirectory(String modelId) => _unwired();

  @override
  Future<String> ensureInstalled(
    String modelId, {
    void Function(double progress)? onProgress,
  }) => _unwired();
}

/// Provides the model repository. Tests override this with a fake; the
/// concrete Hugging Face downloader replaces the placeholder once wired.
@Riverpod(keepAlive: true)
TtsModelRepository ttsModelRepository(Ref ref) =>
    const UnwiredTtsModelRepository();
