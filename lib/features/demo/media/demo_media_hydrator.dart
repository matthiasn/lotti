import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:path/path.dart' as p;

typedef DemoMediaDownload = Future<Uint8List> Function(Uri uri);
typedef DemoMediaFileDigest = Future<String> Function(File file);
typedef DemoMediaFileRename =
    Future<File> Function(
      File source,
      String targetPath,
    );
typedef DemoMediaHydrationError =
    void Function(
      DemoMediaAsset asset,
      Object error,
      StackTrace stackTrace,
    );

class DemoMediaHydrationResult {
  const DemoMediaHydrationResult({
    required this.alreadyComplete,
    required this.downloaded,
    required this.failed,
    required this.cancelled,
  });

  final int alreadyComplete;
  final int downloaded;
  final int failed;
  final int cancelled;

  bool get isComplete => failed == 0 && cancelled == 0;
}

/// Reconciles the immutable R2 catalog into one demo tenant's media folder.
///
/// [hydrate] is intentionally fire-and-forget at bootstrap: demo activation
/// never waits for the network. Missing covers render as their established
/// placeholders, and the existing file watchers reveal them as each atomic
/// download lands. A later startup simply retries anything still incomplete.
class DemoMediaHydrator {
  DemoMediaHydrator({
    required this.root,
    required this.assets,
    required this.download,
    this.onError,
    this.concurrency = 3,
    this.closeDownloader,
    DemoMediaFileDigest? digestFile,
    DemoMediaFileRename? renameFile,
  }) : _digestFile = digestFile ?? _defaultDigestFile,
       _renameFile = renameFile ?? _defaultRenameFile,
       assert(concurrency > 0, 'concurrency must be positive');

  factory DemoMediaHydrator.network({
    required Directory root,
    required List<DemoMediaAsset> assets,
    DemoMediaHydrationError? onError,
    int concurrency = 3,
    Duration requestTimeout = const Duration(seconds: 20),
    http.Client? client,
  }) {
    final httpClient = client ?? http.Client();
    return DemoMediaHydrator(
      root: root,
      assets: assets,
      concurrency: concurrency,
      onError: onError,
      download: (uri) async {
        final response = await httpClient.get(uri).timeout(requestTimeout);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Demo media request returned HTTP ${response.statusCode}',
            uri: uri,
          );
        }
        return response.bodyBytes;
      },
      closeDownloader: httpClient.close,
    );
  }

  final Directory root;
  final List<DemoMediaAsset> assets;
  final int concurrency;
  final DemoMediaHydrationError? onError;
  final DemoMediaDownload download;
  final void Function()? closeDownloader;
  final DemoMediaFileDigest _digestFile;
  final DemoMediaFileRename _renameFile;

  bool _disposed = false;

  Future<DemoMediaHydrationResult> hydrate() async {
    var alreadyComplete = 0;
    var downloaded = 0;
    var failed = 0;
    var cancelled = 0;
    var nextIndex = 0;

    final pending = <DemoMediaAsset>[];
    for (final asset in assets) {
      if (await _isComplete(asset)) {
        alreadyComplete++;
      } else {
        pending.add(asset);
      }
    }

    Future<void> worker() async {
      while (true) {
        if (_disposed) return;
        final index = nextIndex++;
        if (index >= pending.length) return;
        final asset = pending[index];
        try {
          final installed = await _hydrateAsset(asset);
          if (installed) {
            downloaded++;
          } else {
            cancelled++;
          }
        } catch (error, stackTrace) {
          failed++;
          onError?.call(asset, error, stackTrace);
        }
      }
    }

    final workerCount = pending.length < concurrency
        ? pending.length
        : concurrency;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    if (_disposed && nextIndex < pending.length) {
      cancelled += pending.length - nextIndex;
    }

    return DemoMediaHydrationResult(
      alreadyComplete: alreadyComplete,
      downloaded: downloaded,
      failed: failed,
      cancelled: cancelled,
    );
  }

  Future<bool> _hydrateAsset(DemoMediaAsset asset) async {
    final bytes = await download(asset.uri);
    if (_disposed) return false;

    final actualDigest = sha256.convert(bytes).toString();
    if (actualDigest != asset.sha256) {
      throw StateError(
        'Checksum mismatch for demo media ${asset.fileName}',
      );
    }

    final target = _target(asset);
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      if (_disposed) return false;
      try {
        await _renameFile(partial, target.path);
      } on FileSystemException {
        // Windows does not replace an existing destination on rename. The
        // fallback only touches this catalog-owned file inside the demo root.
        if (target.existsSync()) target.deleteSync();
        await _renameFile(partial, target.path);
      }
      return true;
    } finally {
      if (partial.existsSync()) partial.deleteSync();
    }
  }

  Future<bool> _isComplete(DemoMediaAsset asset) async {
    final file = _target(asset);
    if (!file.existsSync()) return false;
    try {
      return await _digestFile(file) == asset.sha256;
    } on FileSystemException {
      return false;
    }
  }

  static Future<String> _defaultDigestFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<File> _defaultRenameFile(File source, String targetPath) =>
      source.rename(targetPath);

  File _target(DemoMediaAsset asset) =>
      File(p.joinAll([root.path, ...asset.relativePath.split('/')]));

  void dispose() {
    _disposed = true;
    closeDownloader?.call();
  }
}
