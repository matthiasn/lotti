import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:lotti/features/ai/on_device_embedding/embedding_model.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';
import 'package:lotti/utils/platform.dart' as platform;

/// Thrown by an embedding call while the model is not on this device.
class EmbeddingModelNotInstalledException implements Exception {
  const EmbeddingModelNotInstalledException(this.modelId);

  final String modelId;

  @override
  String toString() =>
      'EmbeddingModelNotInstalledException: $modelId is not downloaded';
}

/// Loads an embedder from the directory a model is installed in.
typedef EmbedderLoader = Future<GemmaEmbedder> Function(String directory);

/// The app's one embedding provider: [model] on this device.
///
/// The model is downloaded only by [install], an explicit user action.
/// Until then every embedding call throws
/// [EmbeddingModelNotInstalledException]. The embedder is loaded on the first
/// call and kept; a load that fails is tried again on the next call.
class OnDeviceEmbeddingRepository {
  OnDeviceEmbeddingRepository({
    PinnedModelFiles? files,
    EmbeddingModel? model,
    this._load = GemmaEmbedder.load,
  }) : _files = files ?? PinnedModelFiles(folder: 'embedding_models'),
       model = model ?? embeddingGemma;

  final PinnedModelFiles _files;
  final EmbedderLoader _load;

  /// The model every vector is made with.
  final EmbeddingModel model;

  /// The platforms where the bundled ONNX Runtime plugin runs inference off
  /// the thread that draws the app, and is verified to link: macOS, iOS,
  /// Linux and Android. On Windows the plugin answers on the platform thread,
  /// so indexing would freeze the window; there the pipeline does not start.
  static bool get isPlatformSupported =>
      platform.isMacOS ||
      platform.isIOS ||
      platform.isLinux ||
      platform.isAndroid;

  Future<GemmaEmbedder>? _embedder;

  /// The id stored with every vector this repository makes.
  String get modelId => model.id;

  /// Whether every file of the model is on this device and verified.
  Future<bool> isInstalled() => _files.isInstalled(model);

  /// Whether [install] is running.
  bool get isInstalling => _files.isDownloading(model);

  /// Downloads whatever of the model is missing. [onProgress] receives the
  /// share of its bytes done.
  Future<void> install({void Function(double)? onProgress}) =>
      _files.install(model, onProgress: onProgress);

  /// The vector a search for [query] is compared with.
  Future<Float32List> embedQuery(String query) async =>
      (await _ready()).embedQuery(query);

  /// The vector that represents [text] in the index.
  Future<Float32List> embedDocument(String text) async =>
      (await _ready()).embedDocument(text);

  Future<GemmaEmbedder> _ready() async {
    final loading = _embedder;
    if (loading != null) return loading;
    if (!await _files.isInstalled(model)) {
      throw EmbeddingModelNotInstalledException(model.id);
    }
    // Another call may have started loading while this one checked.
    return _embedder ??= _startLoading();
  }

  Future<GemmaEmbedder> _startLoading() async {
    try {
      return await _load(await _files.directory(model));
    } catch (_) {
      _embedder = null;
      rethrow;
    }
  }

  /// Releases the loaded model and the download client.
  Future<void> close() async {
    final loading = _embedder;
    _embedder = null;
    _files.close();
    if (loading == null) return;
    try {
      await (await loading).dispose();
    } catch (_) {
      // A model that never loaded holds nothing to release.
    }
  }
}

/// The app's [OnDeviceEmbeddingRepository], or null when the embedding
/// pipeline did not start (its store failed to open). The composition root
/// supplies the registered instance.
final onDeviceEmbeddingRepositoryProvider =
    Provider<OnDeviceEmbeddingRepository?>(
      (ref) => null,
      name: 'onDeviceEmbeddingRepositoryProvider',
    );
