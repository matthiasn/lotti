import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Information about a Whisper model
class WhisperModelInfo {
  const WhisperModelInfo({
    required this.name,
    required this.displayName,
    required this.sizeBytes,
    required this.url,
    this.description,
  });

  final String name;
  final String displayName;
  final int sizeBytes;
  final String url;
  final String? description;

  String get sizeMB => '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Result of a model operation
class WhisperModelResult {
  const WhisperModelResult({
    required this.success,
    this.modelPath,
    this.message,
    this.error,
  });

  final bool success;
  final String? modelPath;
  final String? message;
  final Object? error;
}

/// Progress information for model download
class WhisperModelDownloadProgress {
  const WhisperModelDownloadProgress({
    required this.modelName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.isComplete,
  });

  final String modelName;
  final int downloadedBytes;
  final int totalBytes;
  final bool isComplete;

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
}

/// Service for managing Whisper model downloads and caching
///
/// Models are downloaded from Hugging Face and cached locally.
/// The service supports multiple model sizes with different accuracy/speed tradeoffs.
class WhisperModelService {
  WhisperModelService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Base URL for model downloads from Hugging Face
  static const _modelBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// Available models with their metadata
  /// Using quantized models where available for smaller downloads
  static const Map<String, WhisperModelInfo> availableModels = {
    'ggml-tiny.en.bin': WhisperModelInfo(
      name: 'ggml-tiny.en.bin',
      displayName: 'Tiny (English)',
      sizeBytes: 77700000, // ~77 MB
      url: '$_modelBaseUrl/ggml-tiny.en.bin',
      description: 'Fastest, lowest accuracy. Good for quick tests.',
    ),
    'ggml-tiny-q5_1.bin': WhisperModelInfo(
      name: 'ggml-tiny-q5_1.bin',
      displayName: 'Tiny Quantized',
      sizeBytes: 32200000, // ~32 MB
      url: '$_modelBaseUrl/ggml-tiny-q5_1.bin',
      description: 'Tiny model with 5-bit quantization. Smallest download.',
    ),
    'ggml-base.en.bin': WhisperModelInfo(
      name: 'ggml-base.en.bin',
      displayName: 'Base (English)',
      sizeBytes: 142000000, // ~142 MB
      url: '$_modelBaseUrl/ggml-base.en.bin',
      description: 'Good balance of speed and accuracy for English.',
    ),
    'ggml-base-q5_1.bin': WhisperModelInfo(
      name: 'ggml-base-q5_1.bin',
      displayName: 'Base Quantized',
      sizeBytes: 57000000, // ~57 MB
      url: '$_modelBaseUrl/ggml-base-q5_1.bin',
      description: 'Base model with quantization. Recommended for most users.',
    ),
    'ggml-small.en.bin': WhisperModelInfo(
      name: 'ggml-small.en.bin',
      displayName: 'Small (English)',
      sizeBytes: 466000000, // ~466 MB
      url: '$_modelBaseUrl/ggml-small.en.bin',
      description: 'Better accuracy, moderate speed.',
    ),
    'ggml-small-q5_1.bin': WhisperModelInfo(
      name: 'ggml-small-q5_1.bin',
      displayName: 'Small Quantized',
      sizeBytes: 182000000, // ~182 MB
      url: '$_modelBaseUrl/ggml-small-q5_1.bin',
      description: 'Small model with quantization. Good accuracy.',
    ),
    'ggml-medium.bin': WhisperModelInfo(
      name: 'ggml-medium.bin',
      displayName: 'Medium (Multilingual)',
      sizeBytes: 1500000000, // ~1.5 GB
      url: '$_modelBaseUrl/ggml-medium.bin',
      description: 'High accuracy, supports multiple languages.',
    ),
    'ggml-medium-q5_0.bin': WhisperModelInfo(
      name: 'ggml-medium-q5_0.bin',
      displayName: 'Medium Quantized',
      sizeBytes: 515000000, // ~515 MB
      url: '$_modelBaseUrl/ggml-medium-q5_0.bin',
      description: 'Medium model with quantization. Good for multilingual.',
    ),
    'ggml-large-v3.bin': WhisperModelInfo(
      name: 'ggml-large-v3.bin',
      displayName: 'Large v3 (Best)',
      sizeBytes: 2900000000, // ~2.9 GB
      url: '$_modelBaseUrl/ggml-large-v3.bin',
      description: 'Highest accuracy, slowest. Best for important content.',
    ),
    'ggml-large-v3-q5_0.bin': WhisperModelInfo(
      name: 'ggml-large-v3-q5_0.bin',
      displayName: 'Large v3 Quantized',
      sizeBytes: 1030000000, // ~1 GB
      url: '$_modelBaseUrl/ggml-large-v3-q5_0.bin',
      description: 'Large v3 with quantization. Best quality/size ratio.',
    ),
  };

  /// Default model to use
  static const defaultModel = 'ggml-base-q5_1.bin';

  final _downloadProgressController =
      StreamController<WhisperModelDownloadProgress>.broadcast();

  /// Stream of download progress updates
  Stream<WhisperModelDownloadProgress> get downloadProgress =>
      _downloadProgressController.stream;

  /// Gets the cache directory for Whisper models
  Future<Directory> getModelCacheDirectory() async {
    final cacheDir = await getApplicationCacheDirectory();
    final whisperDir = Directory(path.join(cacheDir.path, 'whisper-models'));

    if (!whisperDir.existsSync()) {
      await whisperDir.create(recursive: true);
    }

    return whisperDir;
  }

  /// Gets the path to a specific model
  Future<String> getModelPath(String modelName) async {
    final cacheDir = await getModelCacheDirectory();
    return path.join(cacheDir.path, modelName);
  }

  /// Checks if a model is already downloaded
  Future<bool> isModelDownloaded(String modelName) async {
    final modelPath = await getModelPath(modelName);
    final file = File(modelPath);

    if (!file.existsSync()) {
      return false;
    }

    // Verify file size matches expected
    final info = availableModels[modelName];
    if (info != null) {
      final fileSize = await file.length();
      // Allow 5% variance for file size
      final expectedSize = info.sizeBytes;
      final minSize = (expectedSize * 0.95).toInt();
      final maxSize = (expectedSize * 1.05).toInt();

      return fileSize >= minSize && fileSize <= maxSize;
    }

    return true;
  }

  /// Lists all downloaded models
  Future<List<String>> listDownloadedModels() async {
    final cacheDir = await getModelCacheDirectory();
    final downloaded = <String>[];

    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        if (availableModels.containsKey(name)) {
          downloaded.add(name);
        }
      }
    }

    return downloaded;
  }

  /// Ensures a model is available, downloading if necessary
  Future<WhisperModelResult> ensureModelAvailable(String modelName) async {
    // Check if already downloaded
    if (await isModelDownloaded(modelName)) {
      final modelPath = await getModelPath(modelName);
      developer.log(
        'Model $modelName already available at $modelPath',
        name: 'WhisperModelService',
      );
      return WhisperModelResult(
        success: true,
        modelPath: modelPath,
        message: 'Model already downloaded',
      );
    }

    // Download the model
    return downloadModel(modelName);
  }

  /// Downloads a model from Hugging Face
  Future<WhisperModelResult> downloadModel(String modelName) async {
    final info = availableModels[modelName];
    if (info == null) {
      return WhisperModelResult(
        success: false,
        message: 'Unknown model: $modelName',
      );
    }

    developer.log(
      'Downloading model $modelName (${info.sizeMB})',
      name: 'WhisperModelService',
    );

    try {
      final modelPath = await getModelPath(modelName);
      final tempPath = '$modelPath.tmp';

      // Create request
      final request = http.Request('GET', Uri.parse(info.url));
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        return WhisperModelResult(
          success: false,
          message: 'Failed to download model: HTTP ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength ?? info.sizeBytes;
      var downloadedBytes = 0;

      // Download to temp file with progress
      final file = File(tempPath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        _downloadProgressController.add(
          WhisperModelDownloadProgress(
            modelName: modelName,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            isComplete: false,
          ),
        );
      }

      await sink.close();

      // Move temp file to final location
      await File(tempPath).rename(modelPath);

      developer.log(
        'Model $modelName downloaded successfully to $modelPath',
        name: 'WhisperModelService',
      );

      _downloadProgressController.add(
        WhisperModelDownloadProgress(
          modelName: modelName,
          downloadedBytes: totalBytes,
          totalBytes: totalBytes,
          isComplete: true,
        ),
      );

      return WhisperModelResult(
        success: true,
        modelPath: modelPath,
        message: 'Model downloaded successfully',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to download model $modelName: $e',
        name: 'WhisperModelService',
        error: e,
        stackTrace: stackTrace,
      );

      return WhisperModelResult(
        success: false,
        message: 'Failed to download model: $e',
        error: e,
      );
    }
  }

  /// Deletes a downloaded model
  Future<bool> deleteModel(String modelName) async {
    try {
      final modelPath = await getModelPath(modelName);
      final file = File(modelPath);

      if (file.existsSync()) {
        await file.delete();
        developer.log(
          'Deleted model $modelName',
          name: 'WhisperModelService',
        );
        return true;
      }

      return false;
    } catch (e) {
      developer.log(
        'Failed to delete model $modelName: $e',
        name: 'WhisperModelService',
        error: e,
      );
      return false;
    }
  }

  /// Gets total disk usage of downloaded models
  Future<int> getTotalModelSize() async {
    var totalSize = 0;
    final cacheDir = await getModelCacheDirectory();

    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  void dispose() {
    _downloadProgressController.close();
    _httpClient.close();
  }
}
