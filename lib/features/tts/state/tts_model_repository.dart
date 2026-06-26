import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:path_provider/path_provider.dart';

/// Files that make up a Supertonic model, fetched from the repo's `onnx/`
/// directory. The two JSON configs live alongside the ONNX graphs upstream.
const List<String> kSupertonicModelFiles = <String>[
  'duration_predictor.onnx',
  'text_encoder.onnx',
  'vector_estimator.onnx',
  'vocoder.onnx',
  'tts.json',
  'unicode_indexer.json',
];

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

/// Downloads Supertonic models from Hugging Face into the app support
/// directory. The HTTP client and support-directory resolver are injectable so
/// the download/progress/skip logic is testable without the network.
class SupertonicModelRepository implements TtsModelRepository {
  SupertonicModelRepository({
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
  }) : _client = client ?? http.Client(),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final http.Client _client;
  final Future<Directory> Function() _supportDirectory;

  Uri _fileUri(String repoId, String file) =>
      Uri.parse('https://huggingface.co/$repoId/resolve/main/onnx/$file');

  @override
  Future<String> modelDirectory(String modelId) async {
    final support = await _supportDirectory();
    return '${support.path}/tts_models/$modelId';
  }

  @override
  Future<bool> isInstalled(String modelId) async {
    final dir = await modelDirectory(modelId);
    for (final file in kSupertonicModelFiles) {
      if (!File('$dir/$file').existsSync()) return false;
    }
    return true;
  }

  @override
  Future<String> ensureInstalled(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await modelDirectory(modelId);
    await Directory(dir).create(recursive: true);

    final missing = kSupertonicModelFiles
        .where((f) => !File('$dir/$f').existsSync())
        .toList();
    if (missing.isEmpty) {
      onProgress?.call(1);
      return dir;
    }

    final repoId = ttsModelByIdOrDefault(modelId).huggingFaceRepoId;
    for (var i = 0; i < missing.length; i++) {
      final fileIndex = i;
      await _download(
        _fileUri(repoId, missing[i]),
        File('$dir/${missing[i]}'),
        (fraction) => onProgress?.call((fileIndex + fraction) / missing.length),
      );
    }
    onProgress?.call(1);
    return dir;
  }

  Future<void> _download(
    Uri uri,
    File destination,
    void Function(double fraction) onFraction,
  ) async {
    final response = await _client.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to download $uri (HTTP ${response.statusCode})',
      );
    }

    // Stream into a .part file and rename on success so an interrupted
    // download never leaves a truncated file that isInstalled would accept.
    final part = File('${destination.path}.part');
    final sink = part.openWrite();
    try {
      final total = response.contentLength;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) onFraction(received / total);
      }
    } finally {
      await sink.close();
    }
    await part.rename(destination.path);
    onFraction(1);
  }
}

/// Provides the model repository — the Hugging Face downloader in production;
/// tests override it with a fake.
final ttsModelRepositoryProvider = Provider<TtsModelRepository>(
  ttsModelRepository,
  name: 'ttsModelRepositoryProvider',
);
TtsModelRepository ttsModelRepository(Ref ref) => SupertonicModelRepository();
