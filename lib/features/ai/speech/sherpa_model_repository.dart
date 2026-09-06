import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

export 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';

/// Device-local model files. Configuration sync never implies installation.
/// Downloads are explicit, coalesced per model, and published atomically only
/// after their size and SHA-256 match the pinned manifest.
class SherpaModelRepository {
  SherpaModelRepository({
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
    this.models = sherpaModels,
  }) : _client = client ?? http.Client(),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final http.Client _client;
  final Future<Directory> Function() _supportDirectory;
  final List<SherpaModel> models;
  final _downloads = <String, Future<String>>{};
  final _verifiedFiles = <String, ({FileStat stat, Future<bool> result})>{};

  SherpaModel model(String id) => models.firstWhere(
    (model) => model.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown speech model'),
  );

  Future<String> modelDirectory(String id) async {
    final spec = model(id);
    final support = await _supportDirectory();
    return p.join(support.path, 'sherpa_models', spec.id, spec.revision);
  }

  /// Availability checks ignore unknown synced model IDs instead of failing
  /// unrelated provider discovery. Direct downloads still reject unknown IDs.
  Future<bool> isAvailable(String id) async =>
      models.any((model) => model.id == id) && await isInstalled(id);

  /// Hash each file once per process, then probe its size and timestamps.
  /// Changed files are verified again; installs and removals invalidate the cache.
  Future<bool> isInstalled(String id) async {
    final spec = model(id);
    final directory = await modelDirectory(id);
    for (final artifact in spec.files) {
      final file = File(p.join(directory, artifact.name));
      if (!await _isVerified(file, artifact)) return false;
    }
    return true;
  }

  Future<bool> _isVerified(File file, SherpaModelFile artifact) async {
    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file || stat.size != artifact.bytes) {
      _verifiedFiles.remove(file.path);
      return false;
    }
    final cached = _verifiedFiles[file.path];
    if (cached != null &&
        cached.stat.size == stat.size &&
        cached.stat.modified == stat.modified &&
        cached.stat.changed == stat.changed) {
      return cached.result;
    }
    final result = _matches(file, artifact);
    _verifiedFiles[file.path] = (stat: stat, result: result);
    try {
      return await result;
    } catch (_) {
      _verifiedFiles.remove(file.path);
      rethrow;
    }
  }

  Future<bool> _matches(File file, SherpaModelFile artifact) async =>
      file.existsSync() &&
      await file.length() == artifact.bytes &&
      (await sha256.bind(file.openRead()).first).toString() == artifact.sha256;

  /// Downloading requires an explicit user action; inference only reads files.
  Future<String> install(String id, {void Function(double)? onProgress}) =>
      _downloads.putIfAbsent(
        id,
        () => _install(id, onProgress).whenComplete(() {
          _downloads.remove(id);
        }),
      );

  Future<String> _install(String id, void Function(double)? onProgress) async {
    final spec = model(id);
    _verifiedFiles.clear();
    final directory = await modelDirectory(id);
    await Directory(directory).create(recursive: true);
    var completed = 0;
    for (final artifact in spec.files) {
      final file = File(p.join(directory, artifact.name));
      if (!await _matches(file, artifact)) {
        await _download(spec.uri(artifact), file, artifact, (received) {
          onProgress?.call((completed + received) / spec.bytes);
        });
      }
      // Installation already checked the digest; routine discovery can reuse it.
      _verifiedFiles[file.path] = (
        stat: file.statSync(),
        result: Future.value(true),
      );
      completed += artifact.bytes;
      onProgress?.call(completed / spec.bytes);
    }
    return directory;
  }

  Future<void> _download(
    Uri uri,
    File destination,
    SherpaModelFile artifact,
    void Function(int) onProgress,
  ) async {
    final response = await _client.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw HttpException('Model download failed: HTTP ${response.statusCode}');
    }
    await destination.parent.create(recursive: true);
    final part = File('${destination.path}.part');
    try {
      final sink = part.openWrite();
      try {
        var received = 0;
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (received > artifact.bytes) {
            throw const FormatException('Model exceeds its expected size');
          }
          sink.add(chunk);
          onProgress(received);
        }
      } finally {
        await sink.close();
      }
      if (!await _matches(part, artifact)) {
        throw const FormatException('Model checksum or size does not match');
      }
      await part.rename(destination.path);
    } finally {
      if (part.existsSync()) await part.delete();
    }
  }

  /// Removes only this device's files; synced model configuration is retained.
  Future<void> remove(String id) async {
    if (_downloads.containsKey(id)) {
      throw StateError('Cannot remove a model while it is downloading');
    }
    _verifiedFiles.clear();
    final directory = Directory(await modelDirectory(id));
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  void close() => _client.close();
}

final sherpaModelRepositoryProvider = Provider<SherpaModelRepository>((ref) {
  final repository = SherpaModelRepository();
  ref.onDispose(repository.close);
  return repository;
});
