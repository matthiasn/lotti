import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One immutable, checksum-pinned artifact in an embedded speech model.
class SherpaModelFile {
  const SherpaModelFile(this.name, this.bytes, this.sha256);

  final String name;
  final int bytes;
  final String sha256;
}

/// A multilingual Whisper export supported by the embedded recognizer.
class SherpaModel {
  const SherpaModel({
    required this.id,
    required this.name,
    required this.revision,
    required this.files,
  });

  final String id;
  final String name;
  final String revision;
  final List<SherpaModelFile> files;

  int get bytes => files.fold(0, (total, file) => total + file.bytes);
  String get encoder => '$id-encoder.int8.onnx';
  String get decoder => '$id-decoder.int8.onnx';
  String get tokens => '$id-tokens.txt';

  Uri uri(SherpaModelFile file) => Uri.parse(
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-$id/'
    'resolve/$revision/${file.name}',
  );
}

/// Fixed upstream revisions prevent model downloads changing beneath a build.
const sherpaModels = [
  SherpaModel(
    id: 'tiny',
    name: 'Whisper Tiny',
    revision: '65176e2deb88badc814a94058666cadccc29b61c',
    files: [
      SherpaModelFile(
        'tiny-encoder.int8.onnx',
        12937772,
        'd24fb083ae3b1041fc24e97971d60e280c9342201fbb67b0ab428a8b4a51a434',
      ),
      SherpaModelFile(
        'tiny-decoder.int8.onnx',
        89855401,
        'd2fece8dd42771f1df975c6c0445770d0c292bf7547c2cae04a6c0cc57540925',
      ),
      SherpaModelFile(
        'tiny-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
  SherpaModel(
    id: 'base',
    name: 'Whisper Base',
    revision: 'bb53ee204431c90d314c1cc08d28d23e5b7927cc',
    files: [
      SherpaModelFile(
        'base-encoder.int8.onnx',
        29120534,
        '0b8fb1304b6109976038efff5ace81720e00386f3ff6b54ee8c75291ca0a1e11',
      ),
      SherpaModelFile(
        'base-decoder.int8.onnx',
        130672026,
        '9759d217388a01b3a4c7c15533201067b48ae819c4daafc8624e64b9409dc02d',
      ),
      SherpaModelFile(
        'base-tokens.txt',
        816730,
        'b34b360dbb493e781e479794586d661700670d65564001f23024971d1f2fa126',
      ),
    ],
  ),
];

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

  Future<bool> isInstalled(String id) async {
    final spec = model(id);
    final directory = await modelDirectory(id);
    for (final artifact in spec.files) {
      final file = File(p.join(directory, artifact.name));
      if (!await _matches(file, artifact)) return false;
    }
    return true;
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
