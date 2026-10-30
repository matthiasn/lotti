import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One immutable, checksum-pinned artifact of a model.
class PinnedModelFile {
  const PinnedModelFile(this.name, this.bytes, this.sha256);

  /// The path inside the model's directory, which may name a subdirectory.
  final String name;
  final int bytes;
  final String sha256;
}

/// A model downloaded at a fixed upstream revision, file by file.
abstract interface class PinnedModel {
  String get id;
  String get revision;
  List<PinnedModelFile> get files;

  /// Where [file] is downloaded from.
  Uri uri(PinnedModelFile file);
}

/// The size of every file of [model] together.
int pinnedModelBytes(PinnedModel model) =>
    model.files.fold(0, (total, file) => total + file.bytes);

/// Device-local model files under `<application support>/<folder>`.
/// Configuration sync never implies installation. Downloads are explicit,
/// coalesced per model, and published atomically only after their size and
/// SHA-256 match the pinned manifest.
class PinnedModelFiles {
  PinnedModelFiles({
    required this.folder,
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
    this.stallTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// The directory, under application support, that holds every model.
  final String folder;

  /// How long a download waits for the server's answer, or for its next
  /// bytes, before it is abandoned: its request is aborted and its install
  /// fails, so it can be tried again.
  final Duration stallTimeout;
  final http.Client _client;
  final Future<Directory> Function() _supportDirectory;
  final _downloads = <String, Future<String>>{};

  /// Everyone following a running download, by model id, and how far it has
  /// got: a caller that joins it hears from it too, starting where it is.
  final _listeners = <String, List<void Function(double)>>{};
  final _progress = <String, double>{};
  final _verifiedFiles = <String, ({FileStat stat, Future<bool> result})>{};

  /// The directory [model]'s files live in, one per revision.
  Future<String> directory(PinnedModel model) async {
    final support = await _supportDirectory();
    return p.join(support.path, folder, model.id, model.revision);
  }

  /// Whether [model] is downloading right now.
  bool isDownloading(PinnedModel model) => _downloads.containsKey(model.id);

  /// Hash each file once per process, then probe its size and timestamps.
  /// Changed files are verified again; installs and removals invalidate the cache.
  Future<bool> isInstalled(PinnedModel model) async {
    final root = await directory(model);
    for (final artifact in model.files) {
      final file = File(p.join(root, artifact.name));
      if (!await _isVerified(file, artifact)) return false;
    }
    return true;
  }

  Future<bool> _isVerified(File file, PinnedModelFile artifact) async {
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

  Future<bool> _matches(File file, PinnedModelFile artifact) async =>
      file.existsSync() &&
      await file.length() == artifact.bytes &&
      (await sha256.bind(file.openRead()).first).toString() == artifact.sha256;

  /// Downloads whatever of [model] is missing or wrong, and returns its
  /// directory. Downloading requires an explicit user action; inference only
  /// reads files. [onProgress] receives the share of the model's bytes done;
  /// a call that joins a running download hears from it as well, first with
  /// how far it has got.
  Future<String> install(
    PinnedModel model, {
    void Function(double)? onProgress,
  }) {
    final listeners = _listeners[model.id] ??= [];
    if (onProgress != null) {
      listeners.add(onProgress);
      final sofar = _progress[model.id];
      if (sofar != null) onProgress(sofar);
    }
    return _downloads.putIfAbsent(
      model.id,
      () =>
          _install(model, (value) {
            _progress[model.id] = value;
            for (final listener in [...listeners]) {
              listener(value);
            }
          }).whenComplete(() {
            _downloads.remove(model.id);
            _listeners.remove(model.id);
            _progress.remove(model.id);
          }),
    );
  }

  Future<String> _install(
    PinnedModel model,
    void Function(double)? onProgress,
  ) async {
    _verifiedFiles.clear();
    final root = await directory(model);
    await Directory(root).create(recursive: true);
    final total = pinnedModelBytes(model);
    var completed = 0;
    for (final artifact in model.files) {
      final file = File(p.join(root, artifact.name));
      if (!await _matches(file, artifact)) {
        await _download(model.uri(artifact), file, artifact, (received) {
          onProgress?.call((completed + received) / total);
        });
      }
      // Installation already checked the digest; routine discovery can reuse it.
      _verifiedFiles[file.path] = (
        stat: file.statSync(),
        result: Future.value(true),
      );
      completed += artifact.bytes;
      onProgress?.call(completed / total);
    }
    return root;
  }

  Future<void> _download(
    Uri uri,
    File destination,
    PinnedModelFile artifact,
    void Function(int) onProgress,
  ) async {
    final abort = Completer<void>();
    void abandon() {
      if (!abort.isCompleted) abort.complete();
    }

    final http.StreamedResponse response;
    try {
      response = await _client
          .send(http.AbortableRequest('GET', uri, abortTrigger: abort.future))
          .timeout(stallTimeout);
    } on TimeoutException {
      abandon();
      rethrow;
    }
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
        final chunks = response.stream.timeout(
          stallTimeout,
          onTimeout: (sink) {
            abandon();
            sink
              ..addError(
                TimeoutException('Model download stalled', stallTimeout),
              )
              ..close();
          },
        );
        await for (final chunk in chunks) {
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
  Future<void> remove(PinnedModel model) async {
    if (isDownloading(model)) {
      throw StateError('Cannot remove a model while it is downloading');
    }
    _verifiedFiles.clear();
    final root = Directory(await directory(model));
    if (root.existsSync()) await root.delete(recursive: true);
  }

  void close() => _client.close();
}
